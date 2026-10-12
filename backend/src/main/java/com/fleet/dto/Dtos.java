package com.fleet.dto;

import com.fleet.model.*;
import jakarta.validation.constraints.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;

/** All request/response objects of the REST API in one place. */
public final class Dtos {
    private Dtos() {}

    // ----- auth & users -----
    public record LoginRequest(@NotBlank String email, @NotBlank String password) {}

    public record LoginResponse(String token, Long userId, String name, String role) {}

    public record UserRequest(@NotBlank String name, @NotBlank @Email String email,
                              String password, @NotNull Role role, Boolean active) {}

    // ----- vehicles -----
    public record VehicleRequest(@NotBlank String plate, String model, Integer year, String fuelType,
                                 Double tankCapacity, Double odometer, Long driverId, Boolean active) {}

    // ----- telemetry (Appendix A of the SRS) -----
    public record TelemetryDto(
            @NotNull Long vehicleId,
            Instant timestamp,
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude,
            @NotNull @DecimalMin("0") @DecimalMax("250") Double speed,
            @DecimalMin("0") @DecimalMax("359.99") Double heading,
            @DecimalMin("0") @DecimalMax("8000") Double rpm,
            @NotNull @DecimalMin("-40") @DecimalMax("150") Double engineTemp,
            @NotNull @DecimalMin("0") @DecimalMax("100") Double fuelLevel,
            @NotNull @DecimalMin("0") Double odometer,
            List<String> dtcCodes) {}

    public record BatchResult(int accepted, List<String> errors) {}

    /** Message pushed to the app through WebSocket (/topic/telemetry). */
    public record LiveUpdate(Long vehicleId, String plate, double latitude, double longitude,
                             double speed, double fuelLevel, double engineTemp, double odometer,
                             VehicleStatus status, Instant timestamp) {}

    // ----- maintenance -----
    public record RuleRequest(@NotNull Long vehicleId, @NotBlank String name, @NotNull RuleType type,
                              @NotNull @Min(1) Integer intervalValue, Boolean active) {}

    public record RuleView(Long id, Long vehicleId, String name, RuleType type, int intervalValue,
                           double lastServiceOdometer, LocalDate lastServiceDate, boolean active,
                           RuleStatus status, double percentUsed, double remaining) {}

    // ----- work orders -----
    public record WorkOrderRequest(@NotNull Long vehicleId, @NotBlank String title, String description,
                                   Priority priority, Long assignedToId) {}

    public record WorkOrderUpdate(WorkOrderStatus status, String notes, String parts, Double cost,
                                  Long assignedToId) {}

    // ----- geofences -----
    public record GeofenceRequest(@NotBlank String name, @NotNull Double centerLat, @NotNull Double centerLng,
                                  @NotNull @Positive Double radiusMeters, Set<Long> vehicleIds) {}

    // ----- dashboard & reports -----
    public record DashboardDto(long totalVehicles, long activeVehicles, long criticalVehicles,
                               long openAlerts, long openWorkOrders, long maintenanceDue) {}

    public record ReportRow(Long vehicleId, String plate, double distanceKm, double maintenanceCost,
                            long alertCount, long workOrdersCompleted) {}
}
