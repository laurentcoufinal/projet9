package com.openclassroom.devops.orion.microcrm.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.openclassroom.devops.orion.microcrm.opensearch.OpenSearchSecurityEventLogger;
import com.openclassroom.devops.orion.microcrm.opensearch.SecurityEventDocument;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SecurityAccessLogFilterTest {

    @Mock
    private OpenSearchSecurityEventLogger securityLogger;

    @Mock
    private ObjectProvider<OpenSearchSecurityEventLogger> securityLoggerProvider;

    private SecurityAccessLogFilter filter;

    @BeforeEach
    void setUp() {
        doAnswer(invocation -> {
            @SuppressWarnings("unchecked")
            var consumer = (java.util.function.Consumer<OpenSearchSecurityEventLogger>) invocation.getArgument(0);
            consumer.accept(securityLogger);
            return null;
        }).when(securityLoggerProvider).ifAvailable(any());
        filter = new SecurityAccessLogFilter(securityLoggerProvider, new ObjectMapper());
    }

    @Test
    void shouldIndexAccessEventAfterRequest() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("DELETE", "/persons/1");
        request.addHeader("X-Request-Id", "req-abc");
        request.setAttribute(RequestIdFilter.REQUEST_ATTRIBUTE, "req-abc");
        request.addHeader("X-Forwarded-For", "203.0.113.10, 10.0.0.1");
        request.addHeader("User-Agent", "TestAgent/1.0");
        MockHttpServletResponse response = new MockHttpServletResponse();
        response.setStatus(204);

        filter.doFilter(request, response, new MockFilterChain());

        ArgumentCaptor<SecurityEventDocument> captor = ArgumentCaptor.forClass(SecurityEventDocument.class);
        verify(securityLogger).indexSecurityEvent(captor.capture());
        SecurityEventDocument event = captor.getValue();
        assertThat(event.requestId()).isEqualTo("req-abc");
        assertThat(event.clientIp()).isEqualTo("203.0.113.10");
        assertThat(event.method()).isEqualTo("DELETE");
        assertThat(event.path()).isEqualTo("/persons/1");
        assertThat(event.status()).isEqualTo(204);
        assertThat(event.outcome()).isEqualTo("success");
        assertThat(event.sensitive()).isTrue();
        assertThat(event.requestIdProvided()).isTrue();
    }

    @Test
    void shouldSkipActuatorPaths() {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/actuator/health");
        assertThat(filter.shouldNotFilter(request)).isTrue();
    }

    @Test
    void resolveOutcome_classifiesErrors() {
        assertThat(SecurityAccessLogFilter.resolveOutcome(200)).isEqualTo("success");
        assertThat(SecurityAccessLogFilter.resolveOutcome(404)).isEqualTo("client_error");
        assertThat(SecurityAccessLogFilter.resolveOutcome(500)).isEqualTo("server_error");
    }

    @Test
    void isSensitive_detectsMutations() {
        assertThat(SecurityAccessLogFilter.isSensitive("POST", "/persons")).isTrue();
        assertThat(SecurityAccessLogFilter.isSensitive("GET", "/persons")).isFalse();
        assertThat(SecurityAccessLogFilter.isSensitive("DELETE", "/other")).isTrue();
    }

    @Test
    void resolveClientIp_usesRemoteAddrWhenNoForwardedHeader() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("192.168.1.10");

        assertThat(SecurityAccessLogFilter.resolveClientIp(request)).isEqualTo("192.168.1.10");
    }

    @Test
    void shouldIndexEventWithoutClientRequestId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/persons");
        MockHttpServletResponse response = new MockHttpServletResponse();
        response.setStatus(200);

        filter.doFilter(request, response, new MockFilterChain());

        ArgumentCaptor<SecurityEventDocument> captor = ArgumentCaptor.forClass(SecurityEventDocument.class);
        verify(securityLogger).indexSecurityEvent(captor.capture());
        assertThat(captor.getValue().requestId()).isEqualTo("unknown");
        assertThat(captor.getValue().requestIdProvided()).isFalse();
    }

    @Test
    void shouldTruncateLongUserAgent() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/persons");
        request.addHeader("User-Agent", "A".repeat(600));
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, new MockFilterChain());

        ArgumentCaptor<SecurityEventDocument> captor = ArgumentCaptor.forClass(SecurityEventDocument.class);
        verify(securityLogger).indexSecurityEvent(captor.capture());
        assertThat(captor.getValue().userAgent()).hasSize(512);
    }
}
