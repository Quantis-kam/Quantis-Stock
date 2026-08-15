import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran de connexion — Phase 2 Flutter (Auth JWT).
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

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

      // Persister les tokens
      await _storage.write(key: 'access_token', value: accessToken);
      await _storage.write(key: 'refresh_token', value: refreshToken);

      // Configurer le client API
      ApiClient.setToken(accessToken);
      ApiClient.setRefreshToken(refreshToken);

      // Démarrer la sync
      SyncManager.instance.start();

      if (mounted) widget.onLoginSuccess();
    } on DioException catch (e) {
      setState(() {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          _error = 'Email ou mot de passe incorrect';
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.connectionError) {
          _error = 'Impossible de joindre le serveur';
        } else {
          _error = 'Erreur de connexion: ${e.message}';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: QuantisColors.royalBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text('Q', style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: QuantisColors.luxuryGold,
                      )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Quantis Stock', style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: QuantisColors.royalBlue,
                  )),
                  const SizedBox(height: 4),
                  Text('Connectez-vous pour continuer',
                      style: TextStyle(color: QuantisColors.textMuted)),
                  const SizedBox(height: 32),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: QuantisColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
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
                    height: 52,
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
