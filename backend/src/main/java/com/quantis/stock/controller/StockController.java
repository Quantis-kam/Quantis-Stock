package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.model.MouvementStock;
import com.quantis.stock.model.StockCourant;
import com.quantis.stock.service.StockService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/stock")
@RequiredArgsConstructor
public class StockController {

    private final StockService stockService;

    // =================== MOUVEMENTS ===================

    /**
     * POST /stock/movements — Enregistrer un mouvement de stock
     */
    @PostMapping("/movements")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','MAGASINIER')")
    public ResponseEntity<ApiResponse<MouvementStock>> createMouvement(
            @Valid @RequestBody MouvementRequest request,
            Authentication authentication) {
        MouvementStock mouvement = stockService.enregistrerMouvement(request, authentication.getName());
        return new ResponseEntity<>(
                ApiResponse.success("Mouvement enregistré", mouvement), HttpStatus.CREATED);
    }

    /**
     * GET /stock/movements — Historique des mouvements (paginé)
     */
    @GetMapping("/movements")
    public ResponseEntity<ApiResponse<PagedResponse<MouvementStock>>> getHistorique(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<MouvementStock> result = stockService.getHistoriqueMouvements(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * GET /stock/movements/product/{produitId} — Mouvements par produit
     */
    @GetMapping("/movements/product/{produitId}")
    public ResponseEntity<ApiResponse<PagedResponse<MouvementStock>>> getByProduit(
            @PathVariable Long produitId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<MouvementStock> result = stockService.getMouvementsByProduit(produitId, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    // =================== STOCK COURANT ===================

    /**
     * GET /stock/product/{produitId} — Stock par produit (tous dépôts)
     */
    @GetMapping("/product/{produitId}")
    public ResponseEntity<ApiResponse<List<StockCourant>>> getStockByProduit(@PathVariable Long produitId) {
        return ResponseEntity.ok(ApiResponse.success(stockService.getStockByProduit(produitId)));
    }

    /**
     * GET /stock/depot/{depotId} — Stock par dépôt (tous produits)
     */
    @GetMapping("/depot/{depotId}")
    public ResponseEntity<ApiResponse<List<StockCourant>>> getStockByDepot(@PathVariable Long depotId) {
        return ResponseEntity.ok(ApiResponse.success(stockService.getStockByDepot(depotId)));
    }

    // =================== ALERTES ===================

    /**
     * GET /stock/alerts — Produits en alerte basse
     */
    @GetMapping("/alerts")
    public ResponseEntity<ApiResponse<List<StockCourant>>> getAlertes() {
        return ResponseEntity.ok(ApiResponse.success(stockService.getAlertesBasses()));
    }

    /**
     * GET /stock/alerts/ruptures — Produits en rupture
     */
    @GetMapping("/alerts/ruptures")
    public ResponseEntity<ApiResponse<List<StockCourant>>> getRuptures() {
        return ResponseEntity.ok(ApiResponse.success(stockService.getRuptures()));
    }

    /**
     * GET /stock/alerts/depot/{depotId} — Alertes par dépôt
     */
    @GetMapping("/alerts/depot/{depotId}")
    public ResponseEntity<ApiResponse<List<StockCourant>>> getAlertesParDepot(@PathVariable Long depotId) {
        return ResponseEntity.ok(ApiResponse.success(stockService.getAlertesParDepot(depotId)));
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
