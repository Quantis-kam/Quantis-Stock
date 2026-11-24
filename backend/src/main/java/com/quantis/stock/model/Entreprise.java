package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Entité Entreprise — Tenant (Multi-entreprise).
 * Cloisonne l'ensemble des données (dépôts, utilisateurs, documents, stock).
 */
@Entity
@Table(name = "entreprise")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Entreprise {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nom;

    @Column(length = 50)
    private String nif;

    @Column(length = 50)
    private String rccm;

    @Column(length = 30)
    private String telephone;

    @Column(length = 150)
    private String email;

    @Column(length = 255)
    private String adresse;

    @Column(name = "logo_url", columnDefinition = "TEXT")
    private String logoUrl;

    @Builder.Default
    @Column(name = "monnaie", nullable = false, length = 10)
    private String monnaie = "FCFA";

    @Builder.Default
    @Column(name = "format_facture", length = 50)
    private String formatFacture = "FAC-{YYYY}-{NNNNN}";

    // --- Préférences Fiscales & Gestion Commerciale ---
    @Builder.Default
    @Column(name = "tva_active")
    private Boolean tvaActive = true;

    @Builder.Default
    @Column(name = "taux_tva_defaut", precision = 5, scale = 2)
    private BigDecimal tauxTvaDefaut = new BigDecimal("18.00");

    @Builder.Default
    @Column(name = "suivi_prix_achat")
    private Boolean suiviPrixAchat = true;

    @Builder.Default
    @Column(name = "est_actif", nullable = false)
    private Boolean estActif = true;

    public static final double DEFAULT_MONTANT_ABONNEMENT = 10100.0;
    public static final String DEFAULT_CODE_USSD = "*144*2*1*65189261*10100#";

    // --- Système de Licence & Abonnement Mensuel ---
    @Column(name = "date_expiration_licence")
    private java.time.LocalDate dateExpirationLicence;

    @Builder.Default
    @Column(name = "statut_licence", length = 30)
    private String statutLicence = "ACTIVE"; // ACTIVE, EXPIREE, SUSPENDUE

    @Builder.Default
    @Column(name = "montant_abonnement")
    private Double montantAbonnement = DEFAULT_MONTANT_ABONNEMENT;

    @Builder.Default
    @Column(name = "code_ussd_renouvellement", length = 50)
    private String codeUssdRenouvellement = DEFAULT_CODE_USSD;

    @PrePersist
    protected void initDefaultLicenceOnCreate() {
        if (dateExpirationLicence == null) {
            dateExpirationLicence = java.time.LocalDate.now().plusMonths(1);
        }
        if (statutLicence == null || statutLicence.isBlank()) {
            statutLicence = dateExpirationLicence.isBefore(java.time.LocalDate.now()) ? "EXPIREE" : "ACTIVE";
        }
        if (montantAbonnement == null || montantAbonnement <= 0) {
            montantAbonnement = DEFAULT_MONTANT_ABONNEMENT;
        }
        if (codeUssdRenouvellement == null || codeUssdRenouvellement.isBlank()) {
            codeUssdRenouvellement = DEFAULT_CODE_USSD;
        }
    }

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    public boolean isLicenceValide() {
        if (!Boolean.TRUE.equals(estActif)) {
            return false;
        }
        if (dateExpirationLicence == null) {
            return true; // licence non encore initialisée ou illimitée
        }
        return !java.time.LocalDate.now().isAfter(dateExpirationLicence);
    }

    public boolean isTvaActiveEffective() {
        return !Boolean.FALSE.equals(tvaActive);
    }

    public BigDecimal getTauxTvaDefautEffective() {
        if (!isTvaActiveEffective()) {
            return BigDecimal.ZERO;
        }
        return tauxTvaDefaut != null ? tauxTvaDefaut : new BigDecimal("18.00");
    }

    public boolean isSuiviPrixAchatEffective() {
        return !Boolean.FALSE.equals(suiviPrixAchat);
    }
}
