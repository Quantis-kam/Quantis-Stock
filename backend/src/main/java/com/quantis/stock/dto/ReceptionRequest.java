package com.quantis.stock.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/**
 * Requête de réception (partielle ou totale) d'une commande fournisseur.
 */
@Data
public class ReceptionRequest {

    @NotEmpty(message = "Au moins une ligne de réception est requise")
    private List<LigneReception> lignes;

    @Data
    public static class LigneReception {
        @NotNull(message = "L'ID ligne commande est requis")
        private Long ligneCommandeId;

        @NotNull(message = "La quantité reçue est requise")
        @DecimalMin(value = "0.01", message = "La quantité doit être > 0")
        private BigDecimal quantiteRecue;
    }
}
