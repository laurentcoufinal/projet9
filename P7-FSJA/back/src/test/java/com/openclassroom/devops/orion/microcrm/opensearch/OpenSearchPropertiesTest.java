package com.openclassroom.devops.orion.microcrm.opensearch;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class OpenSearchPropertiesTest {

    @Test
    void defaults_shouldMatchApplicationContract() {
        OpenSearchProperties properties = new OpenSearchProperties();

        assertThat(properties.isEnabled()).isTrue();
        assertThat(properties.getHost()).isEqualTo("localhost");
        assertThat(properties.getPort()).isEqualTo(9200);
        assertThat(properties.getUsername()).isEqualTo("admin");
        assertThat(properties.getPassword()).isEmpty();
        assertThat(properties.getIndexDefects()).isEqualTo("microcrm-defects");
        assertThat(properties.getIndexSecurityEvents()).isEqualTo("microcrm-security-events");
        assertThat(properties.isSecurityAccessLogEnabled()).isTrue();
    }

    @Test
    void setters_shouldUpdateAllFields() {
        OpenSearchProperties properties = new OpenSearchProperties();
        properties.setEnabled(false);
        properties.setHost("opensearch.local");
        properties.setPort(443);
        properties.setUsername("user");
        properties.setPassword("secret");
        properties.setIndexDefects("defects");
        properties.setIndexSecurityEvents("security");
        properties.setSecurityAccessLogEnabled(false);

        assertThat(properties.isEnabled()).isFalse();
        assertThat(properties.getHost()).isEqualTo("opensearch.local");
        assertThat(properties.getPort()).isEqualTo(443);
        assertThat(properties.getUsername()).isEqualTo("user");
        assertThat(properties.getPassword()).isEqualTo("secret");
        assertThat(properties.getIndexDefects()).isEqualTo("defects");
        assertThat(properties.getIndexSecurityEvents()).isEqualTo("security");
        assertThat(properties.isSecurityAccessLogEnabled()).isFalse();
    }
}
