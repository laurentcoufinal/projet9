package com.openclassroom.devops.orion.microcrm.opensearch;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;

import java.time.Instant;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.opensearch.client.opensearch.OpenSearchClient;

import java.util.function.Function;

@ExtendWith(MockitoExtension.class)
class OpenSearchSecurityEventLoggerTest {

    @Mock
    private OpenSearchClient client;

    private OpenSearchProperties properties;
    private OpenSearchSecurityEventLogger logger;

    @BeforeEach
    void setUp() {
        properties = new OpenSearchProperties();
        properties.setIndexSecurityEvents("microcrm-security-events");
        logger = new OpenSearchSecurityEventLogger(client, properties);
    }

    @Test
    void indexSecurityEvent_shouldCallOpenSearchClient() throws Exception {
        SecurityEventDocument doc = new SecurityEventDocument(
                "req-1", Instant.now(), "security", "access",
                "127.0.0.1", "GET", "/persons", 200, 12L,
                "agent", "success", false, true);

        logger.indexSecurityEvent(doc);

        verify(client).index(any(Function.class));
    }

    @Test
    void indexSecurityEvent_shouldNotPropagateException() throws Exception {
        doThrow(new RuntimeException("OpenSearch down")).when(client).index(any(Function.class));

        SecurityEventDocument doc = new SecurityEventDocument(
                "req-2", Instant.now(), "security", "access",
                "127.0.0.1", "GET", "/persons", 500, 5L,
                "", "server_error", false, false);

        logger.indexSecurityEvent(doc);
    }
}
