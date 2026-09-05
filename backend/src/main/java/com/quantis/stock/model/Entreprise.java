package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

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

    @Builder.Default
    @Column(name = "est_actif", nullable = false)
    private Boolean estActif = true;

    // --- Système de Licence & Abonnement Mensuel ---
    @Column(name = "date_expiration_licence")
    private java.time.LocalDate dateExpirationLicence;

    @Builder.Default
    @Column(name = "statut_licence", length = 30)
    private String statutLicence = "ACTIVE"; // ACTIVE, EXPIREE, SUSPENDUE

    @Builder.Default
    @Column(name = "montant_abonnement")
    private Double montantAbonnement = 20200.0;

    @Builder.Default
    @Column(name = "code_ussd_renouvellement", length = 50)
    private String codeUssdRenouvellement = "*144*2*1*65189261*20200#";

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
}
