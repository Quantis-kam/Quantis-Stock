package com.quantis.stock.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ChangePasswordRequest {

    @NotBlank(message = "L'ancien mot de passe est requis")
    private String ancienMotDePasse;

    @NotBlank(message = "Le nouveau mot de passe est requis")
    @Size(min = 8, message = "Le nouveau mot de passe doit contenir au moins 8 caractères")
    private String nouveauMotDePasse;
}
