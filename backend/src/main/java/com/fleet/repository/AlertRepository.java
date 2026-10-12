package com.fleet.repository;

import com.fleet.model.Alert;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;

public interface AlertRepository extends JpaRepository<Alert, Long> {
    List<Alert> findTop200ByOrderByCreatedAtDesc();
    long countByAcknowledgedFalse();
    long countByVehicleIdAndCreatedAtAfter(Long vehicleId, Instant since);
}
