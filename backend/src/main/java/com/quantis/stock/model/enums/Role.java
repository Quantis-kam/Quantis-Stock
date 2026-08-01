package com.quantis.stock.model.enums;

/**
 * Rôles utilisateurs du système Quantis Stock.
 * Correspond à la matrice RBAC définie dans docs/roles_permissions.md
 */
public enum Role {
    ADMIN,
    GERANT,
    MAGASINIER,
    CAISSIER,
    COMPTABLE
}
