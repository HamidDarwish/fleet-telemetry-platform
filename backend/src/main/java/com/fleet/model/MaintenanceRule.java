package com.fleet.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

@Entity
@Table(name = "maintenance_rules")
@Getter
@Setter
@NoArgsConstructor
public class MaintenanceRule {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "vehicle_id", nullable = false)
    private Long vehicleId;

    private String name;

    @Enumerated(EnumType.STRING)
    private RuleType type;

    /** Kilometers for DISTANCE rules, days for TIME rules. */
    private int intervalValue;

    private double lastServiceOdometer;
    private LocalDate lastServiceDate;
    private boolean active = true;
}
