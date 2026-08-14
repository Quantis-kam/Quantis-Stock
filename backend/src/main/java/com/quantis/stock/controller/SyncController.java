package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.SyncRequest;
import com.quantis.stock.dto.SyncResponse;
import com.quantis.stock.service.SyncService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/sync")
@RequiredArgsConstructor
public class SyncController {

    private final SyncService syncService;

    /**
     * POST /sync — Synchroniser les actions hors-ligne en lot.
     * Chaque action est idempotente (UUID). Les doublons sont ignorés.
     */
    @PostMapping
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<SyncResponse>> sync(
            @RequestBody SyncRequest request,
            Authentication auth) {
        SyncResponse response = syncService.processBatch(request.getActions(), auth.getName());
        return ResponseEntity.ok(ApiResponse.success(
                String.format("Sync: %d traités, %d ignorés, %d erreurs",
                        response.getTotalProcessed(), response.getTotalSkipped(), response.getTotalFailed()),
                response));
    }
}
