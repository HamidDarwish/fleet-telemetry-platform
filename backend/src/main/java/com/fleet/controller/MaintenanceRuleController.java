package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.model.MaintenanceRule;
import com.fleet.service.MaintenanceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/maintenance-rules")
@RequiredArgsConstructor
public class MaintenanceRuleController {
    private final MaintenanceService maintenance;

    /** Rules with their calculated status; optionally for one vehicle. */
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','MANAGER')")
    public List<Dtos.RuleView> list(@RequestParam(required = false) Long vehicleId) {
        return vehicleId == null ? maintenance.viewsAll() : maintenance.viewsForVehicle(vehicleId);
    }

    @PostMapping
    @PreAuthorize("hasRole('MANAGER')")
    public MaintenanceRule create(@Valid @RequestBody Dtos.RuleRequest r) {
        return maintenance.create(r);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('MANAGER')")
    public MaintenanceRule update(@PathVariable Long id, @Valid @RequestBody Dtos.RuleRequest r) {
        return maintenance.update(id, r);
    }
}
