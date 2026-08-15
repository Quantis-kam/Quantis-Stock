package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.quantis.stock.model.enums.StatutCommande;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Commande Fournisseur — cycle de vie :
 * BROUILLON → EN_COURS → RECUE_PARTIELLE → RECUE → ANNULEE
 */
@Entity
@Table(name = "commande_fournisseur", indexes = {
    @Index(name = "idx_commande_fournisseur", columnList = "fournisseur_id"),
    @Index(name = "idx_commande_numero", columnList = "numero"),
    @Index(name = "idx_commande_statut", columnList = "statut")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class CommandeFournisseur {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false, length = 30)
    private String numero;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "fournisseur_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Fournisseur fournisseur;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Depot depot;

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StatutCommande statut = StatutCommande.BROUILLON;

    @Column(name = "date_commande")
    private LocalDate dateCommande;

    @Column(name = "date_livraison_prevue")
    private LocalDate dateLivraisonPrevue;

    @Builder.Default
    @Column(name = "total_ht", precision = 15, scale = 2)
    private BigDecimal totalHt = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "utilisateur_id", nullable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "motDePasseHash"})
    private Utilisateur utilisateur;

    @OneToMany(mappedBy = "commande", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    @JsonIgnoreProperties({"commande"})
    private List<LigneCommandeFournisseur> lignes = new ArrayList<>();

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    /**
     * Recalcule le total HT à partir des lignes.
     */
    public void recalculerTotal() {
        this.totalHt = lignes.stream()
                .map(l -> l.getPrixUnitaire().multiply(l.getQuantiteCommandee()))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * Vérifie si toutes les lignes sont entièrement reçues.
     */
    public boolean isEntierementRecue() {
        return lignes.stream().allMatch(l ->
                l.getQuantiteRecue().compareTo(l.getQuantiteCommandee()) >= 0);
    }

    /**
     * Vérifie si au moins une ligne a été partiellement reçue.
     */
    public boolean isPartiellementRecue() {
        return lignes.stream().anyMatch(l ->
                l.getQuantiteRecue().compareTo(BigDecimal.ZERO) > 0);
    }
}
