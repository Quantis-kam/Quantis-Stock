package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Client;
import com.quantis.stock.repository.ClientRepository;
import com.quantis.stock.repository.DocumentRepository;
import com.quantis.stock.repository.PaiementRepository;
import com.quantis.stock.service.AuditService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/clients")
@RequiredArgsConstructor
public class ClientController {

    private final ClientRepository clientRepository;
    private final DocumentRepository documentRepository;
    private final PaiementRepository paiementRepository;
    private final AuditService auditService;
    private final com.quantis.stock.security.SecurityUtils securityUtils;

    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<Client>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Client> result;
        if (securityUtils.isSuperAdmin()) {
            result = clientRepository.findByActifTrue(pageable);
        } else {
            Long entId = securityUtils.getCurrentEntrepriseId();
            result = entId != null
                    ? clientRepository.findByEntrepriseIdAndActifTrue(entId, pageable)
                    : clientRepository.findByActifTrue(pageable);
        }
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    private Client getClientAndCheckEntreprise(Long id) {
        Client client = clientRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Client", "id", id));
        if (!securityUtils.isSuperAdmin()) {
            Long entId = securityUtils.getCurrentEntrepriseId();
            if (client.getEntreprise() != null && !client.getEntreprise().getId().equals(entId)) {
                throw new com.quantis.stock.exception.BusinessException("Accès refusé : ce client n'appartient pas à votre entreprise");
            }
        }
        return client;
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Client>> findById(@PathVariable Long id) {
        Client client = getClientAndCheckEntreprise(id);
        return ResponseEntity.ok(ApiResponse.success(client));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<PagedResponse<Client>>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Client> result;
        if (securityUtils.isSuperAdmin()) {
            result = clientRepository.search(q, pageable);
        } else {
            Long entId = securityUtils.getCurrentEntrepriseId();
            result = entId != null
                    ? clientRepository.searchByEntreprise(entId, q, pageable)
                    : clientRepository.search(q, pageable);
        }
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('CRUD_CLIENTS')")
    public ResponseEntity<ApiResponse<Client>> create(@Valid @RequestBody Client client) {
        client.setId(null);
        client.setEntreprise(securityUtils.getCurrentEntreprise().orElse(null));
        if (client.getSoldeCredit() == null) {
            client.setSoldeCredit(java.math.BigDecimal.ZERO);
        }
        Client saved = clientRepository.save(client);
        auditService.logAction("CREATE", "Client", saved.getId(), "Création client " + saved.getNom());
        return new ResponseEntity<>(ApiResponse.success("Client créé", saved), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('CRUD_CLIENTS')")
    public ResponseEntity<ApiResponse<Client>> update(@PathVariable Long id, @Valid @RequestBody Client request) {
        Client client = getClientAndCheckEntreprise(id);
        client.setNom(request.getNom());
        client.setTelephone(request.getTelephone());
        client.setEmail(request.getEmail());
        client.setAdresse(request.getAdresse());
        client.setNotes(request.getNotes());
        if (request.getSoldeCredit() != null) {
            client.setSoldeCredit(request.getSoldeCredit());
        }
        Client updated = clientRepository.save(client);
        auditService.logAction("UPDATE", "Client", updated.getId(), "Modification client " + updated.getNom());
        return ResponseEntity.ok(ApiResponse.success("Client mis à jour", updated));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('CRUD_CLIENTS')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        Client client = getClientAndCheckEntreprise(id);
        client.setActif(false);
        clientRepository.save(client);
        auditService.logAction("DELETE", "Client", client.getId(), "Désactivation client " + client.getNom());
        return ResponseEntity.ok(ApiResponse.success("Client désactivé", null));
    }

    // =================== SOLDE DYNAMIQUE ===================

    /**
     * GET /clients/{id}/balance — Solde recalculé dynamiquement
     * = somme factures validées - somme paiements
     */
    @GetMapping("/{id}/balance")
    public ResponseEntity<ApiResponse<java.util.Map<String, Object>>> getBalance(@PathVariable Long id) {
        Client client = getClientAndCheckEntreprise(id);

        java.math.BigDecimal totalFactures = documentRepository.sumTotalTtcByClientAndType(id, "FACTURE");
        java.math.BigDecimal totalAvoirs = documentRepository.sumTotalTtcByClientAndType(id, "AVOIR");
        java.math.BigDecimal totalPaiements = paiementRepository.sumByClientId(id);

        if (totalFactures == null) totalFactures = java.math.BigDecimal.ZERO;
        if (totalAvoirs == null) totalAvoirs = java.math.BigDecimal.ZERO;
        if (totalPaiements == null) totalPaiements = java.math.BigDecimal.ZERO;

        java.math.BigDecimal solde = totalFactures.subtract(totalAvoirs).subtract(totalPaiements);

        return ResponseEntity.ok(ApiResponse.success(java.util.Map.of(
                "clientId", id,
                "clientNom", client.getNom(),
                "totalFactures", totalFactures,
                "totalAvoirs", totalAvoirs,
                "totalPaiements", totalPaiements,
                "solde", solde
        )));
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
