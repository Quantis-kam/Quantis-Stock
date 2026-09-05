package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Ligne de document — détail d'un produit dans un devis/facture.
 * Calcul TVA 18% Burkina Faso.
 */
@Entity
@Table(name = "ligne_document")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class LigneDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "document_id", nullable = false)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private Document document;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "produit_id", nullable = false)
    private Produit produit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "variante_id")
    private VarianteProduit variante;

    @Column(nullable = false, length = 250)
    private String designation;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal quantite;

    @Column(name = "prix_unitaire", nullable = false, precision = 15, scale = 2)
    private BigDecimal prixUnitaire;

    @Builder.Default
    @Column(name = "taux_tva", precision = 5, scale = 2)
    private BigDecimal tauxTva = new BigDecimal("18.00");

    @Column(name = "montant_ht", precision = 15, scale = 2)
    private BigDecimal montantHt;

    @Column(name = "montant_tva", precision = 15, scale = 2)
    private BigDecimal montantTva;

    @Column(name = "montant_ttc", precision = 15, scale = 2)
    private BigDecimal montantTtc;

    /**
     * Calcule les montants HT, TVA et TTC.
     */
    public void calculerMontants() {
        this.montantHt = prixUnitaire.multiply(quantite).setScale(2, RoundingMode.HALF_UP);
        this.montantTva = montantHt.multiply(tauxTva)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        this.montantTtc = montantHt.add(montantTva);
    }
}
