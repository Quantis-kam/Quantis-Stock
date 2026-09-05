package com.quantis.stock.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Ligne d'écriture du Grand Livre Général.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EcritureGrandLivreDto {
    private LocalDate date;
    private String typeFlux; // VENTE, ACHAT, ENCAISSEMENT_CLIENT, REGLEMENT_FOURNISSEUR, DEPENSE_CAISSE, APPORT_CAISSE
    private String referencePiece;
    private String tiersOuCategorie;
    private String libelle;
    private BigDecimal debit; // Flux positif / entrée trésorerie ou produit
    private BigDecimal credit; // Flux négatif / sortie trésorerie ou charge
    private BigDecimal soldeProgressif;
}
