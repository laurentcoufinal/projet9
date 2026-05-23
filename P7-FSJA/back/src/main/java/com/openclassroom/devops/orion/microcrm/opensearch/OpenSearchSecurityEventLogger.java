package com.openclassroom.devops.orion.microcrm.opensearch;

import org.opensearch.client.opensearch.OpenSearchClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(name = "opensearch.enabled", havingValue = "true")
public class OpenSearchSecurityEventLogger {

    private static final Logger log = LoggerFactory.getLogger(OpenSearchSecurityEventLogger.class);

    private final OpenSearchClient client;
    private final OpenSearchProperties properties;

    public OpenSearchSecurityEventLogger(OpenSearchClient client, OpenSearchProperties properties) {
        this.client = client;
        this.properties = properties;
    }

    @Async
    public void indexSecurityEvent(SecurityEventDocument document) {
        try {
            client.index(i -> i
                    .index(properties.getIndexSecurityEvents())
                    .document(document));
            log.debug("Indexed security event for requestId={}", document.requestId());
        } catch (Exception e) {
            log.warn("Failed to index security event for requestId={}: {}",
                    document.requestId(), e.getMessage());
        }
    }
}
