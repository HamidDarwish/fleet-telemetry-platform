package com.fleet.simulator;

import com.fleet.dto.Dtos;
import com.fleet.model.Vehicle;
import com.fleet.repository.VehicleRepository;
import com.fleet.service.TelemetryService;
import com.fleet.util.GeoUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Virtual vehicles (SIM-1..SIM-9). Every tick each vehicle moves along its route and one telemetry
 * message is sent through the normal TelemetryService - exactly what a real device would do.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SimulatorService {
    private final VehicleRepository vehicles;
    private final TelemetryService telemetry;

    @Value("${fleet.simulator.auto-start:true}")        private boolean autoStart;
    @Value("${fleet.simulator.vehicle-count:10}")       private int vehicleCount;
    @Value("${fleet.simulator.interval-ms:3000}")       private long intervalMs;
    @Value("${fleet.simulator.speed-multiplier:5}")     private double multiplier;
    @Value("${fleet.simulator.fault-probability:0.01}") private double faultProbability;

    private final Map<Long, SimState> states = new ConcurrentHashMap<>();
    private final Random rnd = new Random();
    private volatile boolean running = false;

    /** Mutable state of one virtual vehicle. */
    private static class SimState {
        Long vehicleId;
        int route;
        int seg;
        double t;               // 0..1 position inside the current segment
        double speed = 40;
        double temp = 88;
        double fuel = 80;
        double odometer;
        int overheatTicks;
        int overspeedTicks;
        boolean dtcPending;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        if (autoStart) start();
    }

    public synchronized void start() {
        if (running) return;
        List<Vehicle> list = vehicles.findByActiveTrue();
        int count = Math.min(vehicleCount, list.size());
        states.clear();
        for (int i = 0; i < count; i++) {
            Vehicle v = list.get(i);
            SimState s = new SimState();
            s.vehicleId = v.getId();
            s.route = i % Routes.ALL.size();
            s.seg = (i / Routes.ALL.size()) % Routes.ALL.get(s.route).length;
            s.fuel = v.getFuelLevel() == null ? 80 : v.getFuelLevel();
            s.odometer = v.getOdometer() == null ? 0 : v.getOdometer();
            states.put(v.getId(), s);
        }
        running = true;
        log.info("Simulator started with {} virtual vehicles", states.size());
    }

    public synchronized void stop() {
        running = false;
        states.clear();
        log.info("Simulator stopped");
    }

    public Map<String, Object> status() {
        return Map.of("running", running, "vehicles", states.size(), "intervalMs", intervalMs,
                "speedMultiplier", multiplier, "faultProbability", faultProbability);
    }

    @Scheduled(fixedDelayString = "${fleet.simulator.interval-ms:3000}", initialDelay = 5000)
    public void tick() {
        if (!running) return;
        for (SimState s : states.values()) {
            try {
                telemetry.ingest(nextMessage(s));
            } catch (Exception e) {
                log.warn("Simulator: vehicle {} skipped: {}", s.vehicleId, e.getMessage());
            }
        }
    }

    private Dtos.TelemetryDto nextMessage(SimState s) {
        double[][] route = Routes.ALL.get(s.route);
        int n = route.length;

        // speed: smooth random changes (SIM-4)
        double target = 35 + rnd.nextDouble() * 30;
        s.speed += (target - s.speed) * 0.3;
        if (rnd.nextDouble() < faultProbability) injectFault(s);   // SIM-5
        if (s.overspeedTicks > 0) {
            s.speed = 110 + rnd.nextDouble() * 10;
            s.overspeedTicks--;
        }

        // movement along the route (SIM-2)
        double distanceKm = s.speed * (intervalMs / 3_600_000.0) * multiplier;
        double remaining = distanceKm * 1000.0;
        while (remaining > 0) {
            double[] a = route[s.seg];
            double[] b = route[(s.seg + 1) % n];
            double len = GeoUtils.distanceMeters(a[0], a[1], b[0], b[1]);
            double left = len * (1 - s.t);
            if (remaining < left) {
                s.t += remaining / len;
                remaining = 0;
            } else {
                remaining -= left;
                s.seg = (s.seg + 1) % n;
                s.t = 0;
            }
        }
        double[] a = route[s.seg];
        double[] b = route[(s.seg + 1) % n];
        double lat = a[0] + (b[0] - a[0]) * s.t;
        double lng = a[1] + (b[1] - a[1]) * s.t;
        double heading = GeoUtils.bearing(a[0], a[1], b[0], b[1]);

        // odometer and fuel
        s.odometer += distanceKm;
        s.fuel -= distanceKm * 0.4;
        if (s.fuel < 4) s.fuel = 100;   // refuel

        // engine temperature
        if (s.overheatTicks > 0) {
            s.temp = 117 + rnd.nextDouble() * 5;
            s.overheatTicks--;
        } else {
            s.temp += (88 - s.temp) * 0.25 + (rnd.nextDouble() - 0.5);
        }

        double rpm = 800 + s.speed * 35 + rnd.nextDouble() * 150;
        List<String> dtc = s.dtcPending ? List.of("P0217") : List.of();
        s.dtcPending = false;

        return new Dtos.TelemetryDto(s.vehicleId, Instant.now(),
                round(lat, 6), round(lng, 6), round(Math.min(s.speed, 250), 1), round(heading % 360, 1),
                round(rpm, 0), round(s.temp, 1), round(s.fuel, 1), round(s.odometer, 2), dtc);
    }

    private void injectFault(SimState s) {
        switch (rnd.nextInt(4)) {
            case 0 -> s.overheatTicks = 6;
            case 1 -> s.overspeedTicks = 4;
            case 2 -> s.fuel = Math.min(s.fuel, 12);
            default -> s.dtcPending = true;
        }
    }

    private static double round(double v, int digits) {
        double f = Math.pow(10, digits);
        return Math.round(v * f) / f;
    }
}
