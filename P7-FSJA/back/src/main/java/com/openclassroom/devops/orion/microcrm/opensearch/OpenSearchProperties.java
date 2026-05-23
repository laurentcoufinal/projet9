package com.openclassroom.devops.orion.microcrm.opensearch;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "opensearch")
public class OpenSearchProperties {

    private boolean enabled = true;
    private String host = "localhost";
    private int port = 9200;
    private String username = "admin";
    private String password = "";
    private String indexDefects = "microcrm-defects";

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getIndexDefects() {
        return indexDefects;
    }

    public void setIndexDefects(String indexDefects) {
        this.indexDefects = indexDefects;
    }
}
