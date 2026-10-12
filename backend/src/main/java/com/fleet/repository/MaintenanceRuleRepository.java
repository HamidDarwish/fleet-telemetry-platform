package com.fleet.repository;

import com.fleet.model.MaintenanceRule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MaintenanceRuleRepository extends JpaRepository<MaintenanceRule, Long> {
    List<MaintenanceRule> findByVehicleId(Long vehicleId);
    List<MaintenanceRule> findByVehicleIdAndActiveTrue(Long vehicleId);
}
