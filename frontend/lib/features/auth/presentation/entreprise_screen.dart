import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran de gestion du profil d'entreprise et upload de logo (Phase 1).
class EntrepriseScreen extends StatefulWidget {
  const EntrepriseScreen({super.key});

  @override
  State<EntrepriseScreen> createState() => _EntrepriseScreenState();
}

class _EntrepriseScreenState extends State<EntrepriseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _rccmCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _monnaieCtrl = TextEditingController(text: 'FCFA');
  final _formatFactureCtrl = TextEditingController(text: 'FAC-{YYYY}-{NNNNN}');

  String? _logoBase64;
  Uint8List? _logoBytes;
  String? _logoFileName;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntreprise();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _nifCtrl.dispose();
    _rccmCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _monnaieCtrl.dispose();
    _formatFactureCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEntreprise() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ApiClient.instance;
      final response = await dio.get('/entreprise');
      final data = response.data['data'] as Map<String, dynamic>;

      if (mounted) {
        final logo = data['logoUrl'] as String?;
        Uint8List? bytes;
        if (logo != null && logo.startsWith('data:image')) {
          try {
            bytes = base64Decode(logo.split(',').last);
          } catch (_) {}
        }

        setState(() {
          _nomCtrl.text = data['nom'] ?? '';
          _nifCtrl.text = data['nif'] ?? '';
          _rccmCtrl.text = data['rccm'] ?? '';
          _telephoneCtrl.text = data['telephone'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _adresseCtrl.text = data['adresse'] ?? '';
          _monnaieCtrl.text = data['monnaie'] ?? 'FCFA';
          _formatFactureCtrl.text = data['formatFacture'] ?? 'FAC-{YYYY}-{NNNNN}';
          _logoBase64 = logo;
          _logoBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger les données: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final ext = file.extension ?? 'png';
          final base64String = 'data:image/$ext;base64,${base64Encode(bytes)}';
          setState(() {
            _logoBytes = bytes;
            _logoBase64 = base64String;
            _logoFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection du fichier: $e'),
            backgroundColor: QuantisColors.error,
          ),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBytes = null;
      _logoBase64 = null;
      _logoFileName = null;
    });
  }

  Future<void> _saveEntreprise() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      final dio = ApiClient.instance;
      final body = {
        'nom': _nomCtrl.text.trim(),
        'nif': _nifCtrl.text.trim(),
        'rccm': _rccmCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'adresse': _adresseCtrl.text.trim(),
        'logoUrl': _logoBase64,
        'monnaie': _monnaieCtrl.text.trim(),
        'formatFacture': _formatFactureCtrl.text.trim(),
      };

      await dio.put('/entreprise', data: body);

      // Mettre à jour le cache local
      await ApiClient.updateEntrepriseInfo(
        nom: _nomCtrl.text.trim(),
        monnaie: _monnaieCtrl.text.trim(),
        formatFacture: _formatFactureCtrl.text.trim(),
        logoUrl: _logoBase64,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil d\'entreprise et logo enregistrés avec succès !'),
            backgroundColor: QuantisColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() { _error = 'Erreur lors de l\'enregistrement: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Widget _buildLogoPreview({double size = 64}) {
    if (_logoBytes != null) {
      return Image.memory(_logoBytes!, width: size, height: size, fit: BoxFit.contain);
    }
    if (_logoBase64 != null && _logoBase64!.isNotEmpty) {
      if (_logoBase64!.startsWith('data:image')) {
        try {
          final decoded = base64Decode(_logoBase64!.split(',').last);
          return Image.memory(decoded, width: size, height: size, fit: BoxFit.contain);
        } catch (_) {}
      } else if (_logoBase64!.startsWith('http')) {
        return Image.network(
          _logoBase64!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.business, size: size * 0.6, color: QuantisColors.royalBlue),
        );
      }
    }
    return Icon(Icons.business, size: size * 0.6, color: QuantisColors.royalBlue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = _logoBytes != null || (_logoBase64 != null && _logoBase64!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil d\'Entreprise & Logo', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEntreprise, tooltip: 'Actualiser'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header Logo Preview
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: QuantisColors.royalBlue,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: QuantisColors.luxuryGold, width: 2),
                                  ),
                                  child: Center(child: _buildLogoPreview(size: 72)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _nomCtrl.text.isNotEmpty ? _nomCtrl.text : 'Nom de l\'entreprise',
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Devise : ${_monnaieCtrl.text}  |  Format factures : ${_formatFactureCtrl.text}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Ce logo officiel sera imprimé automatiquement sur toutes vos factures et reçus de caisse.',
                                        style: TextStyle(color: QuantisColors.luxuryGold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: QuantisColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: QuantisColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: QuantisColors.error, fontSize: 13))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // SECTION UPLOAD LOGO
                        Text('Logo Officiel de l\'Entreprise', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue)),
                        const SizedBox(height: 12),

                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Center(child: _buildLogoPreview(size: 78)),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasLogo
                                            ? (_logoFileName ?? 'Logo personnalisé chargé')
                                            : 'Aucun logo sélectionné',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Formats recommandés : PNG, JPG ou JPEG (fond transparent conseillé).',
                                        style: TextStyle(color: QuantisColors.textMuted, fontSize: 12),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _pickLogo,
                                            icon: const Icon(Icons.upload_file, size: 18),
                                            label: Text(hasLogo ? 'Changer la photo' : 'Importer une photo / logo'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: QuantisColors.royalBlue,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          if (hasLogo)
                                            OutlinedButton.icon(
                                              onPressed: _removeLogo,
                                              icon: const Icon(Icons.delete_outline, size: 18, color: QuantisColors.error),
                                              label: const Text('Supprimer', style: TextStyle(color: QuantisColors.error)),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: QuantisColors.error),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION INFORMATIONS GENERALES
                        Text('Informations Générales', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue)),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _nomCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Raison Sociale / Nom de l\'entreprise *',
                            prefixIcon: Icon(Icons.storefront_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est obligatoire' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nifCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'NIF (Numéro d\'Identifiant Fiscal)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _rccmCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'RCCM (Registre du Commerce)',
                                  prefixIcon: Icon(Icons.assignment_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _telephoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Téléphone de contact',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _emailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Email de l\'entreprise',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _adresseCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Adresse physique / Siège social',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SECTION PARAMETRES FINANCIERS
                        Text('Paramètres Financiers & Factures', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: QuantisColors.royalBlue)),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _monnaieCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Devise monétaire *',
                                  hintText: 'Ex: FCFA, EUR, USD',
                                  prefixIcon: Icon(Icons.attach_money),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'La devise est obligatoire' : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _formatFactureCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Format numérotation factures *',
                                  hintText: 'Ex: FAC-{YYYY}-{NNNNN}',
                                  prefixIcon: Icon(Icons.tag),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Le format est obligatoire' : null,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _saveEntreprise,
                              icon: _saving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save, size: 18),
                              label: const Text('Enregistrer les Modifications'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: QuantisColors.royalBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                              ),
                            ),
                          ],
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
