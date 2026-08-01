package com.quantis.stock.dto;

import com.quantis.stock.model.enums.TypeDocument;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class DocumentRequest {

    @NotNull(message = "Le type est requis")
    private TypeDocument type;

    @NotNull(message = "L'ID client est requis")
    private Long clientId;

    private Long depotId;
    private LocalDate dateDocument;
    private LocalDate dateEcheance;
    private String notes;

    /** ID du document parent (pour conversion Devis → BL → Facture) */
    private Long documentParentId;

    @NotEmpty(message = "Au moins une ligne est requise")
    private List<LigneRequest> lignes;

    @Data
    public static class LigneRequest {
        @NotNull(message = "L'ID produit est requis")
        private Long produitId;
        private Long varianteId;
        private String designation;

        @NotNull(message = "La quantité est requise")
        @DecimalMin(value = "0.01")
        private BigDecimal quantite;

        @NotNull(message = "Le prix unitaire est requis")
        @DecimalMin(value = "0")
        private BigDecimal prixUnitaire;

        private BigDecimal tauxTva;
    }
}
