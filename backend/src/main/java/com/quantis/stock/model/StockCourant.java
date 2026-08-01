package com.quantis.stock.model;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Stock courant — quantité en temps réel par produit/variante/dépôt.
 * Contrainte unique : (produit_id, variante_id, depot_id).
 */
@Entity
@Table(name = "stock_courant",
    uniqueConstraints = @UniqueConstraint(
        name = "uk_stock_produit_variante_depot",
        columnNames = {"produit_id", "variante_id", "depot_id"}
    ),
    indexes = @Index(name = "idx_stock_produit_depot", columnList = "produit_id, depot_id")
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class StockCourant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "produit_id", nullable = false)
    private Produit produit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "variante_id")
    private VarianteProduit variante;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_id", nullable = false)
    private Depot depot;

    @Builder.Default
    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal quantite = BigDecimal.ZERO;

    @LastModifiedDate
    @Column(name = "derniere_maj")
    private Instant derniereMaj;

    /**
     * Vérifie si le stock est en alerte basse.
     */
    public boolean isAlerteBasse() {
        return quantite.compareTo(new BigDecimal(produit.getSeuilAlerte())) <= 0;
    }

    /**
     * Vérifie si le stock est épuisé.
     */
    public boolean isEpuise() {
        return quantite.compareTo(BigDecimal.ZERO) <= 0;
    }
}
