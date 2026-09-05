import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran de connexion — Phase 2 Flutter (Auth JWT).
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'admin@quantis.tech');
  final _passwordCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final response = await Dio(BaseOptions(
        baseUrl: 'http://localhost:8080/api/v1',
        connectTimeout: const Duration(seconds: 15),
      )).post('/auth/login', data: {
        'email': _emailCtrl.text.trim(),
        'motDePasse': _passwordCtrl.text,
      });

      final data = response.data['data'];
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final userMap = data['utilisateur'] as Map<String, dynamic>;

      // Persister les tokens
      try {
        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);
      } catch (e) {
        debugPrint('Notice secure storage write: $e');
      }

      // Configurer le client API
      ApiClient.setToken(accessToken);
      ApiClient.setRefreshToken(refreshToken);
      final permissionsList = (userMap['permissions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];

      try {
        await ApiClient.setUserInfo(
          userMap['role'] as String,
          '${userMap['prenom']} ${userMap['nom']}',
          userMap['email'] as String,
          permissionsList,
          entrepriseNom: userMap['entrepriseNom'] as String?,
          entrepriseMonnaie: userMap['entrepriseMonnaie'] as String?,
          formatFacture: userMap['formatFacture'] as String?,
          logoUrl: userMap['logoUrl'] as String?,
          entrepriseId: userMap['entrepriseId']?.toString(),
          isSuperAdmin: userMap['isSuperAdmin'] == true || userMap['role'] == 'SUPER_ADMIN',
        );
      } catch (e) {
        debugPrint('Notice setUserInfo: $e');
      }

      // Démarrer la sync (en arrière-plan, sans bloquer la navigation)
      try {
        SyncManager.instance.start();
      } catch (e) {
        debugPrint('Notice sync manager start: $e');
      }

      ApiClient.authStateNotifier.value = true;
      if (mounted && widget.onLoginSuccess != null) {
        try {
          widget.onLoginSuccess!();
        } catch (e) {
          debugPrint('Notice onLoginSuccess: $e');
        }
      }
    } on DioException catch (e) {
      dynamic resData = e.response?.data;
      if (resData is String) {
        try {
          resData = jsonDecode(resData);
        } catch (_) {}
      }
      if (e.response?.statusCode == 402 || (resData is Map && resData['error'] == 'LICENCE_EXPIREE')) {
        if (mounted) {
          setState(() {
            _error = null;
            _loading = false;
          });
          final mapData = resData is Map ? Map<String, dynamic>.from(resData) : <String, dynamic>{};
          _showLicenceRenewalModal(mapData);
        }
        return;
      }
      setState(() {
        if (e.response?.data != null && e.response?.data is Map && (e.response!.data as Map)['message'] != null) {
          _error = (e.response!.data as Map)['message'].toString();
        } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          _error = 'Email ou mot de passe incorrect';
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.connectionError) {
          _error = 'Impossible de joindre le serveur';
        } else {
          _error = 'Erreur de connexion: ${e.message}';
        }
      });
    } catch (e, stack) {
      debugPrint('Erreur login: $e\n$stack');
      setState(() {
        _error = 'Erreur: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLicenceRenewalModal(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LicenceRenewalDialog(
        data: data,
        onRetryLogin: () {
          Navigator.pop(ctx);
          _login();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo officiel Quantis
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: QuantisColors.royalBlue.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.asset(
                          'assets/images/quantis_emblem_circle.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Q', style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: QuantisColors.royalBlue,
                            )),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('QUANTIS-STOCK', style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: QuantisColors.royalBlue,
                  )),
                  Container(
                    width: 44,
                    height: 3,
                    margin: const EdgeInsets.only(top: 6, bottom: 8),
                    decoration: BoxDecoration(
                      color: QuantisColors.luxuryGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('Connexion à votre espace d\'entreprise',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: QuantisColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 28),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: QuantisColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: QuantisColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: QuantisColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: QuantisColors.error, fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty ? 'Email requis' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: (v) => v == null || v.isEmpty ? 'Mot de passe requis' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal de renouvellement d'abonnement / licence affiché en cas de fin de mois ou expiration
class _LicenceRenewalDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRetryLogin;

  const _LicenceRenewalDialog({
    required this.data,
    required this.onRetryLogin,
  });

  @override
  State<_LicenceRenewalDialog> createState() => _LicenceRenewalDialogState();
}

class _LicenceRenewalDialogState extends State<_LicenceRenewalDialog> {
  bool _copied = false;

  void _copyUssd(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Code USSD $code copié !'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.data['entrepriseNom'] ?? 'Votre Entreprise';
    final codeUssd = widget.data['codeUssd'] ?? '*144*2*1*65189261*20200#';
    final dateExp = widget.data['dateExpiration'] ?? 'Fin de mois';
    final montant = widget.data['montant'] != null
        ? '${(widget.data['montant'] as num).toStringAsFixed(0)} FCFA'
        : '20 200 FCFA';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Alerte Expiration
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Icon(Icons.lock_clock_rounded, size: 32, color: Colors.red.shade700),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LICENCE EXPIRÉE',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Échéance: $dateExp',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Abonnement Requis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SpaceGrotesk',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Message explicatif
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.4),
                  children: [
                    const TextSpan(text: 'L\'accès à l\'espace de '),
                    TextSpan(
                      text: '$nom ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: 'est temporairement suspendu pour cause d\'expiration de l\'abonnement mensuel. Veuillez effectuer le réabonnement de ',
                    ),
                    TextSpan(
                      text: '$montant ',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                    const TextSpan(text: 'pour réactiver vos services de gestion.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Cadre USSD Mis en Valeur
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7900),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ORANGE MONEY',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Paiement direct USSD',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      Text(
                        montant,
                        style: const TextStyle(
                          color: QuantisColors.luxuryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Code USSD
                  SelectableText(
                    codeUssd,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bouton copier
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.luxuryGold,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: Icon(_copied ? Icons.check : Icons.copy_rounded, size: 16),
                    label: Text(
                      _copied ? 'Code USSD Copié !' : 'Copier le Code USSD',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _copyUssd(codeUssd),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Instructions pas à pas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Procédure de réactivation :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  _buildStep('1', 'Composez le code USSD ci-dessus sur votre téléphone Orange.'),
                  _buildStep('2', 'Validez le montant de $montant avec votre code secret.'),
                  _buildStep('3', 'Le Super-Administrateur réactive immédiatement votre accès après confirmation.'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Boutons bas de modal
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Paiement fait ? Vérifier',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: widget.onRetryLogin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: QuantisColors.royalBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: QuantisColors.royalBlue),
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}
