package com.quantis.stock.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class ReconciliationRequest {

    @NotNull(message = "L'ID du dépôt est requis")
    private Long depotId;

    @NotEmpty(message = "La liste des articles ne peut pas être vide")
    @Valid
    private List<ReconciliationItem> items;

    private String reference;
    private String commentaire;
}
