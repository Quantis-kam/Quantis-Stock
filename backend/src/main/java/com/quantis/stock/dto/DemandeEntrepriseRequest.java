package com.quantis.stock.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Requête publique de création d'entreprise envoyée depuis la page d'accueil Quantis-Stock.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DemandeEntrepriseRequest {

    @NotBlank(message = "Le nom de l'entreprise est obligatoire")
    private String nomEntreprise;

    private String secteurActivite;
    private String ville;

    @NotBlank(message = "Le nom du responsable est obligatoire")
    private String nomResponsable;

    @NotBlank(message = "Le numéro de téléphone / WhatsApp est obligatoire")
    private String telephone;

    @NotBlank(message = "L'adresse email est obligatoire")
    @Email(message = "Adresse email invalide")
    private String email;

    private String message;

    /** WHATSAPP, EMAIL ou FORMULAIRE */
    private String canalContact;
}

