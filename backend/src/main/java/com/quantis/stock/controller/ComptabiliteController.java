package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.model.ClotureComptable;
import com.quantis.stock.model.MouvementCaisse;
import com.quantis.stock.service.AuditService;
import com.quantis.stock.service.ComptabiliteService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/accounting")
@RequiredArgsConstructor
public class ComptabiliteController {

    private final ComptabiliteService comptabiliteService;
    private final AuditService auditService;
    private final com.quantis.stock.service.DataSeederService dataSeederService;

    // =================== JOURNAL DE CAISSE ===================

    /**
     * POST /accounting/cash — Enregistrer un mouvement de caisse
     */
    @PostMapping("/cash")
    @PreAuthorize("hasAuthority('JOURNAL_CAISSE')")
    public ResponseEntity<ApiResponse<MouvementCaisse>> createCashEntry(
            @RequestBody MouvementCaisse mouvement,
            Authentication auth) {
        MouvementCaisse saved = comptabiliteService.enregistrerMouvement(mouvement, auth.getName());
        auditService.logAction("CREATE", "MouvementCaisse", saved.getId(),
                "Mouvement caisse " + saved.getType() + " de " + saved.getMontant() + " FCFA");
        return new ResponseEntity<>(ApiResponse.success("Mouvement enregistré", saved), HttpStatus.CREATED);
    }

    /**
     * GET /accounting/cash?debut=2026-01-01&fin=2026-12-31 — Journal de caisse
     */
    @GetMapping("/cash")
    @PreAuthorize("hasAuthority('JOURNAL_CAISSE')")
    public ResponseEntity<ApiResponse<PagedResponse<MouvementCaisse>>> getCashJournal(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<MouvementCaisse> result = comptabiliteService.getJournal(debut, fin, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    /**
     * GET /accounting/report?debut=2026-01-01&fin=2026-12-31 — Rapport financier
     */
    @GetMapping("/report")
    @PreAuthorize("hasAuthority('RAPPORTS_FINANCIERS')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getReport(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {
        return ResponseEntity.ok(ApiResponse.success(comptabiliteService.getRapportPeriode(debut, fin)));
    }

    // =================== GRAND LIVRE GÉNÉRAL ===================

    /**
     * GET /accounting/grand-livre?debut=2026-01-01&fin=2026-12-31 — Grand livre général
     */
    @GetMapping("/grand-livre")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE') or hasAuthority('RAPPORTS_FINANCIERS')")
    public ResponseEntity<ApiResponse<List<EcritureGrandLivreDto>>> getGrandLivre(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {
        List<EcritureGrandLivreDto> ecritures = comptabiliteService.getGrandLivre(debut, fin);
        return ResponseEntity.ok(ApiResponse.success(ecritures));
    }

    /**
     * GET /accounting/grand-livre/export — Export CSV du Grand Livre
     */
    @GetMapping("/grand-livre/export")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE')")
    public ResponseEntity<byte[]> exportGrandLivreCsv(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {

        List<EcritureGrandLivreDto> ecritures = comptabiliteService.getGrandLivre(debut, fin);
        StringBuilder csv = new StringBuilder();
        csv.append("Date;Type de Flux;Référence Pièce;Tiers / Compte;Libellé Opération;Débit (+);Crédit (-);Solde Cumulé (FCFA)\n");

        for (EcritureGrandLivreDto e : ecritures) {
            csv.append(String.format("%s;%s;\"%s\";\"%s\";\"%s\";%s;%s;%s\n",
                    e.getDate(),
                    e.getTypeFlux(),
                    escapeCsv(e.getReferencePiece()),
                    escapeCsv(e.getTiersOuCategorie()),
                    escapeCsv(e.getLibelle()),
                    e.getDebit() != null ? e.getDebit().toPlainString() : "0",
                    e.getCredit() != null ? e.getCredit().toPlainString() : "0",
                    e.getSoldeProgressif() != null ? e.getSoldeProgressif().toPlainString() : "0"));
        }

        String filename = "grand_livre_" + debut + "_" + fin + ".csv";
        byte[] content = csv.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDispositionFormData("attachment", filename);
        headers.setContentLength(content.length);

        auditService.logAction("EXPORT", "GrandLivre", null,
                "Export CSV Grand Livre du " + debut + " au " + fin + " (" + ecritures.size() + " lignes)");

        return new ResponseEntity<>(content, headers, HttpStatus.OK);
    }

    // =================== CLÔTURES PÉRIODIQUES ===================

    /**
     * GET /accounting/clotures/simuler — Simuler un arrêté périodique
     */
    @GetMapping("/clotures/simuler")
    @PreAuthorize("hasAuthority('RAPPORTS_FINANCIERS') or hasAuthority('CONFIG_SYSTEME')")
    public ResponseEntity<ApiResponse<ClotureSyntheseDto>> simulerCloture(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin,
            @RequestParam String periode) {
        ClotureSyntheseDto synthese = comptabiliteService.simulerCloture(debut, fin, periode);
        return ResponseEntity.ok(ApiResponse.success(synthese));
    }

    /**
     * POST /accounting/clotures — Valider et verrouiller une clôture de période
     */
    @PostMapping("/clotures")
    @PreAuthorize("hasAuthority('CONFIG_SYSTEME') or hasAuthority('RAPPORTS_FINANCIERS')")
    public ResponseEntity<ApiResponse<ClotureComptable>> validerCloture(
            @Valid @RequestBody ClotureRequestDto request,
            Authentication auth) {
        ClotureComptable cloture = comptabiliteService.validerCloture(request, auth.getName());
        auditService.logAction("CLOTURE", "ClotureComptable", cloture.getId(),
                "Clôture verrouillée pour la période " + cloture.getPeriode() + " (CA TTC: " + cloture.getChiffreAffairesTtc() + " FCFA)");
        return new ResponseEntity<>(ApiResponse.success("Clôture enregistrée et verrouillée avec succès", cloture), HttpStatus.CREATED);
    }

    /**
     * GET /accounting/clotures — Historique des clôtures passées
     */
    @GetMapping("/clotures")
    @PreAuthorize("hasAuthority('RAPPORTS_FINANCIERS') or hasAuthority('CONFIG_SYSTEME')")
    public ResponseEntity<ApiResponse<List<ClotureComptable>>> getHistoriqueClotures() {
        List<ClotureComptable> clotures = comptabiliteService.getHistoriqueClotures();
        return ResponseEntity.ok(ApiResponse.success(clotures));
    }

    /**
     * POST /accounting/seed-demo — Initialiser un jeu de données réel complet
     */
    @PostMapping("/seed-demo")
    @PreAuthorize("hasAuthority('CONFIG_SYSTEME')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> seedDemoData() {
        Map<String, Object> res = dataSeederService.seedRealisticData();
        return ResponseEntity.ok(ApiResponse.success("Données réelles injectées avec succès", res));
    }

    // =================== EXPORT CSV JOURNAL CAISSE ===================

    @GetMapping("/export")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE')")
    public ResponseEntity<byte[]> exportCsv(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {

        Page<MouvementCaisse> page = comptabiliteService.getJournal(debut, fin, PageRequest.of(0, 10000));
        List<MouvementCaisse> mouvements = page.getContent();

        StringBuilder csv = new StringBuilder();
        csv.append("Date;Type;Libellé;Catégorie;Montant (FCFA);Référence;Notes\n");

        for (MouvementCaisse m : mouvements) {
            csv.append(String.format("%s;%s;\"%s\";\"%s\";%s;\"%s\";\"%s\"\n",
                    m.getDateMouvement(),
                    m.getType(),
                    escapeCsv(m.getLibelle()),
                    escapeCsv(m.getCategorie()),
                    m.getMontant().toPlainString(),
                    escapeCsv(m.getReference()),
                    escapeCsv(m.getNotes())));
        }

        String filename = "journal_caisse_" + debut + "_" + fin + ".csv";
        byte[] content = csv.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDispositionFormData("attachment", filename);
        headers.setContentLength(content.length);

        auditService.logAction("EXPORT", "Comptabilité", null,
                "Export CSV journal caisse du " + debut + " au " + fin + " (" + mouvements.size() + " lignes)");

        return new ResponseEntity<>(content, headers, HttpStatus.OK);
    }

    private String escapeCsv(String value) {
        if (value == null) return "";
        return value.replace("\"", "\"\"");
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
