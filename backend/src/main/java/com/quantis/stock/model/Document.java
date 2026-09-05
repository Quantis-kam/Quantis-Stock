package com.quantis.stock.model;

import com.quantis.stock.model.enums.StatutDocument;
import com.quantis.stock.model.enums.TypeDocument;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
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
import java.util.UUID;

/**
 * Document commercial — Devis, Bon de Livraison, Facture, Avoir.
 * Workflow : DEVIS → BON_LIVRAISON → FACTURE (conversion via document_parent_id).
 */
@Entity
@Table(name = "document", indexes = {
    @Index(name = "idx_document_client", columnList = "client_id"),
    @Index(name = "idx_document_numero", columnList = "numero"),
    @Index(name = "idx_document_date", columnList = "date_document"),
    @Index(name = "idx_document_uuid", columnList = "uuid_sync")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Builder.Default
    @Column(name = "uuid_sync", unique = true, nullable = false, length = 36)
    private String uuidSync = UUID.randomUUID().toString();

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30, columnDefinition = "VARCHAR(30)")
    private TypeDocument type;

    @Column(unique = true, nullable = false, length = 30)
    private String numero;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "client_id")
    private Client client;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_id")
    private Depot depot;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entreprise_id")
    private Entreprise entreprise;

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 15)
    private StatutDocument statut = StatutDocument.BROUILLON;

    @Builder.Default
    @Column(name = "total_ht", precision = 15, scale = 2)
    private BigDecimal totalHt = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "total_tva", precision = 15, scale = 2)
    private BigDecimal totalTva = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "total_ttc", precision = 15, scale = 2)
    private BigDecimal totalTtc = BigDecimal.ZERO;

    @Column(name = "date_document")
    private LocalDate dateDocument;

    @Column(name = "date_echeance")
    private LocalDate dateEcheance;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "document_parent_id")
    private Document documentParent;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "utilisateur_id", nullable = false)
    private Utilisateur utilisateur;

    @OneToMany(mappedBy = "document", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<LigneDocument> lignes = new ArrayList<>();

    @OneToMany(mappedBy = "document")
    @Builder.Default
    private List<Paiement> paiements = new ArrayList<>();

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    /**
     * Recalcule les totaux à partir des lignes.
     */
    public void recalculerTotaux() {
        this.totalHt = lignes.stream()
                .map(LigneDocument::getMontantHt)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        this.totalTva = lignes.stream()
                .map(LigneDocument::getMontantTva)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        this.totalTtc = lignes.stream()
                .map(LigneDocument::getMontantTtc)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * Montant total déjà payé.
     */
    public BigDecimal getMontantPaye() {
        return paiements.stream()
                .map(Paiement::getMontant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /**
     * Solde restant à payer.
     */
    public BigDecimal getSoldeRestant() {
        return totalTtc.subtract(getMontantPaye());
    }
}
