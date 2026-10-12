package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.AlertType;
import com.fleet.model.Geofence;
import com.fleet.model.Severity;
import com.fleet.model.Vehicle;
import com.fleet.repository.GeofenceRepository;
import com.fleet.util.GeoUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class GeofenceService {
    private final GeofenceRepository geofences;
    private final AlertService alerts;

    /** Last known inside/outside state per (vehicle, geofence). */
    private final Map<String, Boolean> insideState = new ConcurrentHashMap<>();

    public List<Geofence> all() {
        return geofences.findAll();
    }

    public Geofence create(Dtos.GeofenceRequest r) {
        return geofences.save(apply(new Geofence(), r));
    }

    public Geofence update(Long id, Dtos.GeofenceRequest r) {
        Geofence g = geofences.findById(id).orElseThrow(() -> new NoSuchElementException("Geofence not found"));
        return geofences.save(apply(g, r));
    }

    public void delete(Long id) {
        geofences.deleteById(id);
    }

    private Geofence apply(Geofence g, Dtos.GeofenceRequest r) {
        g.setName(r.name());
        g.setCenterLat(r.centerLat());
        g.setCenterLng(r.centerLng());
        g.setRadiusMeters(r.radiusMeters());
        g.setVehicleIds(r.vehicleIds() == null ? new HashSet<>() : new HashSet<>(r.vehicleIds()));
        return g;
    }

    /** FR-9.3: raises an alert when a vehicle enters or leaves an assigned geofence. */
    public void check(Vehicle v, double lat, double lng) {
        for (Geofence g : geofences.findAll()) {
            if (!g.getVehicleIds().contains(v.getId())) continue;
            boolean inside = GeoUtils.distanceMeters(lat, lng, g.getCenterLat(), g.getCenterLng()) <= g.getRadiusMeters();
            Boolean before = insideState.put(v.getId() + ":" + g.getId(), inside);
            if (before != null && before != inside) {
                alerts.raise(v,
                        inside ? AlertType.GEOFENCE_ENTER : AlertType.GEOFENCE_EXIT,
                        inside ? Severity.INFO : Severity.WARNING,
                        v.getPlate() + (inside ? " entered " : " left ") + g.getName());
            }
        }
    }
}
