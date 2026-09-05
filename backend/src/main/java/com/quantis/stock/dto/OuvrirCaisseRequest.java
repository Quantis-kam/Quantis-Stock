package com.quantis.stock.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class OuvrirCaisseRequest {

    @NotNull(message = "Le fond de caisse d'ouverture est requis")
    @PositiveOrZero(message = "Le fond de caisse doit être positif ou nul")
    private BigDecimal fondCaisseOuverture;

    private Long depotId;

    private String notes;
}
