package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

/**
 * Entité représentant un arrêté périodique ou une clôture comptable (mensuelle, trimestrielle, annuelle).
 */
@Entity
@Table(name = "cloture_comptable", indexes = {
    @Index(name = "idx_cloture_periode", columnList = "periode"),
    @Index(name = "idx_cloture_dates", columnList = "date_debut, date_fin")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class ClotureComptable extends BaseEntity {

    @Column(nullable = false, length = 50)
    private String periode; // ex: "2026-08", "2026-09"

    @Column(length = 150)
    private String libelle; // ex: "Arrêté Mensuel Août 2026"

    @Column(name = "date_debut", nullable = false)
    private LocalDate dateDebut;

    @Column(name = "date_fin", nullable = false)
    private LocalDate dateFin;

    @Column(name = "date_cloture", nullable = false)
    private Instant dateCloture;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cloture_par_id")
    private Utilisateur cloturePar;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entreprise_id")
    private Entreprise entreprise;

    @Column(name = "ca_ttc", precision = 15, scale = 2)
    private BigDecimal chiffreAffairesTtc;

    @Column(name = "ca_ht", precision = 15, scale = 2)
    private BigDecimal chiffreAffairesHt;

    @Column(name = "tva_collectee", precision = 15, scale = 2)
    private BigDecimal totalTvaCollectee;

    @Column(name = "achats_ht", precision = 15, scale = 2)
    private BigDecimal totalAchatsHt;

    @Column(name = "depenses_caisse", precision = 15, scale = 2)
    private BigDecimal totalDepensesCaisse;

    @Column(name = "entrees_caisse", precision = 15, scale = 2)
    private BigDecimal totalEntreesCaisse;

    @Column(name = "marge_brute", precision = 15, scale = 2)
    private BigDecimal margeBruteEstimee;

    @Column(name = "valeur_stock_fin", precision = 15, scale = 2)
    private BigDecimal valeurStockFinPeriode;

    @Column(name = "creances_clients", precision = 15, scale = 2)
    private BigDecimal totalCreancesClients;

    @Column(name = "dettes_fournisseurs", precision = 15, scale = 2)
    private BigDecimal totalDettesFournisseurs;

    @Column(name = "solde_caisse_final", precision = 15, scale = 2)
    private BigDecimal soldeCaisseFinal;

    @Column(length = 30, nullable = false)
    @Builder.Default
    private String statut = "VERROUILLE"; // SIMULATION, VERROUILLE

    @Column(columnDefinition = "TEXT")
    private String notes;
}
