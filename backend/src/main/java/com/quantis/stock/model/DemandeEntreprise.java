package com.quantis.stock.model;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

/**
 * Demande publique de création d'espace entreprise soumise depuis la page d'accueil vitrine.
 * Permet au Super-Administrateur de suivre les prospects et de créer leur entreprise en 1 clic.
 */
@Entity
@Table(name = "demande_entreprise", indexes = {
    @Index(name = "idx_demande_statut", columnList = "statut"),
    @Index(name = "idx_demande_created_at", columnList = "created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class DemandeEntreprise {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "nom_entreprise", nullable = false, length = 150)
    private String nomEntreprise;

    @Column(name = "secteur_activite", length = 100)
    private String secteurActivite;

    @Column(length = 100)
    private String ville;

    @Column(name = "nom_responsable", nullable = false, length = 120)
    private String nomResponsable;

    @Column(nullable = false, length = 40)
    private String telephone;

    @Column(nullable = false, length = 150)
    private String email;

    @Column(columnDefinition = "TEXT")
    private String message;

    /** WHATSAPP, EMAIL ou FORMULAIRE */
    @Builder.Default
    @Column(name = "canal_contact", length = 20)
    private String canalContact = "WHATSAPP";

    /** EN_ATTENTE, TRAITEE, REJETEE */
    @Builder.Default
    @Column(nullable = false, length = 20)
    private String statut = "EN_ATTENTE";

    @Column(name = "entreprise_creee_id")
    private Long entrepriseCreeeId;

    @Column(name = "note_admin", columnDefinition = "TEXT")
    private String noteAdmin;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}

