package com.quantis.stock.dto;

import com.quantis.stock.model.enums.Permission;
import lombok.Data;

import java.util.List;
import java.util.Set;

/**
 * DTO pour la mise à jour des permissions granulaires d'un utilisateur.
 */
@Data
public class UserPermissionsRequest {

    /** Si true, on utilise les permissions personnalisées au lieu du rôle. */
    private Boolean permissionsCustom;

    /** Liste des permissions personnalisées. */
    private Set<Permission> permissions;

    /** IDs des dépôts autorisés. Si vide → accès à tous les dépôts. */
    private List<Long> depotsAutorises;
}
