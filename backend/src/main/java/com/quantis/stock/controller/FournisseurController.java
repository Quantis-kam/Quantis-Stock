package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Fournisseur;
import com.quantis.stock.repository.FournisseurRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * Contrôleur CRUD pour les fournisseurs.
 */
@RestController
@RequestMapping("/suppliers")
@RequiredArgsConstructor
public class FournisseurController {

    private final FournisseurRepository fournisseurRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<Fournisseur>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Fournisseur> result = fournisseurRepository.findByActifTrue(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Fournisseur>> findById(@PathVariable Long id) {
        Fournisseur fournisseur = fournisseurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Fournisseur", "id", id));
        return ResponseEntity.ok(ApiResponse.success(fournisseur));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<PagedResponse<Fournisseur>>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Fournisseur> result = fournisseurRepository.search(q, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Fournisseur>> create(@Valid @RequestBody Fournisseur fournisseur) {
        fournisseur.setId(null);
        Fournisseur saved = fournisseurRepository.save(fournisseur);
        return new ResponseEntity<>(ApiResponse.success("Fournisseur créé", saved), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Fournisseur>> update(@PathVariable Long id, @Valid @RequestBody Fournisseur request) {
        Fournisseur fournisseur = fournisseurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Fournisseur", "id", id));
        fournisseur.setNom(request.getNom());
        fournisseur.setTelephone(request.getTelephone());
        fournisseur.setEmail(request.getEmail());
        fournisseur.setAdresse(request.getAdresse());
        fournisseur.setNotes(request.getNotes());
        return ResponseEntity.ok(ApiResponse.success("Fournisseur mis à jour", fournisseurRepository.save(fournisseur)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        Fournisseur fournisseur = fournisseurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Fournisseur", "id", id));
        fournisseur.setActif(false);
        fournisseurRepository.save(fournisseur);
        return ResponseEntity.ok(ApiResponse.success("Fournisseur supprimé", null));
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
