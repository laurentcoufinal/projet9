/**
 * Résout CHROME_BIN pour Karma : Chrome système ou chrome-headless-shell local.
 */
const { execSync, spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const FRONT_ROOT = path.join(__dirname, "..");
const CACHE_DIR = path.join(FRONT_ROOT, "chrome-headless-shell");

function findSystemChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    "/usr/bin/google-chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/snap/bin/chromium",
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

function findCachedChrome() {
  if (!fs.existsSync(CACHE_DIR)) {
    return null;
  }

  for (const entry of fs.readdirSync(CACHE_DIR)) {
    const binary = path.join(
      CACHE_DIR,
      entry,
      "chrome-headless-shell-linux64",
      "chrome-headless-shell"
    );
    if (fs.existsSync(binary)) {
      return binary;
    }
  }
  return null;
}

function installChrome() {
  console.log("Chrome introuvable — installation de chrome-headless-shell (une fois)...");
  execSync("npx --yes @puppeteer/browsers install chrome-headless-shell@stable", {
    cwd: FRONT_ROOT,
    stdio: "inherit",
  });
  return findCachedChrome();
}

function resolveChromeBin() {
  return findSystemChrome() || findCachedChrome() || installChrome();
}

function runTests() {
  const chrome = resolveChromeBin();
  if (!chrome) {
    console.error(
      "Impossible de trouver ou installer Chrome. Installez chromium-browser ou définissez CHROME_BIN."
    );
    process.exit(1);
  }

  console.log(`CHROME_BIN=${chrome}`);
  const result = spawnSync(
    "npx",
    [
      "ng",
      "test",
      "--watch=false",
      "--browsers=ChromeHeadlessNoSandbox",
      "--code-coverage",
    ],
    {
      cwd: FRONT_ROOT,
      env: { ...process.env, CHROME_BIN: chrome },
      stdio: "inherit",
    }
  );
  process.exit(result.status ?? 1);
}

if (require.main === module) {
  const mode = process.argv[2] || "run";
  if (mode === "print") {
    const chrome = resolveChromeBin();
    if (!chrome) {
      process.exit(1);
    }
    console.log(chrome);
    process.exit(0);
  }
  runTests();
}

module.exports = { resolveChromeBin };
