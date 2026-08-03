import 'package:flutter/material.dart';
import '../../../core/theme/quantis_theme.dart';
import '../data/tiers_models.dart';
import '../data/tiers_service.dart';

/// Formulaire partagé Client / Fournisseur (création et édition).
class TiersFormScreen extends StatefulWidget {
  final bool isClient;
  final ClientModel? client;
  final FournisseurModel? fournisseur;

  const TiersFormScreen({
    super.key,
    required this.isClient,
    this.client,
    this.fournisseur,
  });

  bool get isEditing => (isClient && client != null) || (!isClient && fournisseur != null);

  @override
  State<TiersFormScreen> createState() => _TiersFormScreenState();
}

class _TiersFormScreenState extends State<TiersFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TiersService _service = TiersService();

  late TextEditingController _nomCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _adresseCtrl;
  late TextEditingController _notesCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isClient && widget.client != null) {
      final c = widget.client!;
      _nomCtrl = TextEditingController(text: c.nom);
      _telCtrl = TextEditingController(text: c.telephone ?? '');
      _emailCtrl = TextEditingController(text: c.email ?? '');
      _adresseCtrl = TextEditingController(text: c.adresse ?? '');
      _notesCtrl = TextEditingController(text: c.notes ?? '');
    } else if (!widget.isClient && widget.fournisseur != null) {
      final f = widget.fournisseur!;
      _nomCtrl = TextEditingController(text: f.nom);
      _telCtrl = TextEditingController(text: f.telephone ?? '');
      _emailCtrl = TextEditingController(text: f.email ?? '');
      _adresseCtrl = TextEditingController(text: f.adresse ?? '');
      _notesCtrl = TextEditingController(text: f.notes ?? '');
    } else {
      _nomCtrl = TextEditingController();
      _telCtrl = TextEditingController();
      _emailCtrl = TextEditingController();
      _adresseCtrl = TextEditingController();
      _notesCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (widget.isClient) {
        final client = ClientModel(
          nom: _nomCtrl.text.trim(),
          telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        if (widget.isEditing) {
          await _service.updateClient(widget.client!.id!, client);
        } else {
          await _service.createClient(client);
        }
      } else {
        final fournisseur = FournisseurModel(
          nom: _nomCtrl.text.trim(),
          telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        if (widget.isEditing) {
          await _service.updateFournisseur(widget.fournisseur!.id!, fournisseur);
        } else {
          await _service.createFournisseur(fournisseur);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Mis à jour avec succès' : 'Créé avec succès'),
            backgroundColor: QuantisColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: QuantisColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isClient ? 'Client' : 'Fournisseur';
    final title = widget.isEditing ? 'Modifier $label' : 'Nouveau $label';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar + nom
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: widget.isClient
                      ? QuantisColors.royalBlue.withValues(alpha: 0.1)
                      : QuantisColors.luxuryGold.withValues(alpha: 0.15),
                  child: Icon(
                    widget.isClient ? Icons.person : Icons.business,
                    size: 36,
                    color: widget.isClient ? QuantisColors.royalBlue : QuantisColors.luxuryGold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est requis' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _telCtrl,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+226 70 00 00 00',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _adresseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Solde affiché en mode édition
              if (widget.isEditing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: QuantisColors.bgLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuantisColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isClient ? 'Créance client' : 'Dette fournisseur',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${widget.isClient ? widget.client!.soldeCredit.toStringAsFixed(0) : widget.fournisseur!.soldeDette.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: widget.isClient ? QuantisColors.warning : QuantisColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Bouton enregistrer
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
