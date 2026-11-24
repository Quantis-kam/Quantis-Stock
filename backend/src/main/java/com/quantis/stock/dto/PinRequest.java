package com.quantis.stock.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Requête de définition ou vérification du code PIN rapide à 4 chiffres rattaché au compte.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PinRequest {

    @NotBlank(message = "Le code PIN est obligatoire")
    @Pattern(regexp = "^\\d{4}$", message = "Le code PIN doit contenir exactement 4 chiffres")
    private String pin;
}

