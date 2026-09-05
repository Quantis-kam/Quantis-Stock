package com.quantis.stock.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ReconciliationItem {

    @NotNull(message = "L'ID produit est requis")
    private Long produitId;

    private Long varianteId;

    @NotNull(message = "La quantité physique est requise")
    @DecimalMin(value = "0.00", message = "La quantité physique doit être >= 0")
    private BigDecimal quantitePhysique;
}
