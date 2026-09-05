package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/**
 * Variante de produit (Taille, Couleur, Poids, etc.).
 * Les prix override sont nullables — si null, le prix du produit parent est utilisé.
 */
@Entity
@Table(name = "variante_produit", indexes = {
    @Index(name = "idx_variante_sku", columnList = "sku_variante")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class VarianteProduit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "produit_id", nullable = false)
    private Produit produit;

    @Column(nullable = false, length = 50)
    private String attribut; // ex: Taille, Couleur, Poids

    @Column(nullable = false, length = 100)
    private String valeur; // ex: XL, Rouge, 500g

    @Column(name = "sku_variante", unique = true, length = 60)
    private String skuVariante;

    @Column(name = "code_barres_variante", length = 50)
    private String codeBarresVariante;

    @Column(name = "prix_achat_override", precision = 15, scale = 2)
    private BigDecimal prixAchatOverride;

    @Column(name = "prix_vente_override", precision = 15, scale = 2)
    private BigDecimal prixVenteOverride;

    @Builder.Default
    @Column(nullable = false)
    private Boolean actif = true;

    /**
     * Retourne le prix de vente effectif (override ou hérité du produit parent).
     */
    public BigDecimal getPrixVenteEffectif() {
        return prixVenteOverride != null ? prixVenteOverride : produit.getPrixVente();
    }

    public BigDecimal getPrixAchatEffectif() {
        return prixAchatOverride != null ? prixAchatOverride : produit.getPrixAchat();
    }
}
