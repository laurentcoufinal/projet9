package com.openclassroom.devops.orion.microcrm.web;

import java.io.IOException;
import java.time.Instant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.openclassroom.devops.orion.microcrm.opensearch.OpenSearchSecurityEventLogger;
import com.openclassroom.devops.orion.microcrm.opensearch.SecurityEventDocument;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
@Order(Ordered.LOWEST_PRECEDENCE)
@ConditionalOnProperty(name = "opensearch.security.access-log.enabled", havingValue = "true", matchIfMissing = true)
public class SecurityAccessLogFilter extends OncePerRequestFilter {

    private static final Logger SECURITY_LOG = LoggerFactory.getLogger("security.access");
    private static final int MAX_USER_AGENT_LENGTH = 512;

    private final ObjectProvider<OpenSearchSecurityEventLogger> securityLogger;
    private final ObjectMapper objectMapper;

    public SecurityAccessLogFilter(
            ObjectProvider<OpenSearchSecurityEventLogger> securityLogger,
            ObjectMapper objectMapper) {
        this.securityLogger = securityLogger;
        this.objectMapper = objectMapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String uri = request.getRequestURI();
        return uri.startsWith("/actuator");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        long start = System.currentTimeMillis();
        boolean requestIdProvided = hasClientRequestId(request);

        try {
            filterChain.doFilter(request, response);
        } finally {
            long durationMs = System.currentTimeMillis() - start;
            SecurityEventDocument event = buildEvent(request, response, durationMs, requestIdProvided);
            emitSecurityEvent(event);
        }
    }

    private SecurityEventDocument buildEvent(
            HttpServletRequest request,
            HttpServletResponse response,
            long durationMs,
            boolean requestIdProvided) {
        int status = response.getStatus();
        String method = request.getMethod();
        String path = request.getRequestURI();

        return new SecurityEventDocument(
                resolveRequestId(request),
                Instant.now(),
                "security",
                "access",
                resolveClientIp(request),
                method,
                path,
                status,
                durationMs,
                truncateUserAgent(request.getHeader("User-Agent")),
                resolveOutcome(status),
                isSensitive(method, path),
                requestIdProvided);
    }

    private void emitSecurityEvent(SecurityEventDocument event) {
        securityLogger.ifAvailable(logger -> logger.indexSecurityEvent(event));
        try {
            SECURITY_LOG.info("SECURITY {}", objectMapper.writeValueAsString(event));
        } catch (Exception e) {
            SECURITY_LOG.warn("SECURITY logging failed for requestId={}: {}", event.requestId(), e.getMessage());
        }
    }

    static String resolveClientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    static String resolveOutcome(int status) {
        if (status < 400) {
            return "success";
        }
        if (status < 500) {
            return "client_error";
        }
        return "server_error";
    }

    static boolean isSensitive(String method, String path) {
        if ("DELETE".equalsIgnoreCase(method)) {
            return true;
        }
        if (path.startsWith("/persons") || path.startsWith("/organizations")) {
            return "POST".equalsIgnoreCase(method)
                    || "PUT".equalsIgnoreCase(method)
                    || "PATCH".equalsIgnoreCase(method);
        }
        return false;
    }

    private static boolean hasClientRequestId(HttpServletRequest request) {
        String header = request.getHeader(RequestIdFilter.HEADER_NAME);
        return header != null && !header.isBlank();
    }

    private static String resolveRequestId(HttpServletRequest request) {
        Object attr = request.getAttribute(RequestIdFilter.REQUEST_ATTRIBUTE);
        if (attr instanceof String id && !id.isBlank()) {
            return id;
        }
        return "unknown";
    }

    private static String truncateUserAgent(String userAgent) {
        if (userAgent == null) {
            return "";
        }
        if (userAgent.length() <= MAX_USER_AGENT_LENGTH) {
            return userAgent;
        }
        return userAgent.substring(0, MAX_USER_AGENT_LENGTH);
    }
}
