package com.quantis.stock.dto;

import com.quantis.stock.model.Document;
import com.quantis.stock.model.Paiement;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * DTO de retour après validation d'une vente directe POS avec ticket imprimable.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PosSaleResponse {

    private Document document;
    private Paiement paiement;

    private BigDecimal montantTotal;
    private BigDecimal montantPaye;
    private BigDecimal montantRecu;
    private BigDecimal monnaieRendue;
    private BigDecimal soldeRestant;

    private String caissierNom;
    private String clientNom;

    // Métadonnées entreprise pour impression directe du ticket
    private String entrepriseNom;
    private String entrepriseNif;
    private String entrepriseRccm;
    private String entrepriseTelephone;
    private String entrepriseEmail;
    private String entrepriseAdresse;
    private String entrepriseLogoUrl;
    private String entrepriseMonnaie;
}
