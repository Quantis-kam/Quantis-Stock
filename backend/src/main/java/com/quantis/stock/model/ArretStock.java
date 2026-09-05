package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Entité ArretStock — Snapshot/gel de l'état du stock à un instant T.
 * Permet l'audit de fin de mois et la valorisation figée des stocks.
 */
@Entity
@Table(name = "arret_stock")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class ArretStock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50, unique = true)
    private String reference;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Depot depot;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entreprise_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Entreprise entreprise;

    @Column(name = "date_arret", nullable = false)
    private Instant dateArret;

    @Column(name = "valeur_totale_achat", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal valeurTotaleAchat = BigDecimal.ZERO;

    @Column(name = "valeur_totale_vente", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal valeurTotaleVente = BigDecimal.ZERO;

    @Column(name = "nbr_produits", nullable = false)
    @Builder.Default
    private Integer nbrProduits = 0;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "utilisateur_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Utilisateur utilisateur;

    @Column(length = 255)
    private String notes;

    @OneToMany(mappedBy = "arretStock", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    @JsonIgnoreProperties("arretStock")
    private List<LigneArretStock> lignes = new ArrayList<>();

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
