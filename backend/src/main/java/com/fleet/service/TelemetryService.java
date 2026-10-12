package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.*;
import com.fleet.repository.TelemetryRepository;
import com.fleet.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * The single entry point for telemetry. The simulator calls ingest() directly and a real device
 * would call it through POST /api/telemetry, so both paths behave identically (SIM-6).
 */
@Service
@RequiredArgsConstructor
public class TelemetryService {
    private final VehicleRepository vehicles;
    private final TelemetryRepository telemetry;
    private final AlertService alerts;
    private final WorkOrderService workOrders;
    private final GeofenceService geofences;
    private final MaintenanceService maintenance;
    private final SimpMessagingTemplate ws;

    @Value("${fleet.alert.overheat-warning:105}")  private double overheatWarning;
    @Value("${fleet.alert.overheat-critical:115}") private double overheatCritical;
    @Value("${fleet.alert.overspeed:100}")         private double overspeed;
    @Value("${fleet.alert.low-fuel:15}")           private double lowFuel;

    public Dtos.LiveUpdate ingest(Dtos.TelemetryDto d) {
        Vehicle v = vehicles.findById(d.vehicleId())
                .orElseThrow(() -> new IllegalArgumentException("Unknown vehicle id " + d.vehicleId()));
        if (!v.isActive()) throw new IllegalArgumentException("Vehicle is not active");

        double previousOdometer = v.getOdometer() == null ? 0 : v.getOdometer();
        if (d.odometer() < previousOdometer)
            throw new IllegalArgumentException("Odometer cannot be lower than the previous value (" + previousOdometer + ")");

        Instant ts = d.timestamp() != null ? d.timestamp() : Instant.now();
        List<String> dtc = d.dtcCodes() == null ? List.of() : d.dtcCodes();

        // FR-4.2: store the record
        TelemetryRecord rec = new TelemetryRecord();
        rec.setVehicleId(v.getId());
        rec.setTimestamp(ts);
        rec.setLatitude(d.latitude());
        rec.setLongitude(d.longitude());
        rec.setSpeed(d.speed());
        rec.setHeading(d.heading());
        rec.setRpm(d.rpm());
        rec.setEngineTemp(d.engineTemp());
        rec.setFuelLevel(d.fuelLevel());
        rec.setOdometer(d.odometer());
        rec.setDtcCodes(String.join(",", dtc));
        telemetry.save(rec);

        // FR-4.3: update the current state of the vehicle
        v.setCurrentLat(d.latitude());
        v.setCurrentLng(d.longitude());
        v.setSpeed(d.speed());
        v.setFuelLevel(d.fuelLevel());
        v.setEngineTemp(d.engineTemp());
        v.setOdometer(d.odometer());
        v.setStatus(computeStatus(d, dtc));
        v.setLastUpdate(Instant.now());
        vehicles.save(v);

        raiseAlerts(v, d, dtc);
        geofences.check(v, d.latitude(), d.longitude());
        maintenance.evaluateVehicle(v);

        Dtos.LiveUpdate update = new Dtos.LiveUpdate(v.getId(), v.getPlate(), d.latitude(), d.longitude(),
                d.speed(), d.fuelLevel(), d.engineTemp(), d.odometer(), v.getStatus(), ts);
        ws.convertAndSend("/topic/telemetry", update);
        return update;
    }

    /** FR-4.5: batch of buffered messages, processed oldest first. */
    public Dtos.BatchResult ingestBatch(List<Dtos.TelemetryDto> batch) {
        List<Dtos.TelemetryDto> sorted = new ArrayList<>(batch);
        sorted.sort(Comparator.comparing(Dtos.TelemetryDto::timestamp, Comparator.nullsLast(Comparator.naturalOrder())));
        int accepted = 0;
        List<String> errors = new ArrayList<>();
        for (int i = 0; i < sorted.size(); i++) {
            try {
                ingest(sorted.get(i));
                accepted++;
            } catch (RuntimeException e) {
                errors.add("#" + i + ": " + e.getMessage());
            }
        }
        return new Dtos.BatchResult(accepted, errors);
    }

    /** FR-5.4: recent history of one vehicle (used for the trip trail). */
    public List<TelemetryRecord> history(Long vehicleId, int minutes) {
        Instant to = Instant.now();
        Instant from = to.minus(Math.max(1, minutes), ChronoUnit.MINUTES);
        return telemetry.findByVehicleIdAndTimestampBetweenOrderByTimestampAsc(vehicleId, from, to);
    }

    private VehicleStatus computeStatus(Dtos.TelemetryDto d, List<String> dtc) {
        if (d.engineTemp() >= overheatCritical || !dtc.isEmpty()) return VehicleStatus.CRITICAL;
        if (d.engineTemp() >= overheatWarning || d.speed() > overspeed || d.fuelLevel() < lowFuel)
            return VehicleStatus.WARNING;
        return VehicleStatus.NORMAL;
    }

    private void raiseAlerts(Vehicle v, Dtos.TelemetryDto d, List<String> dtc) {
        String plate = v.getPlate();
        if (d.engineTemp() >= overheatCritical) {
            alerts.raise(v, AlertType.ENGINE_OVERHEAT, Severity.CRITICAL,
                    plate + ": engine temperature " + Math.round(d.engineTemp()) + " °C");
            workOrders.autoCreate(v, WorkOrderSource.SENSOR, null, "Engine overheating - " + plate,
                    "Engine temperature reached " + Math.round(d.engineTemp()) + " °C.", Priority.CRITICAL);
        } else if (d.engineTemp() >= overheatWarning) {
            alerts.raise(v, AlertType.ENGINE_OVERHEAT, Severity.WARNING,
                    plate + ": engine temperature " + Math.round(d.engineTemp()) + " °C");
        }
        if (d.speed() > overspeed) {
            alerts.raise(v, AlertType.OVER_SPEED, Severity.WARNING,
                    plate + ": speed " + Math.round(d.speed()) + " km/h");
        }
        if (d.fuelLevel() < lowFuel) {
            alerts.raise(v, AlertType.LOW_FUEL, Severity.WARNING,
                    plate + ": fuel level " + Math.round(d.fuelLevel()) + "%");
        }
        if (!dtc.isEmpty()) {
            String codes = String.join(", ", dtc);
            alerts.raise(v, AlertType.DTC_ERROR, Severity.CRITICAL, plate + ": fault code " + codes);
            workOrders.autoCreate(v, WorkOrderSource.DTC, null, "Fault code " + codes + " - " + plate,
                    "The vehicle reported diagnostic trouble code(s): " + codes, Priority.HIGH);
        }
    }
}
