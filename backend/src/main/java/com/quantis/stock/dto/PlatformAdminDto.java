package com.quantis.stock.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public class PlatformAdminDto {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlatformStatsDto {
        private long totalEntreprises;
        private long entreprisesActives;
        private long entreprisesSuspendues;
        private long totalUtilisateurs;
        private long totalDocuments;
        private long totalProduits;
        // Métriques financières consolidées plateforme
        private BigDecimal chiffreAffairesGlobal;
        private BigDecimal totalAchatsGlobal;
        private BigDecimal margeGlobale;
        private long totalVentesCount;
        private long totalAchatsCount;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EntrepriseCreateRequest {
        @NotBlank(message = "Le nom de l'entreprise est obligatoire")
        private String nom;
        private String nif;
        private String rccm;
        private String telephone;
        private String email;
        private String adresse;
        @Builder.Default
        private String monnaie = "FCFA";
        @Builder.Default
        private String formatFacture = "FAC-{YYYY}-{NNNNN}";

        // Administrateur initial
        @NotBlank(message = "Le nom de l'administrateur est obligatoire")
        private String adminNom;
        @NotBlank(message = "Le prénom de l'administrateur est obligatoire")
        private String adminPrenom;
        @NotBlank(message = "L'email de l'administrateur est obligatoire")
        @Email(message = "Email administrateur invalide")
        private String adminEmail;
        @NotBlank(message = "Le mot de passe administrateur est obligatoire")
        private String adminMotDePasse;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EntrepriseListItemDto {
        private Long id;
        private String nom;
        private String nif;
        private String rccm;
        private String telephone;
        private String email;
        private String adresse;
        private String monnaie;
        private String formatFacture;
        private String logoUrl;
        private Boolean estActif;
        private Instant createdAt;
        private long userCount;
        private long productCount;
        private long documentCount;
        private String adminEmail;

        // Supervision Financière et Opérationnelle par Entreprise
        private BigDecimal chiffreAffaires;
        private BigDecimal totalAchats;
        private BigDecimal margeBrute;
        private long ventesCount;
        private long achatsCount;
        private BigDecimal soldeCaisse;

        // Licence & Abonnement
        private java.time.LocalDate dateExpirationLicence;
        private String statutLicence;
        private Boolean isLicenceValide;
        private Long joursRestantsLicence;
        private Double montantAbonnement;
        private String codeUssdRenouvellement;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EntrepriseSupervisionDto {
        private Long entrepriseId;
        private String entrepriseNom;
        private String monnaie;
        private BigDecimal chiffreAffaires;
        private BigDecimal totalAchats;
        private BigDecimal margeBrute;
        private BigDecimal soldeCaisse;
        private long ventesCount;
        private long achatsCount;
        private long clientsCount;
        private long fournisseursCount;
        private long produitsCount;
        private long utilisateursCount;
        private List<DocumentSummaryDto> dernieresVentes;
        private List<AchatSummaryDto> derniersAchats;

        // Licence & Abonnement
        private java.time.LocalDate dateExpirationLicence;
        private String statutLicence;
        private Boolean isLicenceValide;
        private Long joursRestantsLicence;
        private Double montantAbonnement;
        private String codeUssdRenouvellement;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DocumentSummaryDto {
        private Long id;
        private String numero;
        private String clientNom;
        private String type;
        private String statut;
        private BigDecimal totalTtc;
        private String date;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AchatSummaryDto {
        private Long id;
        private String numero;
        private String fournisseurNom;
        private String statut;
        private BigDecimal totalHt;
        private String date;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ResetPasswordRequest {
        @NotBlank(message = "Le nouveau mot de passe est obligatoire")
        private String newPassword;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class LicenceRenewalRequest {
        private Integer nbMois; // par défaut 1
        private String nouvelleDateExpiration; // optionnel (YYYY-MM-DD)
        private String referencePaiement; // ex: Orange Money ID
        private String notes;
    }
}
