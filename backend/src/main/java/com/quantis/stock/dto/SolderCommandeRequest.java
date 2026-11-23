package com.quantis.stock.dto;

import com.quantis.stock.model.enums.MoyenPaiement;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Requête atomique pour valider, déstocker, facturer et solder une commande client.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SolderCommandeRequest {

    @NotNull(message = "Le moyen de paiement est obligatoire")
    @Builder.Default
    private MoyenPaiement moyenPaiement = MoyenPaiement.ESPECES;

    /** Si null et moyenPaiement != CREDIT, considère la commande intégralement soldée (totalTtc). */
    private BigDecimal montantPaye;

    private BigDecimal montantRecu;
    private String reference;
    private String notes;
}

