package com.quantis.stock.dto;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProduitRequest {

    @NotBlank(message = "Le SKU est requis")
    @Size(max = 50)
    private String sku;

    @Size(max = 50)
    private String codeBarres;

    @NotBlank(message = "Le nom est requis")
    @Size(max = 200)
    private String nom;

    private String description;
    private Long categorieId;
    private Long uniteId;

    @DecimalMin(value = "0", message = "Le prix d'achat doit être positif")
    private BigDecimal prixAchat;

    @DecimalMin(value = "0", message = "Le prix de vente doit être positif")
    private BigDecimal prixVente;

    private BigDecimal tauxTva;

    @Min(value = 0, message = "Le seuil d'alerte doit être positif")
    private Integer seuilAlerte;

    private String imageUrl;
    private List<VarianteRequest> variantes;

    @Data
    public static class VarianteRequest {
        @NotBlank(message = "L'attribut est requis")
        private String attribut;
        @NotBlank(message = "La valeur est requise")
        private String valeur;
        private String skuVariante;
        private String codeBarresVariante;
        private BigDecimal prixAchatOverride;
        private BigDecimal prixVenteOverride;
    }
}
