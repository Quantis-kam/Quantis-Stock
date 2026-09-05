package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.model.AuditLog;
import com.quantis.stock.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.UtilisateurRepository;

@RestController
@RequestMapping("/audit-logs")
@RequiredArgsConstructor
public class AuditLogController {

    private final AuditLogRepository auditLogRepository;
    private final UtilisateurRepository utilisateurRepository;

    @GetMapping
    @PreAuthorize("hasAuthority('VOIR_AUDIT')")
    public ResponseEntity<ApiResponse<PagedResponse<AuditLog>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            org.springframework.security.core.Authentication auth) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        boolean isGerant = auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_GERANT"));
        Page<AuditLog> result;
        if (isGerant) {
            Utilisateur currentUser = utilisateurRepository.findByEmail(auth.getName()).orElse(null);
            if (currentUser != null && currentUser.getDepot() != null) {
                result = auditLogRepository.findByUtilisateurDepotIdOrderByCreatedAtDesc(currentUser.getDepot().getId(), pageable);
            } else {
                result = Page.empty();
            }
        } else {
            result = auditLogRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    private <T> PagedResponse<T> toPagedResponse(Page<T> page) {
        return PagedResponse.<T>builder()
                .content(page.getContent())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .first(page.isFirst())
                .build();
    }
}
