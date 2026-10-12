package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.*;
import com.fleet.repository.MaintenanceRuleRepository;
import com.fleet.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.NoSuchElementException;

@Service
@RequiredArgsConstructor
public class MaintenanceService {
    private final MaintenanceRuleRepository rules;
    private final VehicleRepository vehicles;
    private final AlertService alerts;
    private final WorkOrderService workOrders;

    @Value("${fleet.maintenance.proactive-percent:90}")
    private double proactivePercent;

    /** Computes how much of the interval is used and the status (FR-6.3). */
    public Dtos.RuleView toView(MaintenanceRule r, Vehicle v) {
        double used;
        double remaining;
        if (r.getType() == RuleType.DISTANCE) {
            double odometer = v.getOdometer() == null ? 0 : v.getOdometer();
            double driven = odometer - r.getLastServiceOdometer();
            used = driven / r.getIntervalValue() * 100.0;
            remaining = r.getIntervalValue() - driven;          // km
        } else {
            LocalDate last = r.getLastServiceDate() == null ? LocalDate.now() : r.getLastServiceDate();
            long days = ChronoUnit.DAYS.between(last, LocalDate.now());
            used = (double) days / r.getIntervalValue() * 100.0;
            remaining = r.getIntervalValue() - days;            // days
        }
        RuleStatus status = used >= 100 ? RuleStatus.DUE : used >= proactivePercent ? RuleStatus.DUE_SOON : RuleStatus.UPCOMING;
        return new Dtos.RuleView(r.getId(), r.getVehicleId(), r.getName(), r.getType(), r.getIntervalValue(),
                r.getLastServiceOdometer(), r.getLastServiceDate(), r.isActive(), status,
                Math.round(used * 10) / 10.0, Math.round(remaining * 10) / 10.0);
    }

    public List<Dtos.RuleView> viewsForVehicle(Long vehicleId) {
        Vehicle v = vehicles.findById(vehicleId).orElseThrow(() -> new NoSuchElementException("Vehicle not found"));
        List<Dtos.RuleView> out = new ArrayList<>();
        for (MaintenanceRule r : rules.findByVehicleId(vehicleId)) out.add(toView(r, v));
        return out;
    }

    public List<Dtos.RuleView> viewsAll() {
        List<Dtos.RuleView> out = new ArrayList<>();
        for (Vehicle v : vehicles.findAll()) {
            for (MaintenanceRule r : rules.findByVehicleId(v.getId())) out.add(toView(r, v));
        }
        return out;
    }

    public MaintenanceRule create(Dtos.RuleRequest req) {
        Vehicle v = vehicles.findById(req.vehicleId()).orElseThrow(() -> new NoSuchElementException("Vehicle not found"));
        MaintenanceRule r = new MaintenanceRule();
        r.setVehicleId(v.getId());
        r.setLastServiceOdometer(v.getOdometer() == null ? 0 : v.getOdometer());
        r.setLastServiceDate(LocalDate.now());
        return rules.save(apply(r, req));
    }

    public MaintenanceRule update(Long id, Dtos.RuleRequest req) {
        MaintenanceRule r = rules.findById(id).orElseThrow(() -> new NoSuchElementException("Rule not found"));
        return rules.save(apply(r, req));
    }

    private MaintenanceRule apply(MaintenanceRule r, Dtos.RuleRequest req) {
        r.setName(req.name());
        r.setType(req.type());
        r.setIntervalValue(req.intervalValue());
        if (req.active() != null) r.setActive(req.active());
        return r;
    }

    /** FR-6.4/6.5/6.6: called on every telemetry message and once a minute. */
    public void evaluateVehicle(Vehicle v) {
        for (MaintenanceRule rule : rules.findByVehicleIdAndActiveTrue(v.getId())) {
            Dtos.RuleView view = toView(rule, v);
            if (view.status() == RuleStatus.DUE) {
                alerts.raise(v, AlertType.MAINTENANCE_DUE, Severity.WARNING,
                        v.getPlate() + ": " + rule.getName() + " is due");
                workOrders.autoCreate(v, WorkOrderSource.RULE, rule.getId(),
                        rule.getName() + " - " + v.getPlate(),
                        "Preventive maintenance rule \"" + rule.getName() + "\" reached its interval.",
                        Priority.MEDIUM);
            } else if (view.status() == RuleStatus.DUE_SOON) {
                alerts.raise(v, AlertType.MAINTENANCE_DUE_SOON, Severity.INFO,
                        v.getPlate() + ": " + rule.getName() + " due soon (" + view.percentUsed() + "% of interval used)");
            }
        }
    }

    /** Needed for time-based rules, which do not change when telemetry arrives. */
    @Scheduled(fixedRate = 60_000, initialDelay = 30_000)
    public void evaluateAll() {
        for (Vehicle v : vehicles.findByActiveTrue()) evaluateVehicle(v);
    }
}
