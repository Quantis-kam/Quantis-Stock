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
    private final com.quantis.stock.service.AuditService auditService;

    @GetMapping
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<PagedResponse<Produit>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "nom") String sortBy) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by(sortBy));
        Page<Produit> result = produitService.findAll(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<Produit>> findById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(produitService.findById(id)));
    }

    @GetMapping("/sku/{sku}")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<Produit>> findBySku(@PathVariable String sku) {
        return ResponseEntity.ok(ApiResponse.success(produitService.findBySku(sku)));
    }

    @GetMapping("/barcode/{code}")
    @PreAuthorize("hasAuthority('SCANNER_CODES')")
    public ResponseEntity<ApiResponse<Produit>> findByBarcode(@PathVariable String code) {
        return ResponseEntity.ok(ApiResponse.success(produitService.findByCodeBarres(code)));
    }

    @GetMapping("/search")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<PagedResponse<Produit>>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Produit> result = produitService.search(q, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/category/{categorieId}")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<PagedResponse<Produit>>> findByCategory(
            @PathVariable Long categorieId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Produit> result = produitService.findByCategorie(categorieId, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('CREER_MODIFIER_PRODUIT')")
    public ResponseEntity<ApiResponse<Produit>> create(@Valid @RequestBody ProduitRequest request) {
        Produit produit = produitService.create(request);
        auditService.logAction("CREATE", "Produit", produit.getId(), "Création produit " + produit.getNom());
        return new ResponseEntity<>(ApiResponse.success("Produit créé", produit), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('CREER_MODIFIER_PRODUIT')")
    public ResponseEntity<ApiResponse<Produit>> update(
            @PathVariable Long id, @Valid @RequestBody ProduitRequest request) {
        Produit updated = produitService.update(id, request);
        auditService.logAction("UPDATE", "Produit", updated.getId(), "Modification produit " + updated.getNom());
        return ResponseEntity.ok(ApiResponse.success("Produit mis à jour", updated));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('SUPPRIMER_PRODUIT')")
    public ResponseEntity<ApiResponse<Map<String, String>>> delete(@PathVariable Long id) {
        produitService.softDelete(id);
        auditService.logAction("DELETE", "Produit", id, "Désactivation produit ID " + id);
        return ResponseEntity.ok(ApiResponse.success(Map.of("message", "Produit désactivé")));
    }

    @GetMapping("/units")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<java.util.List<com.quantis.stock.model.UniteMesure>>> findAllUnits() {
        return ResponseEntity.ok(ApiResponse.success(produitService.findAllUnits()));
    }

    @PostMapping("/import")
    @PreAuthorize("hasAuthority('IMPORT_EXPORTS')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> importCsv(@RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        try {
            int importedCount = produitService.importCsv(file.getInputStream());
            auditService.logAction("IMPORT", "Produit", null, "Importation de " + importedCount + " produits via CSV");
            return ResponseEntity.ok(ApiResponse.success("Import réussi", Map.of("importedCount", importedCount)));
        } catch (Exception e) {
            throw new com.quantis.stock.exception.BusinessException("Erreur lors de l'import CSV : " + e.getMessage());
        }
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
