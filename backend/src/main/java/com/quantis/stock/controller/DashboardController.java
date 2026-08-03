package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Year;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;

    /**
     * GET /dashboard/kpis — KPIs principaux
     */
    @GetMapping("/kpis")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','COMPTABLE')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getKpis() {
        return ResponseEntity.ok(ApiResponse.success(dashboardService.getKpis()));
    }

    /**
     * GET /dashboard/sales?year=2026 — Ventes par mois
     */
    @GetMapping("/sales")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','COMPTABLE')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getSalesByMonth(
            @RequestParam(defaultValue = "0") int year) {
        int annee = year > 0 ? year : Year.now().getValue();
        return ResponseEntity.ok(ApiResponse.success(dashboardService.getVentesParMois(annee)));
    }
}
