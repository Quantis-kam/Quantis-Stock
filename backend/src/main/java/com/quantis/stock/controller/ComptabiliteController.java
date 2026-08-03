package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.model.MouvementCaisse;
import com.quantis.stock.service.ComptabiliteService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/accounting")
@RequiredArgsConstructor
public class ComptabiliteController {

    private final ComptabiliteService comptabiliteService;

    /**
     * POST /accounting/cash — Enregistrer un mouvement de caisse
     */
    @PostMapping("/cash")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','CAISSIER')")
    public ResponseEntity<ApiResponse<MouvementCaisse>> createCashEntry(
            @RequestBody MouvementCaisse mouvement,
            Authentication auth) {
        MouvementCaisse saved = comptabiliteService.enregistrerMouvement(mouvement, auth.getName());
        return new ResponseEntity<>(ApiResponse.success("Mouvement enregistré", saved), HttpStatus.CREATED);
    }

    /**
     * GET /accounting/cash?debut=2026-01-01&fin=2026-12-31 — Journal de caisse
     */
    @GetMapping("/cash")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','COMPTABLE')")
    public ResponseEntity<ApiResponse<PagedResponse<MouvementCaisse>>> getCashJournal(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<MouvementCaisse> result = comptabiliteService.getJournal(debut, fin, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * GET /accounting/report?debut=2026-01-01&fin=2026-12-31 — Rapport financier
     */
    @GetMapping("/report")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','COMPTABLE')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getReport(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {
        return ResponseEntity.ok(ApiResponse.success(comptabiliteService.getRapportPeriode(debut, fin)));
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
