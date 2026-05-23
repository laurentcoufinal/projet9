package com.openclassroom.devops.orion.microcrm.opensearch;

import java.time.Instant;

public record DefectDocument(
        String requestId,
        Instant timestamp,
        String level,
        String message,
        String exceptionType,
        String stackTrace,
        String path,
        String method,
        int status) {
}
