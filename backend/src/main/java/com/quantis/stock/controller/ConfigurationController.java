package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.model.Configuration;
import com.quantis.stock.repository.ConfigurationRepository;
import com.quantis.stock.service.AuditService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * Contrôleur de configuration système.
 * Table à une seule ligne — GET pour lire, PUT pour modifier.
 */
@RestController
@RequestMapping("/config")
@RequiredArgsConstructor
public class ConfigurationController {

    private final ConfigurationRepository configurationRepository;
    private final AuditService auditService;

    /**
     * GET /config — Lire la configuration actuelle (ou créer les defaults).
     */
    @GetMapping
    @PreAuthorize("hasAuthority('CONFIG_SYSTEME') or hasAuthority('VOIR_DASHBOARD')")
    public ResponseEntity<ApiResponse<Configuration>> get() {
        Configuration config = configurationRepository.findById(1L)
                .orElseGet(() -> configurationRepository.save(Configuration.builder().build()));
        return ResponseEntity.ok(ApiResponse.success(config));
    }

    /**
     * PUT /config — Mettre à jour la configuration système.
     */
    @PutMapping
    @PreAuthorize("hasAuthority('CONFIG_SYSTEME')")
    public ResponseEntity<ApiResponse<Configuration>> update(@RequestBody Configuration request) {
        Configuration config = configurationRepository.findById(1L)
                .orElseGet(() -> configurationRepository.save(Configuration.builder().build()));

        // Mise à jour sélective
        if (request.getRaisonSociale() != null) config.setRaisonSociale(request.getRaisonSociale());
        if (request.getIfu() != null) config.setIfu(request.getIfu());
        if (request.getRccm() != null) config.setRccm(request.getRccm());
        if (request.getAdresse() != null) config.setAdresse(request.getAdresse());
        if (request.getTelephone() != null) config.setTelephone(request.getTelephone());
        if (request.getEmail() != null) config.setEmail(request.getEmail());
        if (request.getTauxTvaDefaut() != null) config.setTauxTvaDefaut(request.getTauxTvaDefaut());
        if (request.getDevise() != null) config.setDevise(request.getDevise());
        if (request.getPrefixeDevis() != null) config.setPrefixeDevis(request.getPrefixeDevis());
        if (request.getPrefixeFacture() != null) config.setPrefixeFacture(request.getPrefixeFacture());
        if (request.getPrefixeBl() != null) config.setPrefixeBl(request.getPrefixeBl());
        if (request.getPrefixeAvoir() != null) config.setPrefixeAvoir(request.getPrefixeAvoir());
        if (request.getPrefixeCommande() != null) config.setPrefixeCommande(request.getPrefixeCommande());
        if (request.getSeuilAlerteStock() != null) config.setSeuilAlerteStock(request.getSeuilAlerteStock());

        config = configurationRepository.save(config);
        auditService.logAction("UPDATE", "Configuration", config.getId(), "Mise à jour configuration système");
        return ResponseEntity.ok(ApiResponse.success("Configuration mise à jour", config));
    }
}
