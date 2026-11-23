package com.quantis.stock.dto;

import com.quantis.stock.model.enums.MoyenPaiement;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Requête de règlement de créance client (facture précise ou règlement global / acompte).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReglementClientRequest {

    @NotNull(message = "Le montant du règlement est obligatoire")
    @DecimalMin(value = "0.01", message = "Le montant doit être supérieur à 0")
    private BigDecimal montant;

    @NotNull(message = "Le moyen de paiement est obligatoire")
    @Builder.Default
    private MoyenPaiement moyen = MoyenPaiement.ESPECES;

    /** Optionnel : si renseigné, impute sur cette facture précise ; sinon imputation FIFO automatique. */
    private Long documentId;

    private LocalDate datePaiement;
    private String reference;
    private String notes;
}

