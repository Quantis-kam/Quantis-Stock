package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/**
 * Entité LigneArretStock — Détail par produit pour un arrêt de stock donné.
 */
@Entity
@Table(name = "ligne_arret_stock")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class LigneArretStock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "arret_stock_id", nullable = false)
    @JsonIgnore
    private ArretStock arretStock;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "produit_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Produit produit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "variante_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private VarianteProduit variante;

    @Column(name = "quantite_projetee", nullable = false, precision = 15, scale = 2)
    private BigDecimal quantiteProjetee;

    @Column(name = "prix_achat_unitaire", nullable = false, precision = 15, scale = 2)
    private BigDecimal prixAchatUnitaire;

    @Column(name = "prix_vente_unitaire", nullable = false, precision = 15, scale = 2)
    private BigDecimal prixVenteUnitaire;

    @Column(name = "valeur_achat_totale", nullable = false, precision = 15, scale = 2)
    private BigDecimal valeurAchatTotale;

    @Column(name = "valeur_vente_totale", nullable = false, precision = 15, scale = 2)
    private BigDecimal valeurVenteTotale;
}
