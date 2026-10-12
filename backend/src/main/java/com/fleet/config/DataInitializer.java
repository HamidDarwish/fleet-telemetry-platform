package com.fleet.config;

import com.fleet.model.*;
import com.fleet.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.Set;

/** Creates demo users, vehicles, maintenance rules and a geofence on first start (empty database only). */
@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {
    private final UserRepository users;
    private final VehicleRepository vehicles;
    private final MaintenanceRuleRepository rules;
    private final GeofenceRepository geofences;
    private final PasswordEncoder encoder;

    @Override
    public void run(String... args) {
        if (users.count() > 0) return;

        createUser("System Admin", "admin@fleet.local", "admin123", Role.ADMIN);
        createUser("Fleet Manager", "manager@fleet.local", "manager123", Role.MANAGER);
        createUser("Technician", "tech@fleet.local", "tech123", Role.TECHNICIAN);
        User driver = createUser("Driver One", "driver@fleet.local", "driver123", Role.DRIVER);

        // plate, model, year, fuel, tank (L), odometer (km), km driven since the last oil change
        Object[][] data = {
            {"KBL-1001", "Toyota Hilux",   2021, "Diesel", 80.0,  45210.0, 4990.0},  // oil change due almost immediately
            {"KBL-1002", "Toyota Corolla", 2019, "Petrol", 50.0,  78300.0, 2000.0},
            {"KBL-1003", "Isuzu NPR",      2020, "Diesel", 100.0, 120450.0, 4500.0}, // already at 90%
            {"KBL-1004", "Ford Transit",   2018, "Diesel", 80.0,  32100.0, 1000.0},
            {"KBL-1005", "Toyota Hiace",   2022, "Diesel", 70.0,  15800.0, 3000.0},
            {"KBL-1006", "Hyundai Porter", 2017, "Diesel", 90.0,  98000.0, 4200.0},
        };

        Set<Long> vehicleIds = new HashSet<>();
        int i = 0;
        for (Object[] d : data) {
            Vehicle v = new Vehicle();
            v.setPlate((String) d[0]);
            v.setModel((String) d[1]);
            v.setYear((Integer) d[2]);
            v.setFuelType((String) d[3]);
            v.setTankCapacity((Double) d[4]);
            v.setOdometer((Double) d[5]);
            v.setFuelLevel(80.0);
            if (i == 0) v.setDriver(driver);
            v = vehicles.save(v);
            vehicleIds.add(v.getId());

            MaintenanceRule oil = new MaintenanceRule();
            oil.setVehicleId(v.getId());
            oil.setName("Oil change");
            oil.setType(RuleType.DISTANCE);
            oil.setIntervalValue(5000);
            oil.setLastServiceOdometer((Double) d[5] - (Double) d[6]);
            oil.setLastServiceDate(LocalDate.now().minusDays(20));
            rules.save(oil);

            MaintenanceRule inspection = new MaintenanceRule();
            inspection.setVehicleId(v.getId());
            inspection.setName("General inspection");
            inspection.setType(RuleType.TIME);
            inspection.setIntervalValue(90);
            inspection.setLastServiceOdometer((Double) d[5]);
            inspection.setLastServiceDate(LocalDate.now().minusDays(10L + i * 12L));
            rules.save(inspection);
            i++;
        }

        Geofence city = new Geofence();
        city.setName("Kabul city zone");
        city.setCenterLat(34.5281);
        city.setCenterLng(69.1723);
        city.setRadiusMeters(7000);
        city.setVehicleIds(vehicleIds);
        geofences.save(city);
    }

    private User createUser(String name, String email, String password, Role role) {
        User u = new User();
        u.setName(name);
        u.setEmail(email);
        u.setPasswordHash(encoder.encode(password));
        u.setRole(role);
        return users.save(u);
    }
}
