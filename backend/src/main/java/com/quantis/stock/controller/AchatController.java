package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.model.CommandeFournisseur;
import com.quantis.stock.model.enums.StatutCommande;
import com.quantis.stock.service.AchatService;
import com.quantis.stock.service.AuditService;
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

@RestController
@RequestMapping("/purchases")
@RequiredArgsConstructor
public class AchatController {

    private final AchatService achatService;
    private final AuditService auditService;

    /**
     * POST /purchases — Créer une commande fournisseur
     */
    @PostMapping
    @PreAuthorize("hasAuthority('CREER_ACHAT')")
    public ResponseEntity<ApiResponse<CommandeFournisseur>> create(
            @Valid @RequestBody CommandeRequest request,
            Authentication auth) {
        CommandeFournisseur cmd = achatService.creerCommande(request, auth.getName());
        auditService.logAction("CREATE", "CommandeFournisseur", cmd.getId(), "Création commande " + cmd.getNumero());
        return new ResponseEntity<>(ApiResponse.success("Commande créée: " + cmd.getNumero(), cmd), HttpStatus.CREATED);
    }

    /**
     * GET /purchases — Liste des commandes (paginée)
     */
    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<CommandeFournisseur>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<CommandeFournisseur> result = achatService.findAll(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * GET /purchases/{id} — Détail d'une commande
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<CommandeFournisseur>> findById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(achatService.findById(id)));
    }

    /**
     * GET /purchases/status/{statut} — Par statut
     */
    @GetMapping("/status/{statut}")
    public ResponseEntity<ApiResponse<PagedResponse<CommandeFournisseur>>> findByStatut(
            @PathVariable StatutCommande statut,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<CommandeFournisseur> result = achatService.findByStatut(statut, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * GET /purchases/supplier/{fournisseurId} — Par fournisseur
     */
    @GetMapping("/supplier/{fournisseurId}")
    public ResponseEntity<ApiResponse<PagedResponse<CommandeFournisseur>>> findByFournisseur(
            @PathVariable Long fournisseurId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<CommandeFournisseur> result = achatService.findByFournisseur(fournisseurId, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * PUT /purchases/{id}/validate — Valider une commande brouillon
     */
    @PutMapping("/{id}/validate")
    @PreAuthorize("hasAuthority('CREER_ACHAT')")
    public ResponseEntity<ApiResponse<CommandeFournisseur>> validate(@PathVariable Long id) {
        CommandeFournisseur cmd = achatService.validerCommande(id);
        auditService.logAction("VALIDATE", "CommandeFournisseur", id, "Validation commande " + cmd.getNumero());
        return ResponseEntity.ok(ApiResponse.success("Commande validée", cmd));
    }

    /**
     * PUT /purchases/{id}/cancel — Annuler une commande
     */
    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasAuthority('CREER_ACHAT')")
    public ResponseEntity<ApiResponse<CommandeFournisseur>> cancel(@PathVariable Long id) {
        CommandeFournisseur cmd = achatService.annulerCommande(id);
        auditService.logAction("CANCEL", "CommandeFournisseur", id, "Annulation commande " + cmd.getNumero());
        return ResponseEntity.ok(ApiResponse.success("Commande annulée", cmd));
    }

    /**
     * POST /purchases/{id}/receive — Réceptionner (partiel ou total)
     * Crée automatiquement des entrées de stock.
     */
    @PostMapping("/{id}/receive")
    @PreAuthorize("hasAuthority('RECEPTIONNER_ACHAT')")
    public ResponseEntity<ApiResponse<CommandeFournisseur>> receive(
            @PathVariable Long id,
            @Valid @RequestBody ReceptionRequest request,
            Authentication auth) {
        CommandeFournisseur cmd = achatService.receptionner(id, request, auth.getName());
        auditService.logAction("RECEIVE", "CommandeFournisseur", id, "Réception commande " + cmd.getNumero());
        return ResponseEntity.ok(ApiResponse.success("Réception enregistrée", cmd));
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
