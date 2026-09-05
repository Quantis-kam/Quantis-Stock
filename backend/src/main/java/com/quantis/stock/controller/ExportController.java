package com.quantis.stock.controller;

import com.quantis.stock.service.ExportService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/exports")
@RequiredArgsConstructor
public class ExportController {

    private final ExportService exportService;

    @GetMapping("/ventes")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE') or hasAuthority('VOIR_DASHBOARD')")
    public ResponseEntity<byte[]> exportVentes(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {

        byte[] csv = exportService.exportVentesCsv(debut, fin);
        String filename = "journal_ventes_" + LocalDate.now() + ".csv";

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv);
    }

    @GetMapping("/caisse")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE') or hasAuthority('JOURNAL_CAISSE')")
    public ResponseEntity<byte[]> exportCaisse(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate debut,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fin) {

        byte[] csv = exportService.exportCaisseCsv(debut, fin);
        String filename = "journal_caisse_" + LocalDate.now() + ".csv";

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv);
    }

    @GetMapping("/debiteurs")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE') or hasAuthority('VOIR_CREANCES')")
    public ResponseEntity<byte[]> exportDebiteurs() {
        byte[] csv = exportService.exportDebiteursCsv();
        String filename = "grand_livre_debiteurs_" + LocalDate.now() + ".csv";

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv);
    }

    @GetMapping("/stock")
    @PreAuthorize("hasAuthority('EXPORT_COMPTABLE') or hasAuthority('VOIR_STOCK')")
    public ResponseEntity<byte[]> exportStock() {
        byte[] csv = exportService.exportStockCsv();
        String filename = "valorisation_stock_" + LocalDate.now() + ".csv";

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv);
    }
}
