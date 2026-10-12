package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.*;
import com.fleet.repository.AlertRepository;
import com.fleet.repository.TelemetryRepository;
import com.fleet.repository.VehicleRepository;
import com.fleet.repository.WorkOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {
    private final VehicleRepository vehicles;
    private final AlertRepository alerts;
    private final WorkOrderRepository workOrders;
    private final TelemetryRepository telemetry;
    private final MaintenanceService maintenance;

    /** FR-5.5 */
    public Dtos.DashboardDto summary() {
        List<Vehicle> active = vehicles.findByActiveTrue();
        long online = active.stream().filter(v -> v.getStatus() != VehicleStatus.OFFLINE).count();
        long critical = active.stream().filter(v -> v.getStatus() == VehicleStatus.CRITICAL).count();
        long due = active.stream()
                .flatMap(v -> maintenance.viewsForVehicle(v.getId()).stream())
                .filter(r -> r.active() && r.status() == RuleStatus.DUE)
                .count();
        return new Dtos.DashboardDto(
                vehicles.count(), online, critical,
                alerts.countByAcknowledgedFalse(),
                workOrders.countByStatusIn(List.of(WorkOrderStatus.OPEN, WorkOrderStatus.IN_PROGRESS)),
                due);
    }

    /** FR-10.1 (summary data; PDF/Excel export is not part of this first version). */
    public List<Dtos.ReportRow> report(int days) {
        Instant since = Instant.now().minus(Math.max(1, days), ChronoUnit.DAYS);
        return vehicles.findAll().stream().map(v -> {
            Double distance = telemetry.distanceSince(v.getId(), since);
            List<WorkOrder> done = workOrders.findByVehicleIdOrderByCreatedAtDesc(v.getId()).stream()
                    .filter(w -> w.getStatus() == WorkOrderStatus.COMPLETED
                            && w.getCompletedAt() != null && w.getCompletedAt().isAfter(since))
                    .toList();
            double cost = done.stream().mapToDouble(w -> w.getCost() == null ? 0 : w.getCost()).sum();
            return new Dtos.ReportRow(v.getId(), v.getPlate(),
                    distance == null ? 0 : Math.round(distance * 10) / 10.0,
                    cost, alerts.countByVehicleIdAndCreatedAtAfter(v.getId(), since), done.size());
        }).toList();
    }
}
