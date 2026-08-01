package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.model.Document;
import com.quantis.stock.model.Paiement;
import com.quantis.stock.model.enums.TypeDocument;
import com.quantis.stock.service.DocumentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/documents")
@RequiredArgsConstructor
public class DocumentController {

    private final DocumentService documentService;

    /**
     * POST /documents — Créer un document (Devis/BL/Facture/Avoir)
     */
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','CAISSIER')")
    public ResponseEntity<ApiResponse<Document>> create(
            @Valid @RequestBody DocumentRequest request,
            Authentication auth) {
        Document doc = documentService.creerDocument(request, auth.getName());
        return new ResponseEntity<>(ApiResponse.success("Document créé: " + doc.getNumero(), doc), HttpStatus.CREATED);
    }

    /**
     * GET /documents/{id} — Détail d'un document
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Document>> findById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(documentService.findById(id)));
    }

    /**
     * GET /documents/numero/{numero} — Par numéro
     */
    @GetMapping("/numero/{numero}")
    public ResponseEntity<ApiResponse<Document>> findByNumero(@PathVariable String numero) {
        return ResponseEntity.ok(ApiResponse.success(documentService.findByNumero(numero)));
    }

    /**
     * GET /documents?type=FACTURE — Par type, paginé
     */
    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<Document>>> findByType(
            @RequestParam TypeDocument type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Document> result = documentService.findByType(type, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * GET /documents/client/{clientId} — Documents d'un client
     */
    @GetMapping("/client/{clientId}")
    public ResponseEntity<ApiResponse<PagedResponse<Document>>> findByClient(
            @PathVariable Long clientId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Document> result = documentService.findByClient(clientId, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * PUT /documents/{id}/validate — Valider un brouillon
     */
    @PutMapping("/{id}/validate")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Document>> validate(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success("Document validé", documentService.validerDocument(id)));
    }

    /**
     * PUT /documents/{id}/cancel — Annuler un document
     */
    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT')")
    public ResponseEntity<ApiResponse<Document>> cancel(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success("Document annulé", documentService.annulerDocument(id)));
    }

    // =================== PAIEMENTS ===================

    /**
     * POST /documents/payments — Enregistrer un paiement
     */
    @PostMapping("/payments")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','CAISSIER')")
    public ResponseEntity<ApiResponse<Paiement>> createPayment(
            @Valid @RequestBody PaiementRequest request,
            Authentication auth) {
        Paiement paiement = documentService.enregistrerPaiement(request, auth.getName());
        return new ResponseEntity<>(ApiResponse.success("Paiement enregistré", paiement), HttpStatus.CREATED);
    }

    /**
     * GET /documents/{id}/payments — Paiements d'un document
     */
    @GetMapping("/{id}/payments")
    public ResponseEntity<ApiResponse<List<Paiement>>> getPayments(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(documentService.getPaiementsParDocument(id)));
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
