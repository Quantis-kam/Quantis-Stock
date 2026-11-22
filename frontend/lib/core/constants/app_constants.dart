import 'package:flutter/foundation.dart';

/// Constantes de l'API backend.
class ApiConstants {
  ApiConstants._();

  static const int defaultApiPort = 8080;
  static const int discoveryUdpPort = 45808;
  static const String discoveryMagic = 'QUANTIS_DISCOVER';

  /// URL Cloud officielle de production (Render + Cloudflare quantisbf.com).
  static const String cloudApiBaseUrl = 'https://api-stock.quantisbf.com/api/v1';

  /// Surcharge optionnelle à la compilation via `--dart-define=API_BASE_URL=...`
  static const String _compiledApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Vrai si l'application s'exécute sur Android ou iOS natif.
  static bool get isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Vrai si l'URL courante pointe vers un serveur Cloud HTTPS (hors LAN local).
  static bool get isCloudUrl => baseUrl.toLowerCase().startsWith('https://');

  /// URL de base de l'API par défaut selon la plateforme et l'environnement.
  static String get defaultBaseUrl {
    if (_compiledApiBaseUrl.isNotEmpty) {
      return normalizeApiUrl(_compiledApiBaseUrl);
    }
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host == 'stock.quantisbf.com' ||
          host.endsWith('.quantisbf.com') ||
          host.endsWith('.pages.dev')) {
        return cloudApiBaseUrl;
      }
      if (Uri.base.scheme == 'https' && host.isNotEmpty) {
        return '${Uri.base.origin}/api/v1';
      }
      final devHost = host.isNotEmpty ? host : 'localhost';
      return 'http://$devHost:$defaultApiPort/api/v1';
    }
    if (!isMobilePlatform) {
      return 'http://localhost:$defaultApiPort/api/v1';
    }
    // Sur mobile (APK distribué aux commerçants), pointe par défaut sur le Cloud Quantis.
    return cloudApiBaseUrl;
  }

  /// Raccourcis techniques (Cloud + modes locaux).
  static const List<String> serverPresets = [
    cloudApiBaseUrl,                // Serveur Cloud Quantis
    'http://127.0.0.1:8080/api/v1', // Câble USB (ADB reverse)
    'http://10.0.2.2:8080/api/v1',  // Émulateur Android
    'http://localhost:8080/api/v1', // Local (PC)
  ];

  /// Normalise une saisie utilisateur (IP nue, IP:port ou URL complète) en URL API `/api/v1`.
  static String normalizeApiUrl(String raw) {
    String clean = raw.trim();
    if (clean.isEmpty) return defaultBaseUrl;

    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }

    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    final parsed = Uri.tryParse(clean);
    if (parsed != null && parsed.host.isNotEmpty) {
      final isIpOrLocal = _looksLikeIpv4(parsed.host) || parsed.host == 'localhost';
      final needsDefaultPort = !parsed.hasPort && parsed.scheme == 'http' && isIpOrLocal;
      final port = needsDefaultPort ? defaultApiPort : (parsed.hasPort ? parsed.port : null);
      String path = parsed.path;
      while (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      if (!path.endsWith('/api/v1')) {
        path = '$path/api/v1';
      }
      final portPart = port != null ? ':$port' : '';
      return '${parsed.scheme}://${parsed.host}$portPart$path';
    }

    if (!clean.endsWith('/api/v1')) {
      clean = '$clean/api/v1';
    }
    return clean;
  }

  static bool _looksLikeIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static String baseUrl = defaultBaseUrl;

  /// Timeout en secondes (tolérant au réveil à froid Cloud Free Tier)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 45;

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

  /// Active l'accès au module Quantis AI (réservé aux abonnements Premium).
  /// Quand `false`, tous les points d'entrée IA affichent l'offre Premium
  /// et aucune écoute micro / reconnaissance vocale n'est initialisée.
  static const bool isQuantisAiPremiumEnabled = false;

  /// Contact commercial Quantis pour les passages en offre Premium.
  static const String supportWhatsAppPhone = '22665189261';
  static const String supportPhoneDisplay = '+226 65 18 92 61';

  /// Expiration automatique de session après inactivité (app ouverte, en arrière-plan ou fermée).
  static const Duration sessionInactivityTimeout = Duration(minutes: 30);

  /// Seuil avant expiration du JWT d'accès pour rafraîchir silencieusement tant que l'utilisateur est actif.
  static const Duration proactiveRefreshThreshold = Duration(minutes: 2);
}
