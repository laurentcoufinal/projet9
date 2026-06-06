#!/usr/bin/env python3
"""Calcul métriques DORA et transformation des runs GitHub Actions."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from shutil import which


def parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def run_duration_minutes(run: dict) -> float | None:
    if run.get("conclusion") not in ("success", "failure", "cancelled"):
        return None
    started = parse_dt(run.get("run_started_at"))
    ended = parse_dt(run.get("updated_at"))
    if started and ended and ended > started:
        return round((ended - started).total_seconds() / 60, 2)
    return None


def filter_runs_since(runs: list[dict], since: datetime | None) -> list[dict]:
    if since is None:
        return runs
    filtered = []
    for run in runs:
        created = parse_dt(run.get("created_at"))
        if created and created >= since:
            filtered.append(run)
    return filtered


def dedupe_runs(runs: list[dict]) -> list[dict]:
    seen: set[int] = set()
    unique: list[dict] = []
    for run in runs:
        run_id = run.get("id")
        if run_id in seen:
            continue
        seen.add(run_id)
        unique.append(run)
    return unique


def fetch_with_curl(repo: str, token: str) -> list[dict]:
    runs: list[dict] = []
    page = 1
    while True:
        query = urllib.parse.urlencode({"per_page": 100, "page": page})
        url = f"https://api.github.com/repos/{repo}/actions/runs?{query}"
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.load(response)
        batch = payload.get("workflow_runs", [])
        if not isinstance(batch, list) or not batch:
            break
        runs.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    return dedupe_runs(runs)


def fetch_with_gh(repo: str) -> list[dict]:
    proc = subprocess.run(
        ["gh", "api", f"repos/{repo}/actions/runs?per_page=100", "--paginate"],
        check=True,
        capture_output=True,
        text=True,
    )
    runs: list[dict] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue
        batch = data.get("workflow_runs", [])
        if isinstance(batch, list):
            runs.extend(batch)
    return dedupe_runs(runs)


def fetch_workflow_runs(repo: str, token: str | None = None) -> list[dict]:
    if token:
        return fetch_with_curl(repo, token)
    if which("gh"):
        return fetch_with_gh(repo)
    raise RuntimeError("GITHUB_TOKEN requis ou gh CLI authentifié")


def compute_metrics(runs: list[dict], days: int, repo: str) -> dict:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    filtered = filter_runs_since(runs, since)

    ci = [r for r in filtered if r.get("name") == "CI"]
    cd = [r for r in filtered if r.get("name") == "CD"]
    nightly = [r for r in filtered if r.get("name") == "Nightly"]

    def avg_minutes(target_runs: list[dict]) -> float | None:
        values = [d for d in (run_duration_minutes(r) for r in target_runs) if d is not None]
        return round(sum(values) / len(values), 1) if values else None

    weeks = max(1, days / 7)
    cd_success = [r for r in cd if r.get("conclusion") == "success"]
    deploy_freq = round(len(cd_success) / weeks, 2)

    cd_total = len([r for r in cd if r.get("conclusion")])
    cd_fail = len([r for r in cd if r.get("conclusion") == "failure"])
    cfr = round(100 * cd_fail / cd_total, 1) if cd_total else 0

    ci_main_success = [
        r for r in ci if r.get("head_branch") == "main" and r.get("conclusion") == "success"
    ]
    lead_time = avg_minutes(ci_main_success)

    ci_main = sorted([r for r in ci if r.get("head_branch") == "main"], key=lambda x: x.get("created_at", ""))
    mttr_samples: list[float] = []
    for index, run in enumerate(ci_main):
        if run.get("conclusion") != "failure":
            continue
        fail_end = parse_dt(run.get("updated_at"))
        for next_run in ci_main[index + 1 :]:
            if next_run.get("conclusion") == "success":
                ok_start = parse_dt(next_run.get("run_started_at"))
                if fail_end and ok_start and ok_start > fail_end:
                    mttr_samples.append((ok_start - fail_end).total_seconds() / 3600)
                break
    mttr = round(sum(mttr_samples) / len(mttr_samples), 2) if mttr_samples else None

    ci_fail_rate = (
        round(100 * len([r for r in ci if r.get("conclusion") == "failure"]) / len(ci), 1) if ci else 0
    )

    return {
        "period_days": days,
        "repo": repo,
        "lead_time_minutes": lead_time,
        "deployment_frequency_per_week": deploy_freq,
        "mttr_hours": mttr,
        "change_failure_rate_pct": cfr,
        "ci_failure_rate_pct": ci_fail_rate,
        "ci_runs": len(ci),
        "cd_runs": len(cd),
        "nightly_runs": len(nightly),
    }


def workflow_run_document(run: dict, repo: str) -> dict:
    return {
        "timestamp": run.get("created_at"),
        "eventType": "workflow_run",
        "repo": repo,
        "workflow": run.get("name"),
        "conclusion": run.get("conclusion") or "unknown",
        "branch": run.get("head_branch") or "unknown",
        "run_id": run.get("id"),
        "duration_minutes": run_duration_minutes(run),
        "head_sha": run.get("head_sha"),
        "source": "github-api",
        "ingest_source": os.environ.get("DORA_INGEST_SOURCE", "sync_dora_script"),
    }


def snapshot_document(metrics: dict) -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "timestamp": now,
        "eventType": "dora_snapshot",
        "repo": metrics.get("repo"),
        "source": "github-api",
        "ingest_source": os.environ.get("DORA_INGEST_SOURCE", "sync_dora_script"),
        **metrics,
    }


def build_bulk_lines(runs: list[dict], repo: str, index: str, since_days: int) -> list[str]:
    since = datetime.now(timezone.utc) - timedelta(days=since_days)
    lines: list[str] = []
    for run in filter_runs_since(runs, since):
        run_id = run.get("id")
        if run_id is None:
            continue
        meta = json.dumps({"index": {"_index": index, "_id": f"run-{run_id}"}})
        body = json.dumps(workflow_run_document(run, repo))
        lines.extend([meta, body])
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description="DORA metrics utilities")
    sub = parser.add_subparsers(dest="command", required=True)

    fetch_p = sub.add_parser("fetch", help="Fetch workflow runs JSON")
    fetch_p.add_argument("--repo", required=True)
    fetch_p.add_argument("--token", default=os.environ.get("GITHUB_TOKEN", ""))

    metrics_p = sub.add_parser("metrics", help="Compute DORA metrics from runs JSON on stdin")
    metrics_p.add_argument("--repo", required=True)
    metrics_p.add_argument("--days", type=int, default=28)

    bulk_p = sub.add_parser("bulk", help="Build OpenSearch bulk NDJSON from runs on stdin")
    bulk_p.add_argument("--repo", required=True)
    bulk_p.add_argument("--index", default="microcrm-dora-metrics")
    bulk_p.add_argument("--days", type=int, default=90)

    sub.add_parser("snapshot", help="Build snapshot document from metrics JSON on stdin")

    args = parser.parse_args()

    if args.command == "fetch":
        token = args.token or None
        try:
            runs = fetch_workflow_runs(args.repo, token)
        except urllib.error.HTTPError as exc:
            print(f"GitHub API error: {exc.code} {exc.reason}", file=sys.stderr)
            return 1
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        json.dump(runs, sys.stdout)
        return 0

    if args.command == "metrics":
        runs = json.load(sys.stdin)
        json.dump(compute_metrics(runs, args.days, args.repo), sys.stdout)
        return 0

    if args.command == "bulk":
        runs = json.load(sys.stdin)
        lines = build_bulk_lines(runs, args.repo, args.index, args.days)
        sys.stdout.write("\n".join(lines))
        if lines:
            sys.stdout.write("\n")
        return 0

    if args.command == "snapshot":
        metrics = json.load(sys.stdin)
        json.dump(snapshot_document(metrics), sys.stdout)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
