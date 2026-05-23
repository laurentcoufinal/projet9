package com.openclassroom.devops.orion.microcrm.exception;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.time.Instant;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.openclassroom.devops.orion.microcrm.opensearch.DefectDocument;
import com.openclassroom.devops.orion.microcrm.opensearch.OpenSearchDefectLogger;
import com.openclassroom.devops.orion.microcrm.web.RequestIdFilter;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final int MAX_STACK_LENGTH = 8192;

    private final ObjectProvider<OpenSearchDefectLogger> defectLogger;

    public GlobalExceptionHandler(ObjectProvider<OpenSearchDefectLogger> defectLogger) {
        this.defectLogger = defectLogger;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidation(
            MethodArgumentNotValidException ex,
            HttpServletRequest request) {
        String message = ex.getBindingResult().getFieldErrors().stream()
                .map(e -> e.getField() + ": " + e.getDefaultMessage())
                .collect(Collectors.joining("; "));
        return buildResponse(request, HttpStatus.BAD_REQUEST, message, ex);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, String>> handleConstraintViolation(
            ConstraintViolationException ex,
            HttpServletRequest request) {
        String message = ex.getConstraintViolations().stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .collect(Collectors.joining("; "));
        return buildResponse(request, HttpStatus.BAD_REQUEST, message, ex);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, String>> handleDataIntegrity(
            DataIntegrityViolationException ex,
            HttpServletRequest request) {
        return buildResponse(request, HttpStatus.CONFLICT, "Data integrity violation", ex);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGeneric(
            Exception ex,
            HttpServletRequest request) {
        return buildResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "Internal server error", ex);
    }

    private ResponseEntity<Map<String, String>> buildResponse(
            HttpServletRequest request,
            HttpStatus status,
            String message,
            Exception ex) {
        String requestId = resolveRequestId(request);
        indexDefect(request, status, message, ex, requestId);
        return ResponseEntity.status(status).body(Map.of(
                "message", message,
                "requestId", requestId));
    }

    private void indexDefect(
            HttpServletRequest request,
            HttpStatus status,
            String message,
            Exception ex,
            String requestId) {
        defectLogger.ifAvailable(logger -> logger.indexDefect(new DefectDocument(
                requestId,
                Instant.now(),
                "ERROR",
                message,
                ex.getClass().getName(),
                truncateStackTrace(ex),
                request.getRequestURI(),
                request.getMethod(),
                status.value())));
    }

    private String resolveRequestId(HttpServletRequest request) {
        Object attr = request.getAttribute(RequestIdFilter.REQUEST_ATTRIBUTE);
        if (attr instanceof String id && !id.isBlank()) {
            return id;
        }
        String header = request.getHeader(RequestIdFilter.HEADER_NAME);
        if (header != null && !header.isBlank()) {
            return header;
        }
        return "unknown";
    }

    private static String truncateStackTrace(Exception ex) {
        StringWriter sw = new StringWriter();
        ex.printStackTrace(new PrintWriter(sw));
        String trace = sw.toString();
        if (trace.length() <= MAX_STACK_LENGTH) {
            return trace;
        }
        return trace.substring(0, MAX_STACK_LENGTH) + "\n... (truncated)";
    }
}
