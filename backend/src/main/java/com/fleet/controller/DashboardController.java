package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
@PreAuthorize("hasAnyRole('ADMIN','MANAGER')")
@RequiredArgsConstructor
public class DashboardController {
    private final DashboardService dashboard;

    @GetMapping("/dashboard")
    public Dtos.DashboardDto summary() {
        return dashboard.summary();
    }

    @GetMapping("/reports/summary")
    public List<Dtos.ReportRow> report(@RequestParam(defaultValue = "7") int days) {
        return dashboard.report(days);
    }
}
