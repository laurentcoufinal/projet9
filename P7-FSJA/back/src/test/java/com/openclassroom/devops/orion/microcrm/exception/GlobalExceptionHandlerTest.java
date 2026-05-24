package com.openclassroom.devops.orion.microcrm.exception;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.MethodParameter;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.web.bind.MethodArgumentNotValidException;

import com.openclassroom.devops.orion.microcrm.Person;
import com.openclassroom.devops.orion.microcrm.opensearch.DefectDocument;
import com.openclassroom.devops.orion.microcrm.opensearch.OpenSearchDefectLogger;
import com.openclassroom.devops.orion.microcrm.web.RequestIdFilter;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Path;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GlobalExceptionHandlerTest {

    @Mock
    private ObjectProvider<OpenSearchDefectLogger> defectLoggerProvider;

    @Mock
    private OpenSearchDefectLogger defectLogger;

    @Mock
    private HttpServletRequest request;

    private GlobalExceptionHandler handler;

    @BeforeEach
    void setUp() {
        doAnswer(invocation -> {
            @SuppressWarnings("unchecked")
            var consumer = (java.util.function.Consumer<OpenSearchDefectLogger>) invocation.getArgument(0);
            consumer.accept(defectLogger);
            return null;
        }).when(defectLoggerProvider).ifAvailable(any());
        handler = new GlobalExceptionHandler(defectLoggerProvider);
        when(request.getRequestURI()).thenReturn("/persons");
        when(request.getMethod()).thenReturn("POST");
    }

    @Test
    void handleValidation_shouldReturnBadRequestWithFieldErrors() throws Exception {
        when(request.getAttribute(RequestIdFilter.REQUEST_ATTRIBUTE)).thenReturn("req-val");
        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult(new Person(), "person");
        bindingResult.rejectValue("email", "NotBlank", "must not be blank");
        MethodParameter parameter = new MethodParameter(
                Person.class.getDeclaredConstructor(String.class, String.class, String.class), 0);
        MethodArgumentNotValidException ex = new MethodArgumentNotValidException(parameter, bindingResult);

        ResponseEntity<?> response = handler.handleValidation(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isInstanceOfSatisfying(java.util.Map.class, body -> {
            assertThat(body.get("message")).asString().contains("email");
            assertThat(body.get("requestId")).isEqualTo("req-val");
        });
        verifyDefectIndexed("req-val", 400);
    }

    @Test
    void handleConstraintViolation_shouldReturnBadRequest() {
        when(request.getHeader(RequestIdFilter.HEADER_NAME)).thenReturn("req-cv");
        @SuppressWarnings("unchecked")
        ConstraintViolation<Object> violation = org.mockito.Mockito.mock(ConstraintViolation.class);
        Path path = org.mockito.Mockito.mock(Path.class);
        when(path.toString()).thenReturn("email");
        when(violation.getPropertyPath()).thenReturn(path);
        when(violation.getMessage()).thenReturn("invalid email");
        ConstraintViolationException ex = new ConstraintViolationException(Set.of(violation));

        ResponseEntity<?> response = handler.handleConstraintViolation(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isInstanceOfSatisfying(java.util.Map.class, body ->
                assertThat(body.get("requestId")).isEqualTo("req-cv"));
        verifyDefectIndexed("req-cv", 400);
    }

    @Test
    void handleDataIntegrity_shouldReturnConflict() {
        when(request.getAttribute(RequestIdFilter.REQUEST_ATTRIBUTE)).thenReturn("req-di");
        DataIntegrityViolationException ex = new DataIntegrityViolationException("duplicate");

        ResponseEntity<?> response = handler.handleDataIntegrity(ex, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody()).isInstanceOfSatisfying(java.util.Map.class, body -> {
            assertThat(body.get("message")).isEqualTo("Data integrity violation");
            assertThat(body.get("requestId")).isEqualTo("req-di");
        });
        verifyDefectIndexed("req-di", 409);
    }

    @Test
    void handleGeneric_shouldReturnInternalServerError() {
        ResponseEntity<?> response = handler.handleGeneric(new RuntimeException("boom"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody()).isInstanceOfSatisfying(java.util.Map.class, body -> {
            assertThat(body.get("message")).isEqualTo("Internal server error");
            assertThat(body.get("requestId")).isEqualTo("unknown");
        });
        verifyDefectIndexed("unknown", 500);
    }

    @Test
    void handleGeneric_shouldTruncateVeryLongStackTrace() {
        RuntimeException ex = new RuntimeException("deep") {
            @Override
            public void printStackTrace(java.io.PrintWriter writer) {
                writer.write("x".repeat(9000));
            }
        };

        handler.handleGeneric(ex, request);

        ArgumentCaptor<DefectDocument> captor = ArgumentCaptor.forClass(DefectDocument.class);
        verify(defectLogger).indexDefect(captor.capture());
        assertThat(captor.getValue().stackTrace()).contains("truncated");
    }

    @Test
    void shouldNotIndexDefectWhenLoggerUnavailable() {
        org.mockito.Mockito.reset(defectLoggerProvider);
        GlobalExceptionHandler handlerWithoutLogger = new GlobalExceptionHandler(defectLoggerProvider);

        handlerWithoutLogger.handleGeneric(new RuntimeException("no logger"), request);

        verifyNoInteractions(defectLogger);
    }

    private void verifyDefectIndexed(String requestId, int status) {
        ArgumentCaptor<DefectDocument> captor = ArgumentCaptor.forClass(DefectDocument.class);
        verify(defectLogger).indexDefect(captor.capture());
        DefectDocument doc = captor.getValue();
        assertThat(doc.requestId()).isEqualTo(requestId);
        assertThat(doc.status()).isEqualTo(status);
        assertThat(doc.path()).isEqualTo("/persons");
        assertThat(doc.method()).isEqualTo("POST");
    }
}
