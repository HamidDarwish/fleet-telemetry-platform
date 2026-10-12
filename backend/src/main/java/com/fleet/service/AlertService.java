package com.fleet.service;

import com.fleet.model.*;
import com.fleet.repository.AlertRepository;
import com.fleet.repository.VehicleRepository;
import com.fleet.repository.WorkOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AlertService {
    private final AlertRepository alerts;
    private final VehicleRepository vehicles;
    private final WorkOrderRepository workOrders;
    private final SimpMessagingTemplate ws;

    @Value("${fleet.alert.cooldown-seconds:300}")
    private long cooldownSeconds;

    /** Last time an alert of (vehicle, type) was created - used to suppress repeats (FR-8.4). */
    private final Map<String, Instant> lastRaised = new ConcurrentHashMap<>();

    /** Creates an alert and pushes it to /topic/alerts. Returns null when suppressed by the cooldown. */
    public Alert raise(Vehicle v, AlertType type, Severity severity, String message) {
        String key = v.getId() + ":" + type;
        Instant now = Instant.now();
        Instant previous = lastRaised.get(key);
        if (previous != null && now.isBefore(previous.plusSeconds(cooldownSeconds))) return null;
        lastRaised.put(key, now);

        Alert a = new Alert();
        a.setVehicleId(v.getId());
        a.setVehiclePlate(v.getPlate());
        a.setType(type);
        a.setSeverity(severity);
        a.setMessage(message);
        a.setCreatedAt(now);
        Alert saved = alerts.save(a);
        ws.convertAndSend("/topic/alerts", saved);
        return saved;
    }

    public List<Alert> list(User viewer, AlertType type, Severity severity, Long vehicleId, Boolean acknowledged) {
        Set<Long> allowed = allowedVehicleIds(viewer);
        return alerts.findTop200ByOrderByCreatedAtDesc().stream()
                .filter(a -> allowed == null || allowed.contains(a.getVehicleId()))
                .filter(a -> type == null || a.getType() == type)
                .filter(a -> severity == null || a.getSeverity() == severity)
                .filter(a -> vehicleId == null || a.getVehicleId().equals(vehicleId))
                .filter(a -> acknowledged == null || a.isAcknowledged() == acknowledged)
                .collect(Collectors.toList());
    }

    public Alert acknowledge(Long id, User viewer) {
        Alert a = alerts.findById(id).orElseThrow(() -> new NoSuchElementException("Alert not found"));
        Set<Long> allowed = allowedVehicleIds(viewer);
        if (allowed != null && !allowed.contains(a.getVehicleId()))
            throw new AccessDeniedException("Not allowed to acknowledge this alert");
        a.setAcknowledged(true);
        a.setAcknowledgedBy(viewer.getName());
        a.setAcknowledgedAt(Instant.now());
        return alerts.save(a);
    }

    /** null = all vehicles; driver = own vehicle; technician = vehicles of his/her work orders (FR-8.6). */
    private Set<Long> allowedVehicleIds(User u) {
        if (u.getRole() == Role.DRIVER) {
            return vehicles.findByDriverId(u.getId()).stream().map(Vehicle::getId).collect(Collectors.toSet());
        }
        if (u.getRole() == Role.TECHNICIAN) {
            return workOrders.findByAssignedToIdOrderByCreatedAtDesc(u.getId()).stream()
                    .map(WorkOrder::getVehicleId).collect(Collectors.toSet());
        }
        return null;
    }
}
