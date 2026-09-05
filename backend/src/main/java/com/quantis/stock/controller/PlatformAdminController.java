package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.EntrepriseRequest;
import com.quantis.stock.dto.PlatformAdminDto.*;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.service.PlatformAdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Contrôleur d'administration centrale de la plateforme Quantis-Stock Multi-Entreprises.
 * Réservé exclusivement au rôle SUPER_ADMIN.
 */
@RestController
@RequestMapping("/platform")
@RequiredArgsConstructor
@PreAuthorize("hasRole('SUPER_ADMIN')")
public class PlatformAdminController {

    private final PlatformAdminService platformAdminService;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<PlatformStatsDto>> getStats() {
        return ResponseEntity.ok(ApiResponse.success(platformAdminService.getStats()));
    }

    @GetMapping("/entreprises")
    public ResponseEntity<ApiResponse<List<EntrepriseListItemDto>>> getAllEntreprises() {
        return ResponseEntity.ok(ApiResponse.success(platformAdminService.getAllEntreprises()));
    }

    @PostMapping("/entreprises")
    public ResponseEntity<ApiResponse<EntrepriseListItemDto>> createEntreprise(
            @Valid @RequestBody EntrepriseCreateRequest request) {
        EntrepriseListItemDto dto = platformAdminService.createEntreprise(request);
        return new ResponseEntity<>(
                ApiResponse.success("Entreprise et compte administrateur créés avec succès", dto),
                HttpStatus.CREATED);
    }

    @PutMapping("/entreprises/{id}")
    public ResponseEntity<ApiResponse<EntrepriseListItemDto>> updateEntreprise(
            @PathVariable Long id,
            @Valid @RequestBody EntrepriseRequest request) {
        EntrepriseListItemDto dto = platformAdminService.updateEntreprise(id, request);
        return ResponseEntity.ok(ApiResponse.success("Entreprise mise à jour", dto));
    }

    @PatchMapping("/entreprises/{id}/status")
    public ResponseEntity<ApiResponse<EntrepriseListItemDto>> toggleStatus(
            @PathVariable Long id) {
        EntrepriseListItemDto dto = platformAdminService.toggleStatus(id);
        String msg = Boolean.TRUE.equals(dto.getEstActif()) ? "Entreprise réactivée" : "Entreprise suspendue";
        return ResponseEntity.ok(ApiResponse.success(msg, dto));
    }

    @GetMapping("/entreprises/{id}/users")
    public ResponseEntity<ApiResponse<List<Utilisateur>>> getEntrepriseUsers(
            @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(platformAdminService.getEntrepriseUsers(id)));
    }

    @GetMapping("/entreprises/{id}/supervision")
    public ResponseEntity<ApiResponse<EntrepriseSupervisionDto>> getEntrepriseSupervision(
            @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(platformAdminService.getEntrepriseSupervision(id)));
    }

    @PostMapping("/entreprises/{id}/reset-admin-password")
    public ResponseEntity<ApiResponse<Void>> resetAdminPassword(
            @PathVariable Long id,
            @Valid @RequestBody ResetPasswordRequest request) {
        platformAdminService.resetAdminPassword(id, request.getNewPassword());
        return ResponseEntity.ok(ApiResponse.success("Mot de passe réinitialisé avec succès", null));
    }

    @PostMapping("/entreprises/{id}/renew-licence")
    public ResponseEntity<ApiResponse<EntrepriseListItemDto>> renewLicence(
            @PathVariable Long id,
            @RequestBody(required = false) LicenceRenewalRequest request) {
        EntrepriseListItemDto dto = platformAdminService.renewLicence(id, request);
        return ResponseEntity.ok(ApiResponse.success("Licence renouvelée avec succès", dto));
    }

    @PostMapping("/entreprises/{id}/expire-licence")
    public ResponseEntity<ApiResponse<EntrepriseListItemDto>> expireLicence(
            @PathVariable Long id) {
        EntrepriseListItemDto dto = platformAdminService.expireLicence(id);
        return ResponseEntity.ok(ApiResponse.success("Licence marquée expirée", dto));
    }
}
