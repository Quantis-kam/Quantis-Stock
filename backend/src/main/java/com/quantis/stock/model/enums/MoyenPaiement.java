package com.quantis.stock.model.enums;

/**
 * Moyens de paiement supportés.
 */
public enum MoyenPaiement {
    ESPECES("Espèces"),
    WAVE("Wave"),
    ORANGE_MONEY("Orange Money"),
    MOOV_MONEY("Moov Money"),
    CARTE_BANCAIRE("Carte Bancaire"),
    CREDIT("À Crédit"),
    MOBILE_MONEY("Mobile Money"),
    VIREMENT("Virement"),
    CHEQUE("Chèque");

    private final String libelle;

    MoyenPaiement(String libelle) {
        this.libelle = libelle;
    }

    public String getLibelle() {
        return libelle;
    }
}
