package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.*;
import com.fleet.repository.MaintenanceRuleRepository;
import com.fleet.repository.UserRepository;
import com.fleet.repository.VehicleRepository;
import com.fleet.repository.WorkOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.NoSuchElementException;

@Service
@RequiredArgsConstructor
public class WorkOrderService {
    private static final List<WorkOrderStatus> ACTIVE = List.of(WorkOrderStatus.OPEN, WorkOrderStatus.IN_PROGRESS);

    private final WorkOrderRepository orders;
    private final VehicleRepository vehicles;
    private final UserRepository users;
    private final MaintenanceRuleRepository rules;

    public List<WorkOrder> list(User viewer) {
        return viewer.getRole() == Role.TECHNICIAN
                ? orders.findByAssignedToIdOrderByCreatedAtDesc(viewer.getId())
                : orders.findAllByOrderByCreatedAtDesc();
    }

    /** Manual creation by a manager (FR-7.1). */
    public WorkOrder create(Dtos.WorkOrderRequest r) {
        Vehicle v = vehicles.findById(r.vehicleId()).orElseThrow(() -> new NoSuchElementException("Vehicle not found"));
        WorkOrder w = newOrder(v, WorkOrderSource.MANUAL, null, r.title(), r.description(),
                r.priority() == null ? Priority.MEDIUM : r.priority());
        if (r.assignedToId() != null) w.setAssignedTo(technician(r.assignedToId()));
        return orders.save(w);
    }

    /** Automatic creation (rules, DTC, sensors). Returns null when an open work order for the same cause exists (FR-6.6). */
    public WorkOrder autoCreate(Vehicle v, WorkOrderSource source, Long ruleId, String title,
                                String description, Priority priority) {
        boolean exists = ruleId != null
                ? orders.existsByRuleIdAndStatusIn(ruleId, ACTIVE)
                : orders.existsByVehicleIdAndSourceAndStatusIn(v.getId(), source, ACTIVE);
        if (exists) return null;
        return orders.save(newOrder(v, source, ruleId, title, description, priority));
    }

    public WorkOrder update(Long id, Dtos.WorkOrderUpdate r, User actor) {
        WorkOrder w = orders.findById(id).orElseThrow(() -> new NoSuchElementException("Work order not found"));
        boolean technician = actor.getRole() == Role.TECHNICIAN;
        if (technician) {
            if (w.getAssignedTo() == null || !w.getAssignedTo().getId().equals(actor.getId()))
                throw new AccessDeniedException("This work order is not assigned to you");
        } else if (r.assignedToId() != null) {
            w.setAssignedTo(technician(r.assignedToId()));
        }
        if (r.notes() != null) w.setNotes(r.notes());
        if (r.parts() != null) w.setParts(r.parts());
        if (r.cost() != null) w.setCost(r.cost());
        if (r.status() != null && r.status() != w.getStatus()) changeStatus(w, r.status(), actor);
        return orders.save(w);
    }

    // ---------- helpers ----------

    private WorkOrder newOrder(Vehicle v, WorkOrderSource source, Long ruleId, String title,
                               String description, Priority priority) {
        WorkOrder w = new WorkOrder();
        w.setVehicleId(v.getId());
        w.setVehiclePlate(v.getPlate());
        w.setSource(source);
        w.setRuleId(ruleId);
        w.setTitle(title);
        w.setDescription(description);
        w.setPriority(priority);
        w.setStatus(WorkOrderStatus.OPEN);
        w.setCreatedAt(Instant.now());
        return w;
    }

    private User technician(Long id) {
        User u = users.findById(id).orElseThrow(() -> new NoSuchElementException("Technician not found"));
        if (u.getRole() != Role.TECHNICIAN) throw new IllegalArgumentException("Selected user is not a technician");
        return u;
    }

    /** OPEN -> IN_PROGRESS/CANCELLED, IN_PROGRESS -> COMPLETED/CANCELLED (FR-7.3). */
    private void changeStatus(WorkOrder w, WorkOrderStatus next, User actor) {
        WorkOrderStatus cur = w.getStatus();
        boolean allowed = (cur == WorkOrderStatus.OPEN
                && (next == WorkOrderStatus.IN_PROGRESS || next == WorkOrderStatus.CANCELLED))
                || (cur == WorkOrderStatus.IN_PROGRESS
                && (next == WorkOrderStatus.COMPLETED || next == WorkOrderStatus.CANCELLED));
        if (!allowed) throw new IllegalArgumentException("Invalid status change: " + cur + " -> " + next);
        if (next == WorkOrderStatus.CANCELLED && actor.getRole() == Role.TECHNICIAN)
            throw new AccessDeniedException("Only a manager can cancel a work order");
        w.setStatus(next);
        if (next == WorkOrderStatus.COMPLETED) {
            w.setCompletedAt(Instant.now());
            restartRule(w);
        }
    }

    /** FR-6.7: after completion the linked rule restarts from the current odometer and date. */
    private void restartRule(WorkOrder w) {
        if (w.getRuleId() == null) return;
        rules.findById(w.getRuleId()).ifPresent(rule -> {
            vehicles.findById(w.getVehicleId()).ifPresent(v -> {
                if (v.getOdometer() != null) rule.setLastServiceOdometer(v.getOdometer());
            });
            rule.setLastServiceDate(LocalDate.now());
            rules.save(rule);
        });
    }
}
