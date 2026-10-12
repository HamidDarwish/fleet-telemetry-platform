package com.fleet.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "telemetry_records",
       indexes = @Index(name = "idx_telemetry_vehicle_time", columnList = "vehicle_id, ts"))
@Getter
@Setter
@NoArgsConstructor
public class TelemetryRecord {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "vehicle_id", nullable = false)
    private Long vehicleId;

    @Column(name = "ts", nullable = false)
    private Instant timestamp;

    private double latitude;
    private double longitude;
    private double speed;
    private Double heading;
    private Double rpm;
    private double engineTemp;
    private double fuelLevel;
    private double odometer;

    /** DTC codes separated by commas, empty when there is no fault. */
    private String dtcCodes;
}
