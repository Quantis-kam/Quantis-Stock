package com.quantis.stock.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EntrepriseRequest {

    @NotBlank(message = "Le nom de l'entreprise est obligatoire")
    private String nom;

    private String nif;
    private String rccm;
    private String telephone;
    private String email;
    private String adresse;
    private String logoUrl;

    @Builder.Default
    private String monnaie = "FCFA";

    @Builder.Default
    private String formatFacture = "FAC-{YYYY}-{NNNNN}";
}
