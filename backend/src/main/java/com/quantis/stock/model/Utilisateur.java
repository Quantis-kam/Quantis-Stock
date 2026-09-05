package com.quantis.stock.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.quantis.stock.model.enums.Permission;
import com.quantis.stock.model.enums.Role;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

/**
 * Entité Utilisateur — correspond au MCD.
 * Soft delete via le champ 'actif'.
 */
@Entity
@Table(name = "utilisateur", indexes = {
    @Index(name = "idx_utilisateur_email", columnList = "email")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class Utilisateur {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String nom;

    @Column(nullable = false, length = 100)
    private String prenom;

    @Column(nullable = false, unique = true, length = 150)
    private String email;

    @com.fasterxml.jackson.annotation.JsonIgnore
    @Column(name = "mot_de_passe_hash", nullable = false)
    private String motDePasseHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    /** Dépôt principal (affinité). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "depot_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Depot depot;

    /** Entreprise d'appartenance. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "entreprise_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Entreprise entreprise;

    // =================== PERMISSIONS GRANULAIRES ===================

    /**
     * Si true, on utilise permissionsPersonnalisees au lieu des permissions du rôle.
     */
    @Builder.Default
    @Column(name = "permissions_custom")
    private Boolean permissionsCustom = false;

    /**
     * Permissions personnalisées (override du rôle). Ignorées si permissionsCustom = false.
     */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "utilisateur_permissions", joinColumns = @JoinColumn(name = "utilisateur_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "permission")
    @Builder.Default
    private Set<Permission> permissionsPersonnalisees = new HashSet<>();

    /**
     * Dépôts autorisés. Si vide → accès à tous les dépôts.
     */
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "utilisateur_depots",
        joinColumns = @JoinColumn(name = "utilisateur_id"),
        inverseJoinColumns = @JoinColumn(name = "depot_id"))
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    @Builder.Default
    private Set<Depot> depotsAutorises = new HashSet<>();

    // =================== CHAMPS SYSTEME ===================

    @Builder.Default
    @Column(nullable = false)
    private Boolean actif = true;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    /**
     * Retourne les permissions effectives (custom ou rôle).
     */
    public Set<Permission> getPermissionsEffectives() {
        if (Boolean.TRUE.equals(permissionsCustom) && permissionsPersonnalisees != null && !permissionsPersonnalisees.isEmpty()) {
            return permissionsPersonnalisees;
        }
        return role.getPermissions();
    }

    /**
     * Retourne le nom complet (prénom + nom).
     */
    public String getNomComplet() {
        return prenom + " " + nom;
    }
}
