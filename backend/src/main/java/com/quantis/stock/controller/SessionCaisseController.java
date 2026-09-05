package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.FermerCaisseRequest;
import com.quantis.stock.dto.OuvrirCaisseRequest;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.model.SessionCaisse;
import com.quantis.stock.service.SessionCaisseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping("/caisses")
@RequiredArgsConstructor
public class SessionCaisseController {

    private final SessionCaisseService sessionCaisseService;

    @PostMapping("/ouvrir")
    @PreAuthorize("hasAuthority('JOURNAL_CAISSE') or hasAuthority('PAIEMENT_CLIENT')")
    public ResponseEntity<ApiResponse<SessionCaisse>> ouvrirSession(
            @Valid @RequestBody OuvrirCaisseRequest request,
            Authentication auth) {
        SessionCaisse session = sessionCaisseService.ouvrirSession(auth.getName(), request);
        return ResponseEntity.ok(ApiResponse.success("Session de caisse ouverte avec succès", session));
    }

    @PostMapping("/fermer")
    @PreAuthorize("hasAuthority('JOURNAL_CAISSE') or hasAuthority('PAIEMENT_CLIENT')")
    public ResponseEntity<ApiResponse<SessionCaisse>> fermerSession(
            @Valid @RequestBody FermerCaisseRequest request,
            Authentication auth) {
        SessionCaisse session = sessionCaisseService.fermerSession(auth.getName(), request);
        return ResponseEntity.ok(ApiResponse.success("Session de caisse fermée avec succès", session));
    }

    @GetMapping("/session-active")
    @PreAuthorize("hasAuthority('JOURNAL_CAISSE') or hasAuthority('PAIEMENT_CLIENT')")
    public ResponseEntity<ApiResponse<SessionCaisse>> getSessionActive(Authentication auth) {
        Optional<SessionCaisse> session = sessionCaisseService.getSessionActive(auth.getName());
        return ResponseEntity.ok(ApiResponse.success(session.orElse(null)));
    }

    @GetMapping("/historique")
    @PreAuthorize("hasAuthority('JOURNAL_CAISSE') or hasAuthority('RAPPORTS_FINANCIERS')")
    public ResponseEntity<ApiResponse<PagedResponse<SessionCaisse>>> getHistorique(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by("id").descending());
        Page<SessionCaisse> result = sessionCaisseService.findAll(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
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
