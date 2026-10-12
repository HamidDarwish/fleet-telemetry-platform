package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.model.Geofence;
import com.fleet.service.GeofenceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/geofences")
@PreAuthorize("hasRole('MANAGER')")
@RequiredArgsConstructor
public class GeofenceController {
    private final GeofenceService geofences;

    @GetMapping
    public List<Geofence> list() {
        return geofences.all();
    }

    @PostMapping
    public Geofence create(@Valid @RequestBody Dtos.GeofenceRequest r) {
        return geofences.create(r);
    }

    @PutMapping("/{id}")
    public Geofence update(@PathVariable Long id, @Valid @RequestBody Dtos.GeofenceRequest r) {
        return geofences.update(id, r);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {
        geofences.delete(id);
    }
}
