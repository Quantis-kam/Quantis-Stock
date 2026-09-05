package com.quantis.stock.model;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Configuration système — paramètres globaux de l'application.
 * Table à une seule ligne (id = 1).
 */
@Entity
@Table(name = "configuration")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class Configuration {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Informations entreprise
    @Column(name = "raison_sociale", length = 200)
    private String raisonSociale;

    @Column(length = 50)
    private String ifu;

    @Column(length = 50)
    private String rccm;

    @Column(length = 500)
    private String adresse;

    @Column(length = 50)
    private String telephone;

    @Column(length = 100)
    private String email;

    // Paramètres comptables
    @Builder.Default
    @Column(name = "taux_tva_defaut", precision = 5, scale = 2)
    private BigDecimal tauxTvaDefaut = new BigDecimal("18.00");

    @Builder.Default
    @Column(name = "devise", length = 10)
    private String devise = "FCFA";

    // Préfixes de numérotation
    @Builder.Default
    @Column(name = "prefixe_devis", length = 20)
    private String prefixeDevis = "DEV-";

    @Builder.Default
    @Column(name = "prefixe_facture", length = 20)
    private String prefixeFacture = "FAC-";

    @Builder.Default
    @Column(name = "prefixe_bl", length = 20)
    private String prefixeBl = "BL-";

    @Builder.Default
    @Column(name = "prefixe_avoir", length = 20)
    private String prefixeAvoir = "AV-";

    @Builder.Default
    @Column(name = "prefixe_commande", length = 20)
    private String prefixeCommande = "CMD-";

    // Seuils et alertes
    @Builder.Default
    @Column(name = "seuil_alerte_stock")
    private Integer seuilAlerteStock = 10;

    @CreatedDate
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}
