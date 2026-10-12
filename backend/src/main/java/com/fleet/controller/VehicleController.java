package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.model.TelemetryRecord;
import com.fleet.model.Vehicle;
import com.fleet.service.TelemetryService;
import com.fleet.service.UserService;
import com.fleet.service.VehicleService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/vehicles")
@RequiredArgsConstructor
public class VehicleController {
    private final VehicleService vehicleService;
    private final UserService userService;
    private final TelemetryService telemetryService;

    @GetMapping
    public List<Vehicle> list(Authentication auth) {
        return vehicleService.list(userService.current(auth));
    }

    @GetMapping("/{id}")
    public Vehicle get(@PathVariable Long id, Authentication auth) {
        return vehicleService.get(id, userService.current(auth));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','MANAGER')")
    public Vehicle create(@Valid @RequestBody Dtos.VehicleRequest r) {
        return vehicleService.create(r);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','MANAGER')")
    public Vehicle update(@PathVariable Long id, @Valid @RequestBody Dtos.VehicleRequest r) {
        return vehicleService.update(id, r);
    }

    /** Recent telemetry of one vehicle, oldest first (trip trail). */
    @GetMapping("/{id}/telemetry")
    @PreAuthorize("hasAnyRole('ADMIN','MANAGER','DRIVER')")
    public List<TelemetryRecord> history(@PathVariable Long id,
                                         @RequestParam(defaultValue = "30") int minutes,
                                         Authentication auth) {
        vehicleService.get(id, userService.current(auth));   // access check (a driver only sees own vehicle)
        return telemetryService.history(id, minutes);
    }
}
