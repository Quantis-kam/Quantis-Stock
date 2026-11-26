package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.DemandeEntrepriseRequest;
import com.quantis.stock.model.DemandeEntreprise;
import com.quantis.stock.service.PlatformAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Endpoints publics de la vitrine d'accueil Quantis-Stock (sans authentification).
 */
@RestController
@RequestMapping("/public")
@RequiredArgsConstructor
public class PublicLeadController {

    private final PlatformAdminService platformAdminService;

    /**
     * POST /public/demandes-entreprise — Enregistre une demande de création d'espace entreprise.
     */
    @PostMapping("/demandes-entreprise")
    public ResponseEntity<ApiResponse<Map<String, Object>>> submitEnterpriseRequest(
            @Valid @RequestBody DemandeEntrepriseRequest request) {
        DemandeEntreprise saved = platformAdminService.submitDemandeEntreprise(request);
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("id", saved.getId());
        summary.put("nomEntreprise", saved.getNomEntreprise());
        summary.put("statut", saved.getStatut());
        summary.put("createdAt", saved.getCreatedAt());
        return new ResponseEntity<>(
                ApiResponse.success("Votre demande a bien été transmise à l'équipe Quantis-Stock.", summary),
                HttpStatus.CREATED);
    }
}

