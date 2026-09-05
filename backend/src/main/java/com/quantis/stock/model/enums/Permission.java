package com.quantis.stock.model.enums;

/**
 * Énumération des permissions fines du système correspondant à la matrice RBAC.
 */
public enum Permission {
    // Utilisateurs
    CRUD_UTILISATEURS,
    VOIR_UTILISATEURS,
    CHANGER_MDP,

    // Catalogue produits
    CREER_MODIFIER_PRODUIT,
    VOIR_PRODUITS,
    SUPPRIMER_PRODUIT,
    GERER_CATEGORIES,
    IMPORT_EXPORTS,
    SCANNER_CODES,

    // Stocks
    VOIR_STOCK,
    ENTREE_STOCK,
    SORTIE_STOCK,
    TRANSFERT_STOCK,
    INVENTAIRE_PHYSIQUE,
    FORCE_SORTIE,
    HISTORIQUE_MOUVEMENTS,

    // Tiers
    CRUD_CLIENTS,
    CRUD_FOURNISSEURS,
    VOIR_CREANCES,

    // Achats
    CREER_ACHAT,
    RECEPTIONNER_ACHAT,
    VOIR_ACHATS,

    // Ventes
    CREER_VENTE,
    CONVERTIR_VENTE,
    ANNULER_VENTE,
    IMPRIMER_VENTE,

    // Paiements
    PAIEMENT_CLIENT,
    PAIEMENT_FOURNISSEUR,
    CREER_AVOIR,
    RECEPTIONNER_RETOUR,

    // Comptabilité & Rapports
    JOURNAL_CAISSE,
    RAPPORTS_FINANCIERS,
    VOIR_DASHBOARD,
    EXPORT_COMPTABLE,

    // Système & Audit
    VOIR_AUDIT,
    CONFIG_SYSTEME
}
