package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.model.User;
import com.fleet.model.WorkOrder;
import com.fleet.service.UserService;
import com.fleet.service.WorkOrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/work-orders")
@PreAuthorize("hasAnyRole('MANAGER','TECHNICIAN')")
@RequiredArgsConstructor
public class WorkOrderController {
    private final WorkOrderService workOrders;
    private final UserService userService;

    @GetMapping
    public List<WorkOrder> list(Authentication auth) {
        return workOrders.list(userService.current(auth));
    }

    @PostMapping
    @PreAuthorize("hasRole('MANAGER')")
    public WorkOrder create(@Valid @RequestBody Dtos.WorkOrderRequest r) {
        return workOrders.create(r);
    }

    /** Assign (manager), change status, add notes/parts/cost (manager or the assigned technician). */
    @PutMapping("/{id}")
    public WorkOrder update(@PathVariable Long id, @RequestBody Dtos.WorkOrderUpdate r, Authentication auth) {
        User actor = userService.current(auth);
        return workOrders.update(id, r, actor);
    }

    /** Technicians for the "assign" drop-down. */
    @GetMapping("/technicians")
    @PreAuthorize("hasRole('MANAGER')")
    public List<User> technicians() {
        return userService.all().stream()
                .filter(u -> u.getRole() == com.fleet.model.Role.TECHNICIAN && u.isActive())
                .toList();
    }
}
