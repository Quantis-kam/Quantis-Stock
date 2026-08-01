package com.quantis.stock.model;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

/**
 * Journal d'audit — trace toutes les actions sensibles.
 */
@Entity
@Table(name = "audit_log", indexes = {
    @Index(name = "idx_audit_date", columnList = "created_at"),
    @Index(name = "idx_audit_entite", columnList = "entite, entite_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "utilisateur_id")
    private Utilisateur utilisateur;

    @Column(nullable = false, length = 20)
    private String action; // CREATE, UPDATE, DELETE, LOGIN, LOGOUT

    @Column(nullable = false, length = 50)
    private String entite; // Produit, Document, etc.

    @Column(name = "entite_id")
    private Long entiteId;

    @Column(columnDefinition = "TEXT")
    private String details; // JSON string for H2 compat (jsonb in PostgreSQL)

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
