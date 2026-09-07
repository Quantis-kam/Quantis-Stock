package com.quantis.stock.controller;

import com.quantis.stock.dto.*;
import com.quantis.stock.exception.BusinessException;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Depot;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.model.enums.Permission;
import com.quantis.stock.repository.DepotRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.security.SecurityUtils;
import org.springframework.data.domain.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import com.quantis.stock.service.AuditService;

import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UtilisateurController {

    private final UtilisateurRepository utilisateurRepository;
    private final DepotRepository depotRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;
    private final SecurityUtils securityUtils;

    @GetMapping
    @PreAuthorize("hasAuthority('VOIR_UTILISATEURS')")
    public ResponseEntity<ApiResponse<PagedResponse<Utilisateur>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100), Sort.by("id").ascending());
        Page<Utilisateur> result;
        if (securityUtils.isSuperAdmin()) {
            result = utilisateurRepository.findAll(pageable);
        } else {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            Utilisateur currentUser = securityUtils.getCurrentUser().orElse(null);
            if (currentUser != null && currentUser.getRole() != Role.ADMIN && currentUser.getDepot() != null) {
                result = utilisateurRepository.findByDepotIdAndRoleNot(currentUser.getDepot().getId(), Role.SUPER_ADMIN, pageable);
            } else if (currentEntrepriseId != null) {
                result = utilisateurRepository.findByEntrepriseIdAndRoleNot(currentEntrepriseId, Role.SUPER_ADMIN, pageable);
            } else {
                result = Page.empty();
            }
        }
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('VOIR_UTILISATEURS')")
    public ResponseEntity<ApiResponse<Utilisateur>> findById(
            @PathVariable Long id,
            Authentication auth) {
        Utilisateur user = utilisateurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "id", id));
        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (user.getRole() == Role.SUPER_ADMIN ||
                user.getEntreprise() == null ||
                !user.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Vous n'êtes pas autorisé à voir cet utilisateur");
            }
            Utilisateur currentUser = securityUtils.getCurrentUser().orElse(null);
            if (currentUser != null && currentUser.getRole() != Role.ADMIN && currentUser.getDepot() != null) {
                if (user.getDepot() == null || !currentUser.getDepot().getId().equals(user.getDepot().getId())) {
                    throw new BusinessException("Vous n'êtes pas autorisé à voir cet utilisateur");
                }
            }
        }
        return ResponseEntity.ok(ApiResponse.success(user));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('CRUD_UTILISATEURS')")
    public ResponseEntity<ApiResponse<Utilisateur>> update(
            @PathVariable Long id,
            @Valid @RequestBody UserUpdateRequest request) {
        Utilisateur user = utilisateurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "id", id));

        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (user.getRole() == Role.SUPER_ADMIN ||
                user.getEntreprise() == null ||
                !user.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Vous n'êtes pas autorisé à modifier cet utilisateur");
            }
            if (request.getRole() == Role.SUPER_ADMIN) {
                throw new BusinessException("Vous ne pouvez pas attribuer le rôle SuperAdmin");
            }
        }

        Depot depot = null;
        if (request.getDepotId() != null) {
            depot = depotRepository.findById(request.getDepotId())
                    .orElseThrow(() -> new ResourceNotFoundException("Dépôt", "id", request.getDepotId()));
            if (!securityUtils.isSuperAdmin() && user.getEntreprise() != null) {
                if (depot.getEntreprise() == null || !depot.getEntreprise().getId().equals(user.getEntreprise().getId())) {
                    throw new BusinessException("Ce dépôt n'appartient pas à votre entreprise");
                }
            }
        }

        user.setNom(request.getNom());
        user.setPrenom(request.getPrenom());
        user.setRole(request.getRole());
        user.setDepot(depot);
        user.setActif(request.getActif());

        Utilisateur updated = utilisateurRepository.save(user);
        auditService.logAction("UPDATE", "Utilisateur", updated.getId(), "Modification utilisateur " + updated.getEmail());
        return ResponseEntity.ok(ApiResponse.success("Utilisateur mis à jour", updated));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('CRUD_UTILISATEURS')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        Utilisateur user = utilisateurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "id", id));
        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (user.getRole() == Role.SUPER_ADMIN ||
                user.getEntreprise() == null ||
                !user.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Vous n'êtes pas autorisé à désactiver cet utilisateur");
            }
        }
        user.setActif(false);
        utilisateurRepository.save(user);
        auditService.logAction("DELETE", "Utilisateur", user.getId(), "Désactivation utilisateur " + user.getEmail());
        return ResponseEntity.ok(ApiResponse.success("Utilisateur désactivé", null));
    }

    @PostMapping("/change-password")
    @PreAuthorize("hasAuthority('CHANGER_MDP')")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            Authentication auth) {
        String email = auth.getName();
        Utilisateur user = utilisateurRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "email", email));

        if (!passwordEncoder.matches(request.getAncienMotDePasse(), user.getMotDePasseHash())) {
            throw new BusinessException("L'ancien mot de passe est incorrect");
        }

        user.setMotDePasseHash(passwordEncoder.encode(request.getNouveauMotDePasse()));
        utilisateurRepository.save(user);
        auditService.logAction("PASSWORD_CHANGE", "Utilisateur", user.getId(), "Modification mot de passe pour " + user.getEmail());

        return ResponseEntity.ok(ApiResponse.success("Mot de passe modifié avec succès", null));
    }

    // =================== PERMISSIONS GRANULAIRES ===================

    /**
     * GET /users/{id}/permissions — Récupérer les permissions d'un utilisateur.
     */
    @GetMapping("/{id}/permissions")
    @PreAuthorize("hasAuthority('CRUD_UTILISATEURS')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getPermissions(@PathVariable Long id) {
        Utilisateur user = utilisateurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "id", id));

        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (user.getRole() == Role.SUPER_ADMIN ||
                user.getEntreprise() == null ||
                !user.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Vous n'êtes pas autorisé à gérer les permissions de cet utilisateur");
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("userId", user.getId());
        result.put("role", user.getRole().name());
        result.put("permissionsCustom", Boolean.TRUE.equals(user.getPermissionsCustom()));
        result.put("permissionsRole", user.getRole().getPermissions().stream()
                .map(Enum::name).sorted().collect(Collectors.toList()));
        result.put("permissionsPersonnalisees", user.getPermissionsPersonnalisees().stream()
                .map(Enum::name).sorted().collect(Collectors.toList()));
        result.put("permissionsEffectives", user.getPermissionsEffectives().stream()
                .map(Enum::name).sorted().collect(Collectors.toList()));
        result.put("depotsAutorises", user.getDepotsAutorises().stream()
                .map(d -> Map.of("id", d.getId(), "nom", d.getNom()))
                .collect(Collectors.toList()));

        return ResponseEntity.ok(ApiResponse.success(result));
    }

    /**
     * PUT /users/{id}/permissions — Mettre à jour les permissions d'un utilisateur.
     */
    @PutMapping("/{id}/permissions")
    @PreAuthorize("hasAuthority('CRUD_UTILISATEURS')")
    public ResponseEntity<ApiResponse<Void>> updatePermissions(
            @PathVariable Long id,
            @RequestBody UserPermissionsRequest request) {
        Utilisateur user = utilisateurRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur", "id", id));

        if (!securityUtils.isSuperAdmin()) {
            Long currentEntrepriseId = securityUtils.getCurrentEntrepriseId();
            if (user.getRole() == Role.SUPER_ADMIN ||
                user.getEntreprise() == null ||
                !user.getEntreprise().getId().equals(currentEntrepriseId)) {
                throw new BusinessException("Vous n'êtes pas autorisé à modifier les permissions de cet utilisateur");
            }
        }

        // Mettre à jour le flag custom
        user.setPermissionsCustom(request.getPermissionsCustom() != null && request.getPermissionsCustom());

        // Mettre à jour les permissions
        if (request.getPermissions() != null) {
            user.getPermissionsPersonnalisees().clear();
            user.getPermissionsPersonnalisees().addAll(request.getPermissions());
        }

        // Mettre à jour les dépôts autorisés
        if (request.getDepotsAutorises() != null) {
            user.getDepotsAutorises().clear();
            if (!request.getDepotsAutorises().isEmpty()) {
                List<Depot> depots = depotRepository.findAllById(request.getDepotsAutorises());
                user.getDepotsAutorises().addAll(new HashSet<>(depots));
            }
        }

        utilisateurRepository.save(user);
        auditService.logAction("UPDATE_PERMISSIONS", "Utilisateur", user.getId(),
                "Mise à jour permissions pour " + user.getEmail() +
                " (custom=" + user.getPermissionsCustom() +
                ", perms=" + user.getPermissionsPersonnalisees().size() +
                ", depots=" + user.getDepotsAutorises().size() + ")");

        return ResponseEntity.ok(ApiResponse.success("Permissions mises à jour", null));
    }

    /**
     * GET /users/permissions/catalog — Catalogue de toutes les permissions groupées.
     */
    @GetMapping("/permissions/catalog")
    @PreAuthorize("hasAuthority('CRUD_UTILISATEURS')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getPermissionsCatalog() {
        List<Map<String, Object>> groups = new ArrayList<>();

        groups.add(buildGroup("Catalogue Produits", "🛍️", List.of(
                Permission.CREER_MODIFIER_PRODUIT, Permission.VOIR_PRODUITS,
                Permission.SUPPRIMER_PRODUIT, Permission.GERER_CATEGORIES,
                Permission.IMPORT_EXPORTS, Permission.SCANNER_CODES)));

        groups.add(buildGroup("Gestion de Stock", "📦", List.of(
                Permission.VOIR_STOCK, Permission.ENTREE_STOCK,
                Permission.SORTIE_STOCK, Permission.TRANSFERT_STOCK,
                Permission.INVENTAIRE_PHYSIQUE, Permission.FORCE_SORTIE,
                Permission.HISTORIQUE_MOUVEMENTS)));

        groups.add(buildGroup("Tiers (Clients/Fournisseurs)", "👥", List.of(
                Permission.CRUD_CLIENTS, Permission.CRUD_FOURNISSEURS,
                Permission.VOIR_CREANCES)));

        groups.add(buildGroup("Achats", "🛒", List.of(
                Permission.CREER_ACHAT, Permission.RECEPTIONNER_ACHAT,
                Permission.VOIR_ACHATS)));

        groups.add(buildGroup("Ventes & Documents", "💰", List.of(
                Permission.CREER_VENTE, Permission.CONVERTIR_VENTE,
                Permission.ANNULER_VENTE, Permission.IMPRIMER_VENTE)));

        groups.add(buildGroup("Paiements", "💳", List.of(
                Permission.PAIEMENT_CLIENT, Permission.PAIEMENT_FOURNISSEUR,
                Permission.CREER_AVOIR, Permission.RECEPTIONNER_RETOUR)));

        groups.add(buildGroup("Comptabilité & Rapports", "📊", List.of(
                Permission.JOURNAL_CAISSE, Permission.RAPPORTS_FINANCIERS,
                Permission.VOIR_DASHBOARD, Permission.EXPORT_COMPTABLE)));

        groups.add(buildGroup("Système & Administration", "⚙️", List.of(
                Permission.CRUD_UTILISATEURS, Permission.VOIR_UTILISATEURS,
                Permission.CHANGER_MDP, Permission.VOIR_AUDIT,
                Permission.CONFIG_SYSTEME)));

        return ResponseEntity.ok(ApiResponse.success(groups));
    }

    private Map<String, Object> buildGroup(String label, String icon, List<Permission> perms) {
        Map<String, Object> group = new LinkedHashMap<>();
        group.put("label", label);
        group.put("icon", icon);
        group.put("permissions", perms.stream().map(p -> Map.of(
                "code", p.name(),
                "label", formatPermissionLabel(p.name())
        )).collect(Collectors.toList()));
        return group;
    }

    private String formatPermissionLabel(String code) {
        return switch (code) {
            case "CRUD_UTILISATEURS" -> "Gérer les utilisateurs";
            case "VOIR_UTILISATEURS" -> "Voir les utilisateurs";
            case "CHANGER_MDP" -> "Changer son mot de passe";
            case "CREER_MODIFIER_PRODUIT" -> "Créer / modifier produits";
            case "VOIR_PRODUITS" -> "Voir les produits";
            case "SUPPRIMER_PRODUIT" -> "Supprimer un produit";
            case "GERER_CATEGORIES" -> "Gérer les catégories";
            case "IMPORT_EXPORTS" -> "Import / Export";
            case "SCANNER_CODES" -> "Scanner codes-barres";
            case "VOIR_STOCK" -> "Voir le stock";
            case "ENTREE_STOCK" -> "Entrée de stock";
            case "SORTIE_STOCK" -> "Sortie de stock";
            case "TRANSFERT_STOCK" -> "Transfert inter-dépôt";
            case "INVENTAIRE_PHYSIQUE" -> "Inventaire physique";
            case "FORCE_SORTIE" -> "Forcer sortie (stock négatif)";
            case "HISTORIQUE_MOUVEMENTS" -> "Historique mouvements";
            case "CRUD_CLIENTS" -> "Gérer les clients";
            case "CRUD_FOURNISSEURS" -> "Gérer les fournisseurs";
            case "VOIR_CREANCES" -> "Voir les créances";
            case "CREER_ACHAT" -> "Créer un achat";
            case "RECEPTIONNER_ACHAT" -> "Réceptionner un achat";
            case "VOIR_ACHATS" -> "Voir les achats";
            case "CREER_VENTE" -> "Créer une vente";
            case "CONVERTIR_VENTE" -> "Convertir un document";
            case "ANNULER_VENTE" -> "Annuler une vente";
            case "IMPRIMER_VENTE" -> "Imprimer / PDF";
            case "PAIEMENT_CLIENT" -> "Paiement client";
            case "PAIEMENT_FOURNISSEUR" -> "Paiement fournisseur";
            case "CREER_AVOIR" -> "Créer un avoir";
            case "RECEPTIONNER_RETOUR" -> "Réceptionner un retour";
            case "JOURNAL_CAISSE" -> "Journal de caisse";
            case "RAPPORTS_FINANCIERS" -> "Rapports financiers";
            case "VOIR_DASHBOARD" -> "Tableau de bord";
            case "EXPORT_COMPTABLE" -> "Export comptable";
            case "VOIR_AUDIT" -> "Voir les logs d'audit";
            case "CONFIG_SYSTEME" -> "Configuration système";
            default -> code.replace("_", " ").toLowerCase();
        };
    }

    private <T> PagedResponse<T> toPagedResponse(Page<T> page) {
        return PagedResponse.<T>builder()
                .content(page.getContent())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .first(page.isFirst())
                .build();
    }
}
