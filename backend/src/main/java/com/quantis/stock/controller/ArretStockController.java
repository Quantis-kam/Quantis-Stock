package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.ArretStockRequest;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.model.ArretStock;
import com.quantis.stock.service.ArretStockService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/stock/arrets")
@RequiredArgsConstructor
public class ArretStockController {

    private final ArretStockService arretStockService;

    @PostMapping
    @PreAuthorize("hasAuthority('MOUVEMENT_STOCK') or hasRole('ADMIN') or hasRole('GERANT')")
    public ResponseEntity<ApiResponse<ArretStock>> creerArretStock(
            @RequestBody ArretStockRequest request,
            Authentication auth) {
        ArretStock arret = arretStockService.creerArretStock(auth.getName(), request);
        return ResponseEntity.ok(ApiResponse.success("Arrêt de stock créé avec succès", arret));
    }

    @GetMapping
    @PreAuthorize("hasAuthority('MOUVEMENT_STOCK') or hasRole('ADMIN') or hasRole('GERANT')")
    public ResponseEntity<ApiResponse<PagedResponse<ArretStock>>> getHistorique(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by("id").descending());
        Page<ArretStock> result = arretStockService.findAll(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('MOUVEMENT_STOCK') or hasRole('ADMIN') or hasRole('GERANT')")
    public ResponseEntity<ApiResponse<ArretStock>> getById(@PathVariable Long id) {
        ArretStock arret = arretStockService.findById(id);
        return ResponseEntity.ok(ApiResponse.success(arret));
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
