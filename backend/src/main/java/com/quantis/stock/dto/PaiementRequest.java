package com.quantis.stock.dto;

import com.quantis.stock.model.enums.MoyenPaiement;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class PaiementRequest {

    @NotNull(message = "L'ID document est requis")
    private Long documentId;

    @NotNull(message = "Le montant est requis")
    @DecimalMin(value = "0.01", message = "Le montant doit être > 0")
    private BigDecimal montant;

    @NotNull(message = "Le moyen de paiement est requis")
    private MoyenPaiement moyen;

    private LocalDate datePaiement;
    private String reference;
    private String uuidSync;
}
