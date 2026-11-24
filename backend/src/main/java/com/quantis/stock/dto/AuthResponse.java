package com.quantis.stock.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {

    private String accessToken;
    private String refreshToken;
    private String tokenType;
    private UserDto utilisateur;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UserDto {
        private Long id;
        private String nom;
        private String prenom;
        private String email;
        private String role;
        private String depot;
        private Long entrepriseId;
        private String entrepriseNom;
        private String entrepriseMonnaie;
        private String formatFacture;
        private String logoUrl;
        private Boolean tvaActive;
        private java.math.BigDecimal tauxTvaDefaut;
        private Boolean suiviPrixAchat;
        private Boolean isSuperAdmin;
        private Boolean hasPin;
        private java.util.List<String> permissions;
        private String dateExpirationLicence;
        private String statutLicence;
        private String codeUssdRenouvellement;
    }
}
