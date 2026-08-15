package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/**
 * Ligne de commande fournisseur — produit commandé + quantité reçue.
 */
@Entity
@Table(name = "ligne_commande_fournisseur")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LigneCommandeFournisseur {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "commande_id", nullable = false)
    @JsonIgnoreProperties({"lignes", "hibernateLazyInitializer", "handler"})
    private CommandeFournisseur commande;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "produit_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Produit produit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "variante_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private VarianteProduit variante;

    @Column(name = "quantite_commandee", nullable = false, precision = 15, scale = 2)
    private BigDecimal quantiteCommandee;

    @Builder.Default
    @Column(name = "quantite_recue", precision = 15, scale = 2)
    private BigDecimal quantiteRecue = BigDecimal.ZERO;

    @Column(name = "prix_unitaire", nullable = false, precision = 15, scale = 2)
    private BigDecimal prixUnitaire;

    /**
     * Quantité restante à recevoir.
     */
    public BigDecimal getQuantiteRestante() {
        return quantiteCommandee.subtract(quantiteRecue);
    }

    /**
     * Montant total de la ligne (commandé).
     */
    public BigDecimal getMontantTotal() {
        return prixUnitaire.multiply(quantiteCommandee);
    }
}
