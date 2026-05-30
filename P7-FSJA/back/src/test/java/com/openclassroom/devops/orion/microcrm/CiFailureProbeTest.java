package com.openclassroom.devops.orion.microcrm;

import static org.junit.jupiter.api.Assertions.fail;

import org.junit.jupiter.api.Test;

/**
 * Sonde volontaire pour tester l'échec CI GitHub Actions et la notification Slack.
 * Supprimer ce fichier (ou désactiver le test) après validation.
 */
class CiFailureProbeTest {

    @Test
    void intentionalFailureForGithubCiAndSlackAlert() {
        fail("Échec CI intentionnel — test pipeline GitHub + alerte Slack (supprimer CiFailureProbeTest.java après vérif)");
    }
}
