package com.quantis.stock.model.enums;

/**
 * Statuts des commandes fournisseur.
 * Cycle : BROUILLON → EN_COURS → RECUE_PARTIELLE → RECUE → ANNULEE
 */
public enum StatutCommande {
    BROUILLON,
    EN_COURS,
    RECUE_PARTIELLE,
    RECUE,
    ANNULEE
}

