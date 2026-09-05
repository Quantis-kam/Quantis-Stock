package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.model.Categorie;
import com.quantis.stock.service.CategorieService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/categories")
@RequiredArgsConstructor
public class CategorieController {

    private final CategorieService categorieService;
    private final com.quantis.stock.service.AuditService auditService;

    @GetMapping
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<List<Categorie>>> findAll() {
        return ResponseEntity.ok(ApiResponse.success(categorieService.findAll()));
    }

    @GetMapping("/roots")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<List<Categorie>>> findRoots() {
        return ResponseEntity.ok(ApiResponse.success(categorieService.findRoots()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('VOIR_PRODUITS')")
    public ResponseEntity<ApiResponse<Categorie>> findById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(categorieService.findById(id)));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('GERER_CATEGORIES')")
    public ResponseEntity<ApiResponse<Categorie>> create(@Valid @RequestBody CategorieRequest request) {
        Categorie categorie = categorieService.create(request);
        auditService.logAction("CREATE", "Categorie", categorie.getId(), "Création catégorie " + categorie.getNom());
        return new ResponseEntity<>(ApiResponse.success("Catégorie créée", categorie), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('GERER_CATEGORIES')")
    public ResponseEntity<ApiResponse<Categorie>> update(
            @PathVariable Long id, @Valid @RequestBody CategorieRequest request) {
        Categorie updated = categorieService.update(id, request);
        auditService.logAction("UPDATE", "Categorie", updated.getId(), "Modification catégorie " + updated.getNom());
        return ResponseEntity.ok(ApiResponse.success("Catégorie mise à jour", updated));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('GERER_CATEGORIES')")
    public ResponseEntity<ApiResponse<Map<String, String>>> delete(@PathVariable Long id) {
        categorieService.delete(id);
        auditService.logAction("DELETE", "Categorie", id, "Suppression catégorie ID " + id);
        return ResponseEntity.ok(ApiResponse.success(Map.of("message", "Catégorie supprimée")));
    }
}
