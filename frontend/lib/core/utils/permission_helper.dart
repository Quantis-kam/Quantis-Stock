import '../network/api_client.dart';

class PermissionHelper {
  /// Retourne true si l'utilisateur connecté possède la permission demandée.
  /// Si l'utilisateur est ADMIN, il a toutes les permissions.
  static bool hasPermission(String permission) {
    if (ApiClient.isAdmin) return true;
    return ApiClient.userPermissions.contains(permission);
  }

  /// Retourne true si l'utilisateur possède l'une des permissions fournies.
  static bool hasAnyPermission(List<String> permissions) {
    if (ApiClient.isAdmin) return true;
    return permissions.any((perm) => ApiClient.userPermissions.contains(perm));
  }
}
