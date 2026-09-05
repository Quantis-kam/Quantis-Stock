package com.quantis.stock.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Synthèse financière pour simulation ou validation d'arrêté périodique.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ClotureSyntheseDto {
    private String periode;
    private String libelle;
    private LocalDate dateDebut;
    private LocalDate dateFin;
    private BigDecimal chiffreAffairesTtc;
    private BigDecimal chiffreAffairesHt;
    private BigDecimal totalTvaCollectee;
    private BigDecimal totalAchatsHt;
    private BigDecimal totalDepensesCaisse;
    private BigDecimal totalEntreesCaisse;
    private BigDecimal margeBruteEstimee;
    private BigDecimal valeurStockFinPeriode;
    private BigDecimal totalCreancesClients;
    private BigDecimal totalDettesFournisseurs;
    private BigDecimal soldeCaisseFinal;
    private int nombreVentes;
    private int nombreAchats;
    private int nombreMouvementsCaisse;
    private boolean dejaCloturee;
}
