package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.Role;
import com.fleet.model.User;
import com.fleet.model.Vehicle;
import com.fleet.repository.UserRepository;
import com.fleet.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.NoSuchElementException;

@Service
@RequiredArgsConstructor
public class VehicleService {
    private final VehicleRepository vehicles;
    private final UserRepository users;

    /** A driver only sees the vehicle assigned to him/her. */
    public List<Vehicle> list(User viewer) {
        return viewer.getRole() == Role.DRIVER ? vehicles.findByDriverId(viewer.getId()) : vehicles.findAll();
    }

    public Vehicle get(Long id, User viewer) {
        Vehicle v = vehicles.findById(id).orElseThrow(() -> new NoSuchElementException("Vehicle not found"));
        if (viewer.getRole() == Role.DRIVER && (v.getDriver() == null || !v.getDriver().getId().equals(viewer.getId())))
            throw new AccessDeniedException("This is not your vehicle");
        return v;
    }

    public Vehicle create(Dtos.VehicleRequest r) {
        return vehicles.save(apply(new Vehicle(), r));
    }

    public Vehicle update(Long id, Dtos.VehicleRequest r) {
        Vehicle v = vehicles.findById(id).orElseThrow(() -> new NoSuchElementException("Vehicle not found"));
        return vehicles.save(apply(v, r));
    }

    private Vehicle apply(Vehicle v, Dtos.VehicleRequest r) {
        v.setPlate(r.plate());
        v.setModel(r.model());
        v.setYear(r.year());
        v.setFuelType(r.fuelType());
        v.setTankCapacity(r.tankCapacity());
        if (r.odometer() != null) v.setOdometer(r.odometer());
        if (r.active() != null) v.setActive(r.active());
        if (r.driverId() != null) {
            User d = users.findById(r.driverId()).orElseThrow(() -> new NoSuchElementException("Driver not found"));
            if (d.getRole() != Role.DRIVER) throw new IllegalArgumentException("Selected user is not a driver");
            v.setDriver(d);
        } else {
            v.setDriver(null);
        }
        return v;
    }
}
