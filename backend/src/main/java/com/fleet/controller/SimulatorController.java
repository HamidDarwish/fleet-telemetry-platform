package com.fleet.controller;

import com.fleet.simulator.SimulatorService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/** SIM-7 - the System Admin starts and stops the virtual vehicles. */
@RestController
@RequestMapping("/api/simulator")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class SimulatorController {
    private final SimulatorService simulator;

    @PostMapping("/start")
    public Map<String, Object> start() {
        simulator.start();
        return simulator.status();
    }

    @PostMapping("/stop")
    public Map<String, Object> stop() {
        simulator.stop();
        return simulator.status();
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return simulator.status();
    }
}
