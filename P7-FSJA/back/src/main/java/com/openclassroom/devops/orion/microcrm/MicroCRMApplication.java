package com.openclassroom.devops.orion.microcrm;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableAsync;

import com.openclassroom.devops.orion.microcrm.opensearch.OpenSearchProperties;

@EnableAsync
@EnableConfigurationProperties(OpenSearchProperties.class)
@SpringBootApplication
public class MicroCRMApplication {

	public static void main(String[] args) {
		SpringApplication.run(MicroCRMApplication.class, args);
	}
}
