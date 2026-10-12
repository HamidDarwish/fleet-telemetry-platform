package com.fleet.controller;

import com.fleet.model.Alert;
import com.fleet.model.AlertType;
import com.fleet.model.Severity;
import com.fleet.service.AlertService;
import com.fleet.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/alerts")
@RequiredArgsConstructor
public class AlertController {
    private final AlertService alertService;
    private final UserService userService;

    @GetMapping
    public List<Alert> list(@RequestParam(required = false) AlertType type,
                            @RequestParam(required = false) Severity severity,
                            @RequestParam(required = false) Long vehicleId,
                            @RequestParam(required = false) Boolean acknowledged,
                            Authentication auth) {
        return alertService.list(userService.current(auth), type, severity, vehicleId, acknowledged);
    }

    @PutMapping("/{id}/ack")
    public Alert acknowledge(@PathVariable Long id, Authentication auth) {
        return alertService.acknowledge(id, userService.current(auth));
    }
}
