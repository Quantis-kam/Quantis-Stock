package com.quantis.stock.model;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Client — acheteur de produits.
 */
@Entity
@Table(name = "client", indexes = {
    @Index(name = "idx_client_nom", columnList = "nom"),
    @Index(name = "idx_client_telephone", columnList = "telephone")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@EntityListeners(AuditingEntityListener.class)
public class Client {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nom;

    @Column(length = 20)
    private String telephone;

    @Column(length = 150)
    private String email;

    @Column(columnDefinition = "TEXT")
    private String adresse;

    @Builder.Default
    @Column(name = "solde_credit", precision = 15, scale = 2)
    private BigDecimal soldeCredit = BigDecimal.ZERO;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Builder.Default
    @Column(nullable = false)
    private Boolean actif = true;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}
