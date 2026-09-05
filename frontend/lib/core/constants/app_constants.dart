/// Constantes de l'API backend.
class ApiConstants {
  ApiConstants._();

  /// URL de base de l'API (dev)
  static const String baseUrl = 'http://localhost:8080/api/v1';

  /// Timeout en secondes
  static const int connectTimeout = 15;
  static const int receiveTimeout = 30;

  // Endpoints
  static const String auth = '/auth';
  static const String login = '$auth/login';
  static const String refresh = '$auth/refresh';
  static const String health = '/health';

  static const String users = '/users';
  static const String products = '/products';
  static const String categories = '/categories';
  static const String depots = '/depots';
  static const String stock = '/stock';
  static const String movements = '/movements';
  static const String clients = '/clients';
  static const String suppliers = '/suppliers';
  static const String documents = '/documents';
  static const String invoices = '/invoices';
  static const String payments = '/payments';
  static const String reports = '/reports';
  static const String sync = '/sync';
}

/// Constantes métier.
class AppConstants {
  AppConstants._();

  static const String appName = 'Quantis-Stock';
  static const String devise = 'FCFA';
  static const double tvaDefault = 18.0;
  static const int seuilAlerteDefault = 10;
  static const int pageSize = 20;
}
