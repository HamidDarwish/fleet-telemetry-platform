package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.AlertType;
import com.fleet.model.Severity;
import com.fleet.model.Vehicle;
import com.fleet.model.VehicleStatus;
import com.fleet.repository.TelemetryRepository;
import com.fleet.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

/** Background jobs: offline detection (FR-5.6) and telemetry retention (FR-4.6). */
@Component
@RequiredArgsConstructor
public class VehicleStatusMonitor {
    private final VehicleRepository vehicles;
    private final TelemetryRepository telemetry;
    private final AlertService alerts;
    private final SimpMessagingTemplate ws;

    @Value("${fleet.vehicle.offline-seconds:60}")
    private long offlineSeconds;

    @Value("${fleet.telemetry.retention-days:30}")
    private long retentionDays;

    @Scheduled(fixedRate = 15_000, initialDelay = 30_000)
    public void markOfflineVehicles() {
        Instant limit = Instant.now().minusSeconds(offlineSeconds);
        for (Vehicle v : vehicles.findByActiveTrue()) {
            if (v.getLastUpdate() != null && v.getLastUpdate().isBefore(limit) && v.getStatus() != VehicleStatus.OFFLINE) {
                v.setStatus(VehicleStatus.OFFLINE);
                vehicles.save(v);
                alerts.raise(v, AlertType.VEHICLE_OFFLINE, Severity.WARNING,
                        v.getPlate() + ": no data for " + offlineSeconds + " seconds");
                ws.convertAndSend("/topic/telemetry", new Dtos.LiveUpdate(v.getId(), v.getPlate(),
                        orZero(v.getCurrentLat()), orZero(v.getCurrentLng()), 0,
                        orZero(v.getFuelLevel()), orZero(v.getEngineTemp()), orZero(v.getOdometer()),
                        VehicleStatus.OFFLINE, Instant.now()));
            }
        }
    }

    @Scheduled(cron = "0 30 3 * * *")
    @Transactional
    public void purgeOldTelemetry() {
        telemetry.deleteOlderThan(Instant.now().minus(retentionDays, ChronoUnit.DAYS));
    }

    private static double orZero(Double d) {
        return d == null ? 0 : d;
    }
}
