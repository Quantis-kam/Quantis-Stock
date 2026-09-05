package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Produit — entité centrale du stock.
 */
@Entity
@Table(name = "produit", indexes = {
    @Index(name = "idx_produit_sku", columnList = "sku"),
    @Index(name = "idx_produit_code_barres", columnList = "code_barres"),
    @Index(name = "idx_produit_nom", columnList = "nom"),
    @Index(name = "idx_produit_categorie", columnList = "categorie_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Produit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String sku;

    @Column(name = "code_barres", unique = true, length = 50)
    private String codeBarres;

    @Column(nullable = false, length = 200)
    private String nom;

    @Column(columnDefinition = "TEXT")
    private String description;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entreprise_id")
    private Entreprise entreprise;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "categorie_id")
    private Categorie categorie;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "unite_id")
    private UniteMesure unite;

    @Column(name = "prix_achat", precision = 15, scale = 2)
    private BigDecimal prixAchat;

    @Column(name = "prix_vente", precision = 15, scale = 2)
    private BigDecimal prixVente;

    @Builder.Default
    @Column(name = "taux_tva", precision = 5, scale = 2)
    private BigDecimal tauxTva = new BigDecimal("18.00");

    @Builder.Default
    @Column(name = "seuil_alerte")
    private Integer seuilAlerte = 10;

    @Builder.Default
    @Column(nullable = false)
    private Boolean actif = true;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @OneToMany(mappedBy = "produit", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<VarianteProduit> variantes = new ArrayList<>();

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}
