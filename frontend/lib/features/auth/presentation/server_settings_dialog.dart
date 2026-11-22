import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/server_discovery_service.dart';
import '../../../core/theme/quantis_theme.dart';

/// Boîte de dialogue réutilisable (Login + Menu principal) pour détecter
/// automatiquement ou configurer manuellement l'adresse du serveur backend Quantis.
class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const ServerSettingsDialog(),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _controller;
  List<LocalNetworkInfo> _localInterfaces = [];
  bool _hasActiveVpn = false;
  bool _isTesting = false;
  bool _isScanning = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConstants.baseUrl);
    _loadLocalInterfaces();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLocalInterfaces() async {
    final interfaces = await ServerDiscoveryService.getLocalNetworks();
    if (!mounted) return;
    setState(() {
      _localInterfaces = interfaces.where((i) => i.isScannableLan).toList();
      _hasActiveVpn = interfaces.any((i) => i.isVpn);
    });
  }

  Future<void> _runTest([String? overrideUrl]) async {
    final normalized = ApiConstants.normalizeApiUrl(overrideUrl ?? _controller.text);
    _controller.text = normalized;
    setState(() {
      _isTesting = true;
      _statusMessage = 'Test de connexion vers $normalized...';
      _isSuccess = false;
    });

    final verified = await ServerDiscoveryService.verifyServer(
      normalized,
      timeout: const Duration(seconds: 4),
    );
    if (!mounted) return;

    if (verified != null) {
      await ApiClient.setCustomServerUrl(verified.apiUrl, markConnected: true);
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _isSuccess = true;
        _statusMessage =
            'Connecté au serveur (${verified.latencyMs} ms) : ${verified.apiUrl}';
      });
    } else {
      setState(() {
        _isTesting = false;
        _isSuccess = false;
        _statusMessage =
            'Serveur injoignable sur $normalized.\n'
            'Vérifiez que le backend est lancé sur le PC et que le pare-feu autorise le port 8080.';
      });
    }
  }

  Future<void> _runAutoScan() async {
    setState(() {
      _isScanning = true;
      _isSuccess = false;
      _statusMessage = 'Initialisation de la détection réseau...';
    });

    final priority = <String>[
      if (_controller.text.trim().isNotEmpty) _controller.text.trim(),
      ApiConstants.baseUrl,
      ...ApiClient.recentServerUrls,
    ];

    final result = await ServerDiscoveryService.discoverServer(
      priorityUrls: priority,
      onStatus: (msg) {
        if (!mounted) return;
        setState(() => _statusMessage = msg);
      },
    );

    if (!mounted) return;

    final found = result.server;
    setState(() {
      _localInterfaces = result.lanInterfaces;
      _hasActiveVpn = result.hasActiveVpn;
      _isScanning = false;
      if (found != null) {
        _controller.text = found.apiUrl;
        _isSuccess = true;
        final hostLabel =
            found.hostname != null ? ' (${found.hostname})' : '';
        _statusMessage =
            'Serveur détecté via ${found.sourceLabel}$hostLabel : ${found.apiUrl} (${found.latencyMs} ms)';
      } else {
        _isSuccess = false;
        final netHint = result.lanInterfaces.isEmpty
            ? 'Aucune interface Point d\'accès ou Wi-Fi détectée sur cet appareil.'
            : 'Sous-réseaux scannés : ${result.lanInterfaces.map((i) => "${i.subnetPrefix}.x").toSet().join(", ")}.';
        _statusMessage =
            'Serveur introuvable. $netHint\n'
            'Vérifiez que le backend tourne sur le PC, que le PC est connecté au Point d\'accès du téléphone, '
            'et que le pare-feu du PC autorise TCP 8080 & UDP 45808.';
      }
    });

    if (found != null) {
      await ApiClient.setCustomServerUrl(found.apiUrl, markConnected: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final recentUrls = ApiClient.recentServerUrls;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: 16,
      ),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: QuantisColors.royalBlue),
          SizedBox(width: 8),
          Expanded(
            child: Text('Connexion Serveur API', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détection automatique sur Wi-Fi et Point d\'accès mobile (UDP + scan dynamique du sous-réseau actif).',
                style: TextStyle(fontSize: 12.5, color: QuantisColors.textMuted),
              ),
              const SizedBox(height: 12),

              // Bouton principal d'auto-détection
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isScanning || _isTesting) ? null : _runAutoScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.radar, size: 18),
                  label: Text(
                    _isScanning
                        ? 'Recherche du PC en cours...'
                        : 'Auto-détecter le serveur PC',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuantisColors.royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Interfaces réseau locales détectées sur l'appareil
              if (!kIsWeb && _localInterfaces.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blueGrey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Réseaux détectés sur cet appareil :',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: QuantisColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final net in _localInterfaces)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Icon(
                                net.isHotspotLikely
                                    ? Icons.wifi_tethering
                                    : Icons.wifi,
                                size: 14,
                                color: net.isHotspotLikely
                                    ? Colors.orange.shade800
                                    : QuantisColors.royalBlue,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  net.displayLabel,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Alerte VPN actif (cause fréquente de blocage local sur Android)
              if (_hasActiveVpn) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_lock, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'VPN actif détecté : un VPN sur le téléphone peut bloquer l\'accès au PC local.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Saisie manuelle (accepte une simple IP ou une URL complète)
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Adresse IP ou URL de l\'API',
                  hintText: 'Ex: 10.84.192.225 ou http://...:8080/api/v1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    tooltip: 'Tester cette adresse',
                    onPressed: (_isTesting || _isScanning) ? null : () => _runTest(),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check, color: QuantisColors.royalBlue),
                  ),
                ),
                onSubmitted: (_) => _runTest(),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_isSuccess
                            ? Colors.green
                            : ((_isScanning || _isTesting) ? Colors.blue : Colors.red))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isScanning || _isTesting)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error_outline,
                          color: _isSuccess ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _isSuccess
                                ? Colors.green.shade900
                                : ((_isScanning || _isTesting)
                                    ? Colors.blue.shade900
                                    : Colors.red.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Text(
                'Raccourcis :',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: QuantisColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.cloud_done_outlined, size: 14, color: QuantisColors.royalBlue),
                    label: const Text('Cloud Quantis (quantisbf.com)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: QuantisColors.royalBlue.withValues(alpha: 0.1),
                    onPressed: () => _runTest(ApiConstants.cloudApiBaseUrl),
                  ),
                  for (final recent in recentUrls.where((u) => u != ApiConstants.cloudApiBaseUrl).take(3))
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 14, color: QuantisColors.royalBlue),
                      label: Text(
                        recent.replaceAll('http://', '').replaceAll('https://', '').replaceAll('/api/v1', ''),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => _runTest(recent),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.usb, size: 14, color: Colors.green),
                    label: const Text('Câble USB (127.0.0.1)', style: TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green.withValues(alpha: 0.08),
                    onPressed: () => _runTest('http://127.0.0.1:8080/api/v1'),
                  ),
                  if (!ApiConstants.isMobilePlatform)
                    ActionChip(
                      avatar: const Icon(Icons.computer, size: 14),
                      label: const Text('Localhost', style: TextStyle(fontSize: 11)),
                      onPressed: () => _runTest('http://localhost:8080/api/v1'),
                    ),
                  if (ApiConstants.isMobilePlatform)
                    ActionChip(
                      avatar: const Icon(Icons.phone_android, size: 14),
                      label: const Text('Émulateur (10.0.2.2)', style: TextStyle(fontSize: 11)),
                      onPressed: () => _runTest('http://10.0.2.2:8080/api/v1'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Fermer'),
        ),
        ElevatedButton(
          onPressed: (_isScanning || _isTesting)
              ? null
              : () async {
                  await ApiClient.setCustomServerUrl(_controller.text);
                  if (context.mounted) Navigator.of(context).pop(true);
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

