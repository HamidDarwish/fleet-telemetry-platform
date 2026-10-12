package com.fleet.repository;

import com.fleet.model.TelemetryRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface TelemetryRepository extends JpaRepository<TelemetryRecord, Long> {

    List<TelemetryRecord> findByVehicleIdAndTimestampBetweenOrderByTimestampAsc(Long vehicleId, Instant from, Instant to);

    @Modifying
    @Query("delete from TelemetryRecord t where t.timestamp < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);

    @Query("select max(t.odometer) - min(t.odometer) from TelemetryRecord t where t.vehicleId = :vid and t.timestamp >= :since")
    Double distanceSince(@Param("vid") Long vehicleId, @Param("since") Instant since);
}
