package com.quantis.stock.dto;

import com.quantis.stock.model.enums.Role;
import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class UserUpdateRequest {

    @NotBlank(message = "Le nom est requis")
    @Size(max = 100, message = "Le nom ne peut dépasser 100 caractères")
    private String nom;

    @NotBlank(message = "Le prénom est requis")
    @Size(max = 100, message = "Le prénom ne peut dépasser 100 caractères")
    private String prenom;

    @NotNull(message = "Le rôle est requis")
    private Role role;

    private Long depotId;

    @NotNull(message = "Le statut actif est requis")
    private Boolean actif;
}
