package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.model.Produit;
import com.quantis.stock.service.ProduitService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/products")
@RequiredArgsConstructor
public class ProduitController {

    private final ProduitService produitService;

    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<Produit>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "nom") String sortBy) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by(sortBy));
        Page<Produit> result = produitService.findAll(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Produit>> findById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(produitService.findById(id)));
    }

    @GetMapping("/sku/{sku}")
    public ResponseEntity<ApiResponse<Produit>> findBySku(@PathVariable String sku) {
        return ResponseEntity.ok(ApiResponse.success(produitService.findBySku(sku)));
    }

    @GetMapping("/barcode/{code}")
    public ResponseEntity<ApiResponse<Produit>> findByBarcode(@PathVariable String code) {
        return ResponseEntity.ok(ApiResponse.success(produitService.findByCodeBarres(code)));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<PagedResponse<Produit>>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Produit> result = produitService.search(q, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/category/{categorieId}")
    public ResponseEntity<ApiResponse<PagedResponse<Produit>>> findByCategory(
            @PathVariable Long categorieId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Produit> result = produitService.findByCategorie(categorieId, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','MAGASINIER')")
    public ResponseEntity<ApiResponse<Produit>> create(@Valid @RequestBody ProduitRequest request) {
        Produit produit = produitService.create(request);
        return new ResponseEntity<>(ApiResponse.success("Produit créé", produit), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','MAGASINIER')")
    public ResponseEntity<ApiResponse<Produit>> update(
            @PathVariable Long id, @Valid @RequestBody ProduitRequest request) {
        return ResponseEntity.ok(ApiResponse.success("Produit mis à jour", produitService.update(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Map<String, String>>> delete(@PathVariable Long id) {
        produitService.softDelete(id);
        return ResponseEntity.ok(ApiResponse.success(Map.of("message", "Produit désactivé")));
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
