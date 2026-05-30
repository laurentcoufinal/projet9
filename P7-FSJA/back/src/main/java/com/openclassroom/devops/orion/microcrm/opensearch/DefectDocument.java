package com.openclassroom.devops.orion.microcrm.opensearch;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonFormat;

public record DefectDocument(
        String requestId,
        @JsonFormat(shape = JsonFormat.Shape.STRING)
        Instant timestamp,
        String level,
        String message,
        String exceptionType,
        String stackTrace,
        String path,
        String method,
        int status) {
}
