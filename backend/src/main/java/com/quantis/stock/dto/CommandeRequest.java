package com.quantis.stock.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class CommandeRequest {

    @NotNull(message = "L'ID fournisseur est requis")
    private Long fournisseurId;

    @NotNull(message = "L'ID dépôt est requis")
    private Long depotId;

    private LocalDate dateCommande;
    private LocalDate dateLivraisonPrevue;
    private String notes;

    @NotEmpty(message = "Au moins une ligne est requise")
    private List<LigneCommandeRequest> lignes;

    @Data
    public static class LigneCommandeRequest {
        @NotNull(message = "L'ID produit est requis")
        private Long produitId;
        private Long varianteId;

        @NotNull(message = "La quantité est requise")
        @DecimalMin(value = "0.01")
        private BigDecimal quantite;

        @NotNull(message = "Le prix unitaire est requis")
        @DecimalMin(value = "0")
        private BigDecimal prixUnitaire;
    }
}
