package com.quantis.stock.model;

import com.quantis.stock.model.enums.MotifMouvement;
import com.quantis.stock.model.enums.TypeMouvement;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Mouvement de stock — trace chaque entrée, sortie, transfert ou ajustement.
 */
@Entity
@Table(name = "mouvement_stock", indexes = {
    @Index(name = "idx_mouvement_produit", columnList = "produit_id"),
    @Index(name = "idx_mouvement_date", columnList = "created_at"),
    @Index(name = "idx_mouvement_depot_source", columnList = "depot_source_id"),
    @Index(name = "idx_mouvement_uuid", columnList = "uuid_sync")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class MouvementStock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Builder.Default
    @Column(name = "uuid_sync", unique = true, nullable = false, length = 36)
    private String uuidSync = UUID.randomUUID().toString();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "produit_id", nullable = false)
    private Produit produit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "variante_id")
    private VarianteProduit variante;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_source_id")
    private Depot depotSource;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_dest_id")
    private Depot depotDest;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 15)
    private TypeMouvement type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 15)
    private MotifMouvement motif;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal quantite;

    @Column(length = 50)
    private String reference;

    @Column(columnDefinition = "TEXT")
    private String commentaire;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "utilisateur_id", nullable = false)
    private Utilisateur utilisateur;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
