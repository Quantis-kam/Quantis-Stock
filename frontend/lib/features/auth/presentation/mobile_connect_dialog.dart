import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/quantis_theme.dart';

class _BackendInterfaceEntry {
  final String ip;
  final String interfaceName;
  final String type;
  final String? gateway;
  final bool isPrimary;

  const _BackendInterfaceEntry({
    required this.ip,
    required this.interfaceName,
    required this.type,
    this.gateway,
    this.isPrimary = false,
  });

  bool get isHotspot =>
      type == 'hotspot' ||
      type == 'usb_tethering' ||
      ip.startsWith('192.168.43.') ||
      ip.startsWith('172.20.10.') ||
      ip.startsWith('192.168.42.');

  String get chipLabel {
    final prefix = switch (type) {
      'hotspot' => '🔥 Point d\'accès',
      'usb_tethering' => '🔌 USB',
      'wifi' => '📶 Wi-Fi',
      'ethernet' => '🌐 Ethernet',
      _ => '📶 Réseau',
    };
    return interfaceName.isNotEmpty ? '$prefix ($interfaceName) · $ip' : '$prefix · $ip';
  }
}

/// Modal d'affichage des instructions et QR Code pour connecter un téléphone
/// via le Point d'accès mobile ou le réseau Wi-Fi local.
class MobileConnectDialog extends StatefulWidget {
  const MobileConnectDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const MobileConnectDialog(),
    );
  }

  @override
  State<MobileConnectDialog> createState() => _MobileConnectDialogState();
}

class _MobileConnectDialogState extends State<MobileConnectDialog> {
  bool _isLoading = true;
  bool _backendReachable = false;
  String _primaryIp = 'localhost';
  int _apiPort = ApiConstants.defaultApiPort;
  int _discoveryPort = ApiConstants.discoveryUdpPort;
  List<_BackendInterfaceEntry> _interfaces = [];
  String _webUrl = '';
  String _apiUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    setState(() {
      _isLoading = true;
    });

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));

    final endpointsToTry = [
      '${ApiConstants.baseUrl}/network/info',
      '${ApiConstants.baseUrl}/health',
      if (!ApiConstants.isMobilePlatform)
        'http://localhost:${ApiConstants.defaultApiPort}/api/v1/network/info',
    ];

    for (final endpoint in endpointsToTry) {
      try {
        final response = await dio.get(endpoint);
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data['data'] as Map<String, dynamic>? ?? {};
          final port = (data['port'] as num?)?.toInt() ?? ApiConstants.defaultApiPort;
          final discoveryPort =
              (data['discoveryPort'] as num?)?.toInt() ?? ApiConstants.discoveryUdpPort;

          final parsedIfaces = <_BackendInterfaceEntry>[];
          final rawIfaces = data['interfaces'];
          if (rawIfaces is List) {
            for (final item in rawIfaces) {
              if (item is Map) {
                final ip = item['ip']?.toString() ?? '';
                if (ip.isEmpty) continue;
                parsedIfaces.add(_BackendInterfaceEntry(
                  ip: ip,
                  interfaceName: item['interfaceName']?.toString() ?? '',
                  type: item['type']?.toString() ?? 'other',
                  gateway: item['gateway']?.toString(),
                  isPrimary: item['isPrimary'] == true,
                ));
              }
            }
          }

          if (parsedIfaces.isEmpty) {
            final ips = (data['localIps'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .where((e) => e.isNotEmpty)
                    .toList() ??
                [];
            for (final ip in ips) {
              parsedIfaces.add(_BackendInterfaceEntry(
                ip: ip,
                interfaceName: '',
                type: (ip.startsWith('192.168.43.') || ip.startsWith('172.20.10.'))
                    ? 'hotspot'
                    : 'wifi',
              ));
            }
          }

          final primary = data['primaryIp']?.toString() ??
              (parsedIfaces.isNotEmpty ? parsedIfaces.first.ip : 'localhost');

          if (!mounted) return;
          setState(() {
            _backendReachable = true;
            _apiPort = port;
            _discoveryPort = discoveryPort;
            _interfaces = parsedIfaces;
            _primaryIp = primary;
            _webUrl = 'http://$primary:3000';
            _apiUrl = 'http://$primary:$port/api/v1';
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}
    }

    // Repli uniquement si le backend ne répond pas localement
    final parsedBase = Uri.tryParse(ApiConstants.baseUrl);
    final host = (parsedBase != null && parsedBase.host.isNotEmpty)
        ? parsedBase.host
        : (Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost');
    if (!mounted) return;
    setState(() {
      _backendReachable = false;
      _primaryIp = host;
      _interfaces = [
        _BackendInterfaceEntry(ip: host, interfaceName: '', type: 'other'),
      ];
      _webUrl = 'http://$host:3000';
      _apiUrl = 'http://$host:$_apiPort/api/v1';
      _isLoading = false;
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié dans le presse-papiers !'),
        backgroundColor: QuantisColors.royalBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final selectedEntry = _interfaces.cast<_BackendInterfaceEntry?>().firstWhere(
          (e) => e?.ip == _primaryIp,
          orElse: () => null,
        );
    final isHotspot = selectedEntry?.isHotspot ??
        (_primaryIp.startsWith('192.168.43.') || _primaryIp.startsWith('172.20.10.'));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? screenWidth * 0.95 : 620),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: QuantisColors.royalBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi_tethering, color: QuantisColors.royalBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connexion Téléphone / Point d\'accès',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !_backendReachable
                              ? '⚠️ Backend local non joignable — vérifiez qu\'il est démarré'
                              : (isHotspot
                                  ? '🔥 Point d\'accès mobile détecté ($_primaryIp)'
                                  : '📶 Réseau local actif ($_primaryIp)'),
                          style: TextStyle(
                            fontSize: 12,
                            color: !_backendReachable
                                ? Colors.red.shade700
                                : (isHotspot ? Colors.orange.shade800 : Colors.green.shade800),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchNetworkInfo,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Rafraîchir les IP',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (_interfaces.length > 1) ...[
                  const Text(
                    'Interfaces réseau actives sur ce PC :',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _interfaces.map((iface) {
                      final isSelected = iface.ip == _primaryIp;
                      return ChoiceChip(
                        label: Text(iface.chipLabel, style: const TextStyle(fontSize: 11.5)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _primaryIp = iface.ip;
                              _webUrl = 'http://${iface.ip}:3000';
                              _apiUrl = 'http://${iface.ip}:$_apiPort/api/v1';
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Carte pour l'application Mobile Android (APK)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.android, color: Color(0xFF25D366), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Application Android (APK) — Auto-détection active :',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'L\'application mobile détecte ce PC automatiquement (balise UDP $_discoveryPort + scan du sous-réseau). '
                              'En cas de saisie manuelle, utilisez l\'URL API ci-dessous :',
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      _apiUrl,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFF1B5E20)),
                                    onPressed: () => _copyToClipboard(_apiUrl, 'URL API'),
                                    tooltip: 'Copier l\'URL API',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Carte d'accès Rapide Navigateur (Web) avec QR Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: QrImageView(
                          data: _webUrl,
                          version: QrVersions.auto,
                          size: isMobile ? 96 : 124,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.public, color: QuantisColors.royalBlue, size: 18),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Accès Navigateur Téléphone',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Scannez le QR Code ou ouvrez dans Chrome / Safari :',
                              style: TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      _webUrl,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: QuantisColors.royalBlue,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16, color: QuantisColors.royalBlue),
                                    onPressed: () => _copyToClipboard(_webUrl, 'Lien Web'),
                                    tooltip: 'Copier le lien',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Guide 3 étapes simples
                const Text(
                  '💡 Connexion via Point d\'accès mobile :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _buildStepItem('1', 'Activez le « Point d\'accès mobile » sur votre téléphone.'),
                _buildStepItem('2', 'Connectez ce PC au Wi-Fi du téléphone (le backend s\'adapte sans redémarrer).'),
                _buildStepItem('3', 'Ouvrez l\'app Quantis Stock sur le téléphone : le serveur est détecté automatiquement !'),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: QuantisColors.royalBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }
}
