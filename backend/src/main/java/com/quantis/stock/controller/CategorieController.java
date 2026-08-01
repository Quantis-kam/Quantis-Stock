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

    @GetMapping
    public ResponseEntity<ApiResponse<List<Categorie>>> findAll() {
        return ResponseEntity.ok(ApiResponse.success(categorieService.findAll()));
    }

    @GetMapping("/roots")
    public ResponseEntity<ApiResponse<List<Categorie>>> findRoots() {
        return ResponseEntity.ok(ApiResponse.success(categorieService.findRoots()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Categorie>> findById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(categorieService.findById(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Categorie>> create(@Valid @RequestBody CategorieRequest request) {
        Categorie categorie = categorieService.create(request);
        return new ResponseEntity<>(ApiResponse.success("Catégorie créée", categorie), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Categorie>> update(
            @PathVariable Long id, @Valid @RequestBody CategorieRequest request) {
        return ResponseEntity.ok(ApiResponse.success("Catégorie mise à jour", categorieService.update(id, request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, String>>> delete(@PathVariable Long id) {
        categorieService.delete(id);
        return ResponseEntity.ok(ApiResponse.success(Map.of("message", "Catégorie supprimée")));
    }
}
