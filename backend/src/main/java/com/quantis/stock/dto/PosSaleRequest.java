package com.quantis.stock.dto;

import com.quantis.stock.model.enums.MoyenPaiement;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

/**
 * DTO de requête pour une vente directe / encaissement rapide au comptoir (POS).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PosSaleRequest {

    private Long clientId; // Optionnel (défaut: Client Comptoir / Divers)
    private Long depotId;  // Optionnel (défaut: Dépôt assigné à l'utilisateur)

    @NotEmpty(message = "Le panier doit contenir au moins une ligne")
    private List<LignePosRequest> lignes;

    @NotNull(message = "Le moyen de paiement est obligatoire")
    @Builder.Default
    private MoyenPaiement moyenPaiement = MoyenPaiement.ESPECES;

    @NotNull(message = "Le montant payé est obligatoire")
    private BigDecimal montantPaye;

    private BigDecimal montantRecu; // Optionnel (pour calcul du rendu monnaie)
    private BigDecimal remiseGlobale;
    private String notes;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class LignePosRequest {
        @NotNull(message = "Le produit est obligatoire")
        private Long produitId;

        private Long varianteId;
        private String designation;

        @NotNull(message = "La quantité est obligatoire")
        private BigDecimal quantite;

        @NotNull(message = "Le prix unitaire est obligatoire")
        private BigDecimal prixUnitaire;

        private BigDecimal tauxTva;
        private BigDecimal remise;
    }
}
