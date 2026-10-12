package com.fleet.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "vehicles")
@Getter
@Setter
@NoArgsConstructor
public class Vehicle {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String plate;

    private String model;
    @Column(name = "model_year")
    private Integer year;
    private String fuelType;
    private Double tankCapacity;
    private boolean active = true;

    @Enumerated(EnumType.STRING)
    private VehicleStatus status = VehicleStatus.NORMAL;

    @ManyToOne
    @JoinColumn(name = "driver_id")
    private User driver;

    // current state, updated on every telemetry message
    private Double currentLat;
    private Double currentLng;
    private Double speed;
    private Double fuelLevel;
    private Double engineTemp;
    private Double odometer = 0.0;
    private Instant lastUpdate;
}
