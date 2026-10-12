package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.service.TelemetryService;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Valid;
import jakarta.validation.Validator;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;

/**
 * Ingestion endpoints for real devices or an external simulator (FR-4.1, FR-4.5).
 * For now the caller must log in as ADMIN; device API keys can replace this later.
 */
@RestController
@RequestMapping("/api/telemetry")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class TelemetryController {
    private final TelemetryService telemetry;
    private final Validator validator;

    @PostMapping
    public Dtos.LiveUpdate ingest(@Valid @RequestBody Dtos.TelemetryDto d) {
        return telemetry.ingest(d);
    }

    /** The whole batch is rejected (400) if any message has an invalid structure or value range. */
    @PostMapping("/batch")
    public Dtos.BatchResult ingestBatch(@RequestBody List<Dtos.TelemetryDto> batch) {
        for (int i = 0; i < batch.size(); i++) {
            Set<ConstraintViolation<Dtos.TelemetryDto>> violations = validator.validate(batch.get(i));
            if (!violations.isEmpty()) {
                ConstraintViolation<Dtos.TelemetryDto> first = violations.iterator().next();
                throw new IllegalArgumentException("Message #" + i + ": " + first.getPropertyPath() + " " + first.getMessage());
            }
        }
        return telemetry.ingestBatch(batch);
    }
}
