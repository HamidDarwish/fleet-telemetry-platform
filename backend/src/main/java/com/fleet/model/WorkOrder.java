package com.fleet.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "work_orders")
@Getter
@Setter
@NoArgsConstructor
public class WorkOrder {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "vehicle_id", nullable = false)
    private Long vehicleId;

    private String vehiclePlate;

    @Enumerated(EnumType.STRING)
    private WorkOrderSource source = WorkOrderSource.MANUAL;

    /** Set when the work order was created by a maintenance rule. */
    private Long ruleId;

    private String title;

    @Column(length = 1000)
    private String description;

    @Enumerated(EnumType.STRING)
    private Priority priority = Priority.MEDIUM;

    @Enumerated(EnumType.STRING)
    private WorkOrderStatus status = WorkOrderStatus.OPEN;

    @ManyToOne
    @JoinColumn(name = "assigned_to_id")
    private User assignedTo;

    @Column(length = 1000)
    private String notes;

    @Column(length = 500)
    private String parts;

    private Double cost;
    private Instant createdAt;
    private Instant completedAt;
}
