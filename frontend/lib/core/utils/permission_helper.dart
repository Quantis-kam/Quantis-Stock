import '../network/api_client.dart';

class PermissionHelper {
  /// Retourne true si l'utilisateur connecté possède la permission demandée.
  /// Si l'utilisateur est ADMIN ou SUPER_ADMIN, il a toutes les permissions.
  static bool hasPermission(String permission) {
    if (ApiClient.isAdmin) return true;
    return ApiClient.userPermissions.contains(permission);
  }

  /// Retourne true si l'utilisateur possède au moins une des permissions fournies.
  static bool hasAnyPermission(List<String> permissions) {
    if (ApiClient.isAdmin) return true;
    return permissions.any((perm) => ApiClient.userPermissions.contains(perm));
  }

  // =================== ACCÈS PAR MODULE / ESPACE ===================

  /// Accès au Tableau de bord & Rapports
  static bool get canViewDashboard =>
      hasAnyPermission(['VOIR_DASHBOARD', 'RAPPORTS_FINANCIERS']);

  /// Accès à la Caisse POS
  static bool get canAccessPos =>
      hasAnyPermission(['CREER_VENTE', 'PAIEMENT_CLIENT']);

  /// Accès aux Factures, Devis & Documents commerciaux
  static bool get canAccessDocuments =>
      hasAnyPermission(['CREER_VENTE', 'CONVERTIR_VENTE', 'ANNULER_VENTE', 'IMPRIMER_VENTE', 'PAIEMENT_CLIENT']);

  /// Accès à la gestion du Stock
  static bool get canAccessStock =>
      hasAnyPermission([
        'VOIR_STOCK',
        'ENTREE_STOCK',
        'SORTIE_STOCK',
        'TRANSFERT_STOCK',
        'INVENTAIRE_PHYSIQUE',
        'HISTORIQUE_MOUVEMENTS',
        'FORCE_SORTIE'
      ]);

  /// Accès aux Arrêts de stock (Snapshots de valorisation)
  static bool get canAccessArretStock =>
      hasPermission('INVENTAIRE_PHYSIQUE');

  /// Accès au Catalogue Articles & Produits
  static bool get canAccessProduits =>
      hasAnyPermission(['VOIR_PRODUITS', 'CREER_MODIFIER_PRODUIT', 'GERER_CATEGORIES', 'SCANNER_CODES', 'IMPORT_EXPORTS']);

  /// Accès aux Fiches Clients
  static bool get canAccessClients =>
      hasAnyPermission(['CRUD_CLIENTS', 'VOIR_CREANCES']);

  /// Accès aux Débiteurs & Créances
  static bool get canAccessDebiteurs =>
      hasAnyPermission(['VOIR_CREANCES', 'CRUD_CLIENTS', 'PAIEMENT_CLIENT']);

  /// Accès aux Fournisseurs
  static bool get canAccessFournisseurs =>
      hasAnyPermission(['CRUD_FOURNISSEURS', 'VOIR_ACHATS']);

  /// Accès aux Commandes Achats
  static bool get canAccessAchats =>
      hasAnyPermission(['VOIR_ACHATS', 'CREER_ACHAT', 'RECEPTIONNER_ACHAT']);

  /// Accès à la Caisse & Comptabilité
  static bool get canAccessComptabilite =>
      ApiClient.isAdmin || hasAnyPermission(['JOURNAL_CAISSE', 'RAPPORTS_FINANCIERS', 'EXPORT_COMPTABLE', 'CREER_VENTE', 'PAIEMENT_CLIENT']);

  /// Accès aux Exports Compta & Fiscaux
  static bool get canAccessExports =>
      ApiClient.isAdmin || hasAnyPermission(['EXPORT_COMPTABLE', 'JOURNAL_CAISSE', 'VOIR_DASHBOARD']);

  /// Accès aux Paramètres Entreprise & Facturation
  static bool get canAccessEntreprise =>
      ApiClient.isAdmin || hasPermission('CONFIG_SYSTEME');

  /// Accès à la gestion des Utilisateurs & Droits
  static bool get canAccessUsers =>
      ApiClient.isAdmin || hasAnyPermission(['CRUD_UTILISATEURS', 'VOIR_UTILISATEURS']);

  /// Accès aux Logs d'Audit et Sécurité
  static bool get canAccessAudit =>
      ApiClient.isAdmin || hasPermission('VOIR_AUDIT');

  /// Accès à l'assistant Quantis IA
  static bool get canAccessAi =>
      ApiClient.isAdmin || hasAnyPermission(['CONFIG_SYSTEME', 'VOIR_DASHBOARD']);
}
