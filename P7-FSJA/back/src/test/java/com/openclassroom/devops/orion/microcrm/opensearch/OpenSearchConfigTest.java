package com.openclassroom.devops.orion.microcrm.opensearch;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.opensearch.client.opensearch.OpenSearchClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@TestPropertySource(properties = {
        "opensearch.enabled=true",
        "opensearch.host=localhost",
        "opensearch.port=9200",
        "opensearch.username=admin",
        "opensearch.password=admin"
})
class OpenSearchConfigTest {

    @Autowired
    private OpenSearchClient openSearchClient;

    @Test
    void openSearchClientBean_shouldBeCreatedWhenEnabled() {
        assertThat(openSearchClient).isNotNull();
    }
}
