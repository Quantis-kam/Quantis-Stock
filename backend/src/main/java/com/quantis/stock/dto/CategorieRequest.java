package com.quantis.stock.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CategorieRequest {

    @NotBlank(message = "Le nom est requis")
    @Size(max = 100)
    private String nom;

    private String description;
    private Long parentId;
}
