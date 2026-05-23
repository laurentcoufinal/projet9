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
class OpenSearchDefectLoggerTest {

    @Mock
    private OpenSearchClient client;

    private OpenSearchProperties properties;
    private OpenSearchDefectLogger logger;

    @BeforeEach
    void setUp() {
        properties = new OpenSearchProperties();
        properties.setIndexDefects("microcrm-defects");
        logger = new OpenSearchDefectLogger(client, properties);
    }

    @Test
    void indexDefect_shouldCallOpenSearchClient() throws Exception {
        DefectDocument doc = new DefectDocument(
                "req-1", Instant.now(), "ERROR", "msg", null, null, "/p", "GET", 500);

        logger.indexDefect(doc);

        verify(client).index(any(Function.class));
    }

    @Test
    void indexDefect_shouldNotPropagateException() throws Exception {
        doThrow(new RuntimeException("OpenSearch down")).when(client).index(any(Function.class));

        DefectDocument doc = new DefectDocument(
                "req-2", Instant.now(), "ERROR", "msg", null, null, "/p", "GET", 500);

        logger.indexDefect(doc);
    }
}
