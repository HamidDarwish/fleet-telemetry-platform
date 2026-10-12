package com.fleet.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "geofences")
@Getter
@Setter
@NoArgsConstructor
public class Geofence {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private double centerLat;
    private double centerLng;
    private double radiusMeters;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "geofence_vehicles", joinColumns = @JoinColumn(name = "geofence_id"))
    @Column(name = "vehicle_id")
    private Set<Long> vehicleIds = new HashSet<>();
}
