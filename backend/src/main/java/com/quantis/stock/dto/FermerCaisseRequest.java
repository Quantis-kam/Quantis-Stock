package com.quantis.stock.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class FermerCaisseRequest {

    @NotNull(message = "Le solde compté est requis")
    @PositiveOrZero(message = "Le solde compté doit être positif ou nul")
    private BigDecimal soldeCompte;

    private String notes;
}
