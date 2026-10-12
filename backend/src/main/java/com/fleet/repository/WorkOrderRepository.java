package com.fleet.repository;

import com.fleet.model.WorkOrder;
import com.fleet.model.WorkOrderSource;
import com.fleet.model.WorkOrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface WorkOrderRepository extends JpaRepository<WorkOrder, Long> {
    List<WorkOrder> findAllByOrderByCreatedAtDesc();
    List<WorkOrder> findByAssignedToIdOrderByCreatedAtDesc(Long userId);
    List<WorkOrder> findByVehicleIdOrderByCreatedAtDesc(Long vehicleId);
    boolean existsByRuleIdAndStatusIn(Long ruleId, Collection<WorkOrderStatus> statuses);
    boolean existsByVehicleIdAndSourceAndStatusIn(Long vehicleId, WorkOrderSource source, Collection<WorkOrderStatus> statuses);
    long countByStatusIn(Collection<WorkOrderStatus> statuses);
}
