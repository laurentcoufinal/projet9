package com.openclassroom.devops.orion.microcrm.opensearch;

import org.opensearch.client.opensearch.OpenSearchClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(name = "opensearch.enabled", havingValue = "true")
public class OpenSearchDefectLogger {

    private static final Logger log = LoggerFactory.getLogger(OpenSearchDefectLogger.class);

    private final OpenSearchClient client;
    private final OpenSearchProperties properties;

    public OpenSearchDefectLogger(OpenSearchClient client, OpenSearchProperties properties) {
        this.client = client;
        this.properties = properties;
    }

    @Async
    public void indexDefect(DefectDocument document) {
        try {
            client.index(i -> i
                    .index(properties.getIndexDefects())
                    .document(document));
            log.debug("Indexed defect for requestId={}", document.requestId());
        } catch (Exception e) {
            log.warn("Failed to index defect in OpenSearch for requestId={}: {}",
                    document.requestId(), e.getMessage());
        }
    }
}
