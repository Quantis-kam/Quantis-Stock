package com.quantis.stock.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReapprovisionnementSuggestionDto {
    private Long produitId;
    private String sku;
    private String nom;
    private String categorie;
    private String unite;
    private BigDecimal stockActuel;
    private Integer seuilAlerte;
    private BigDecimal ventesMoisDernier;
    private BigDecimal ventesMoyennesJour;
    private Integer joursAutonomie;
    private BigDecimal quantiteSuggeree;
    private BigDecimal prixAchat;
    private BigDecimal montantTotalEstime;
    private String statutUrgence; // "CRITIQUE", "ATTENTION", "NORMAL"
}
