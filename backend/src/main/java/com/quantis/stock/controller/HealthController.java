package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

/**
 * Contrôleur de vérification de santé de l'API.
 */
@RestController
public class HealthController {

    @GetMapping("/health")
    public ApiResponse<Map<String, Object>> health() {
        return ApiResponse.success(Map.of(
            "status", "UP",
            "application", "Quantis Stock API",
            "version", "1.0.0",
            "timestamp", Instant.now().toString()
        ));
    }
}
