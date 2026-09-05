package com.quantis.stock.model.enums;

import java.util.Set;
import java.util.EnumSet;

/**
 * Rôles utilisateurs du système Quantis Stock.
 * Correspond à la matrice RBAC définie dans docs/roles_permissions.md
 */
public enum Role {
    SUPER_ADMIN(EnumSet.allOf(Permission.class)),

    ADMIN(EnumSet.allOf(Permission.class)),

    GERANT(EnumSet.of(
        Permission.VOIR_UTILISATEURS,
        Permission.CHANGER_MDP,
        Permission.CREER_MODIFIER_PRODUIT,
        Permission.VOIR_PRODUITS,
        Permission.GERER_CATEGORIES,
        Permission.IMPORT_EXPORTS,
        Permission.SCANNER_CODES,
        Permission.VOIR_STOCK,
        Permission.ENTREE_STOCK,
        Permission.SORTIE_STOCK,
        Permission.TRANSFERT_STOCK,
        Permission.INVENTAIRE_PHYSIQUE,
        Permission.HISTORIQUE_MOUVEMENTS,
        Permission.CRUD_CLIENTS,
        Permission.CRUD_FOURNISSEURS,
        Permission.VOIR_CREANCES,
        Permission.CREER_ACHAT,
        Permission.RECEPTIONNER_ACHAT,
        Permission.VOIR_ACHATS,
        Permission.CREER_VENTE,
        Permission.CONVERTIR_VENTE,
        Permission.ANNULER_VENTE,
        Permission.IMPRIMER_VENTE,
        Permission.PAIEMENT_CLIENT,
        Permission.PAIEMENT_FOURNISSEUR,
        Permission.CREER_AVOIR,
        Permission.RECEPTIONNER_RETOUR,
        Permission.JOURNAL_CAISSE,
        Permission.RAPPORTS_FINANCIERS,
        Permission.VOIR_DASHBOARD,
        Permission.VOIR_AUDIT
    )),

    MAGASINIER(EnumSet.of(
        Permission.CHANGER_MDP,
        Permission.VOIR_PRODUITS,
        Permission.SCANNER_CODES,
        Permission.VOIR_STOCK,
        Permission.ENTREE_STOCK,
        Permission.SORTIE_STOCK,
        Permission.TRANSFERT_STOCK,
        Permission.INVENTAIRE_PHYSIQUE,
        Permission.HISTORIQUE_MOUVEMENTS,
        Permission.RECEPTIONNER_ACHAT,
        Permission.VOIR_ACHATS,
        Permission.RECEPTIONNER_RETOUR
    )),

    CAISSIER(EnumSet.of(
        Permission.CHANGER_MDP,
        Permission.VOIR_PRODUITS,
        Permission.SCANNER_CODES,
        Permission.VOIR_STOCK,
        Permission.SORTIE_STOCK,
        Permission.HISTORIQUE_MOUVEMENTS,
        Permission.CRUD_CLIENTS,
        Permission.VOIR_CREANCES,
        Permission.CREER_VENTE,
        Permission.CONVERTIR_VENTE,
        Permission.IMPRIMER_VENTE,
        Permission.PAIEMENT_CLIENT,
        Permission.JOURNAL_CAISSE
    )),

    COMPTABLE(EnumSet.of(
        Permission.CHANGER_MDP,
        Permission.VOIR_PRODUITS,
        Permission.VOIR_STOCK,
        Permission.HISTORIQUE_MOUVEMENTS,
        Permission.VOIR_CREANCES,
        Permission.VOIR_ACHATS,
        Permission.IMPRIMER_VENTE,
        Permission.JOURNAL_CAISSE,
        Permission.RAPPORTS_FINANCIERS,
        Permission.VOIR_DASHBOARD,
        Permission.EXPORT_COMPTABLE,
        Permission.VOIR_AUDIT
    ));

    private final Set<Permission> permissions;

    Role(Set<Permission> permissions) {
        this.permissions = permissions;
    }

    public Set<Permission> getPermissions() {
        return permissions;
    }
}
