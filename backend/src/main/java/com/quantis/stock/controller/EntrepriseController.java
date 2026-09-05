package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.EntrepriseRequest;
import com.quantis.stock.model.Entreprise;
import com.quantis.stock.service.EntrepriseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/entreprise")
@RequiredArgsConstructor
public class EntrepriseController {

    private final EntrepriseService entrepriseService;

    @GetMapping
    public ResponseEntity<ApiResponse<Entreprise>> getEntreprise(Authentication auth) {
        String email = auth != null ? auth.getName() : null;
        Entreprise entreprise = entrepriseService.getEntrepriseCourante(email);
        return ResponseEntity.ok(ApiResponse.success(entreprise));
    }

    @PutMapping
    @PreAuthorize("hasAuthority('CONFIG_SYSTEME') or hasRole('ADMIN') or hasRole('GERANT')")
    public ResponseEntity<ApiResponse<Entreprise>> updateEntreprise(
            @Valid @RequestBody EntrepriseRequest request,
            Authentication auth) {
        String email = auth != null ? auth.getName() : null;
        Entreprise updated = entrepriseService.updateEntreprise(request, email);
        return ResponseEntity.ok(ApiResponse.success("Profil d'entreprise mis à jour avec succès", updated));
    }
}
