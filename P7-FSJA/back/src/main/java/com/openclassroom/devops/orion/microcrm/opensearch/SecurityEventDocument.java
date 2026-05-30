package com.openclassroom.devops.orion.microcrm.opensearch;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonFormat;

public record SecurityEventDocument(
        String requestId,
        @JsonFormat(shape = JsonFormat.Shape.STRING)
        Instant timestamp,
        String eventCategory,
        String eventType,
        String clientIp,
        String method,
        String path,
        int status,
        long durationMs,
        String userAgent,
        String outcome,
        boolean sensitive,
        boolean requestIdProvided) {
}
