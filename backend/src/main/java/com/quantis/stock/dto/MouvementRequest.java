package com.quantis.stock.dto;

import com.quantis.stock.model.enums.MotifMouvement;
import com.quantis.stock.model.enums.TypeMouvement;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class MouvementRequest {

    @NotNull(message = "Le type est requis")
    private TypeMouvement type;

    @NotNull(message = "Le motif est requis")
    private MotifMouvement motif;

    @NotNull(message = "L'ID produit est requis")
    private Long produitId;

    private Long varianteId;

    /** Requis pour SORTIE et TRANSFERT */
    private Long depotSourceId;

    /** Requis pour ENTREE et TRANSFERT */
    private Long depotDestId;

    @NotNull(message = "La quantité est requise")
    @DecimalMin(value = "0.01", message = "La quantité doit être > 0")
    private BigDecimal quantite;

    private String reference;
    private String commentaire;

    /** UUID pour idempotence sync offline (optionnel, auto-généré si absent) */
    private String uuidSync;
}
