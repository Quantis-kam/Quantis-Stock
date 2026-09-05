package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.quantis.stock.model.enums.StatutSessionCaisse;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Entité SessionCaisse — Session d'ouverture/fermeture autonome de caisse.
 * Permet le suivi rigoureux du fond de caisse, des entrées/sorties et des écarts de caisse.
 */
@Entity
@Table(name = "session_caisse")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class SessionCaisse {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "caissier_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Utilisateur caissier;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Depot depot;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entreprise_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Entreprise entreprise;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private StatutSessionCaisse statut = StatutSessionCaisse.OUVERTE;

    @Column(name = "date_ouverture", nullable = false)
    private Instant dateOuverture;

    @Column(name = "date_fermeture")
    private Instant dateFermeture;

    @Column(name = "fond_caisse_ouverture", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal fondCaisseOuverture = BigDecimal.ZERO;

    @Column(name = "total_entrees", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal totalEntrees = BigDecimal.ZERO;

    @Column(name = "total_sorties", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal totalSorties = BigDecimal.ZERO;

    @Column(name = "solde_theorique", nullable = false, precision = 15, scale = 2)
    @Builder.Default
    private BigDecimal soldeTheorique = BigDecimal.ZERO;

    @Column(name = "solde_compte", precision = 15, scale = 2)
    private BigDecimal soldeCompte;

    @Column(name = "ecart", precision = 15, scale = 2)
    private BigDecimal ecart;

    @Column(length = 255)
    private String notes;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * Recalcule le solde théorique de la session.
     */
    public void recalculerSoldeTheorique() {
        BigDecimal fond = fondCaisseOuverture != null ? fondCaisseOuverture : BigDecimal.ZERO;
        BigDecimal entrees = totalEntrees != null ? totalEntrees : BigDecimal.ZERO;
        BigDecimal sorties = totalSorties != null ? totalSorties : BigDecimal.ZERO;
        this.soldeTheorique = fond.add(entrees).subtract(sorties);
    }
}
