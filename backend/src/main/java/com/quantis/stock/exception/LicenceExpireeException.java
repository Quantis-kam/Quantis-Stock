package com.quantis.stock.exception;

import lombok.Getter;

import java.time.LocalDate;

/**
 * Exception déclenchée lorsqu'un utilisateur tente d'accéder à son entreprise
 * dont la licence ou l'abonnement mensuel a expiré.
 */
@Getter
public class LicenceExpireeException extends RuntimeException {

    private final String entrepriseNom;
    private final LocalDate dateExpiration;
    private final String codeUssd;
    private final Double montant;

    public LicenceExpireeException(String entrepriseNom, LocalDate dateExpiration, String codeUssd, Double montant) {
        super("L'abonnement de l'entreprise " + entrepriseNom + " a expiré le " + (dateExpiration != null ? dateExpiration.toString() : "fin de mois") + ".");
        this.entrepriseNom = entrepriseNom;
        this.dateExpiration = dateExpiration;
        this.codeUssd = codeUssd != null ? codeUssd : "*144*2*1*65189261*20200#";
        this.montant = montant != null ? montant : 20200.0;
    }
}
