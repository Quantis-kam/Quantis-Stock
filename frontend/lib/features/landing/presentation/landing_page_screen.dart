import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/quantis_theme.dart';
import '../../../core/utils/whatsapp_share_helper.dart';
import '../../../core/widgets/pwa_install_button.dart';

/// Page d'accueil vitrine professionnelle Quantis-Stock.
/// Présente la proposition de valeur, les fonctionnalités clés, le tarif transparent
/// et permet aux visiteurs de demander la création de leur entreprise via formulaire,
/// WhatsApp (+226 65 18 92 61) ou Email (contact@quantisbf.com).
class LandingPageScreen extends StatefulWidget {
  /// Action déclenchée lorsque le visiteur clique sur « Se connecter ».
  final VoidCallback onGoToLogin;

  /// Indique si la page a été ouverte via Navigator.push depuis LoginScreen (mobile/APK).
  final bool canPopToLogin;

  const LandingPageScreen({
    super.key,
    required this.onGoToLogin,
    this.canPopToLogin = false,
  });

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final _scrollCtrl = ScrollController();
  final _whyKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();
  final _contactKey = GlobalKey();

  final _formKey = GlobalKey<FormState>();
  final _entrepriseCtrl = TextEditingController();
  final _responsableCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  static const String _formuleAnnuelle =
      'Annuelle — 100 000 FCFA (1re année, puis 120 000 FCFA/an)';
  static const String _formuleMensuelle =
      'Mensuelle — 10 100 FCFA / mois (sans engagement)';
  static const List<String> _formules = [
    _formuleAnnuelle,
    _formuleMensuelle,
  ];

  String _secteur = 'Boutique / Commerce général';
  String _formule = _formuleAnnuelle;
  bool _submitting = false;
  bool _submittedOk = false;
  String? _lastSentSummary;
  String? _submitNotice;

  static const List<String> _secteurs = [
    'Boutique / Commerce général',
    'Alimentation / Supérette',
    'Quincaillerie / Matériaux',
    'Pharmacie / Cosmétique',
    'Électronique / Téléphonie',
    'Grossiste / Distribution',
    'Restauration / Dépôt Boissons',
    'Pièces détachées / Auto-Moto',
    'Autre activité',
  ];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _entrepriseCtrl.dispose();
    _responsableCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _villeCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _goToLogin() {
    if (widget.canPopToLogin && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      widget.onGoToLogin();
    }
  }

  void _selectPlanAndScroll(String formule) {
    setState(() {
      _formule = formule;
      _submittedOk = false;
    });
    _scrollTo(_contactKey);
  }

  String _buildLeadMessage() {
    final buf = StringBuffer();
    buf.writeln('Bonjour l\'équipe Quantis-Stock,');
    buf.writeln('Je souhaite créer un espace entreprise sur Quantis-Stock :');
    buf.writeln('');
    buf.writeln('• Entreprise : ${_entrepriseCtrl.text.trim()}');
    buf.writeln('• Secteur : $_secteur');
    buf.writeln('• Formule souhaitée : $_formule');
    if (_villeCtrl.text.trim().isNotEmpty) {
      buf.writeln('• Ville / Quartier : ${_villeCtrl.text.trim()}');
    }
    buf.writeln('• Responsable : ${_responsableCtrl.text.trim()}');
    buf.writeln('• Téléphone / WhatsApp : ${_telephoneCtrl.text.trim()}');
    buf.writeln('• Email : ${_emailCtrl.text.trim()}');
    if (_messageCtrl.text.trim().isNotEmpty) {
      buf.writeln('• Précisions : ${_messageCtrl.text.trim()}');
    }
    buf.writeln('');
    buf.writeln('Merci de me contacter pour activer mon compte !');
    return buf.toString();
  }

  Future<bool> _persistLeadOnBackend(String canal) async {
    try {
      final isCloud = ApiConstants.baseUrl.toLowerCase().startsWith('https://');
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: Duration(seconds: isCloud ? 15 : 6),
        receiveTimeout: Duration(seconds: isCloud ? 20 : 8),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
      final rawMsg = _messageCtrl.text.trim();
      final fullMessage = rawMsg.isEmpty
          ? '[Formule : $_formule]'
          : '[Formule : $_formule]\n$rawMsg';
      final res = await dio.post('/public/demandes-entreprise', data: {
        'nomEntreprise': _entrepriseCtrl.text.trim(),
        'secteurActivite': _secteur,
        'ville': _villeCtrl.text.trim(),
        'nomResponsable': _responsableCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'message': fullMessage,
        'canalContact': canal,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Notice enregistrement demande entreprise: $e');
      return false;
    }
  }

  Future<void> _submitLead({required String canal}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollTo(_contactKey);
      return;
    }

    setState(() {
      _submitting = true;
      _submitNotice = null;
    });

    final msg = _buildLeadMessage();
    final savedInPortal = await _persistLeadOnBackend(canal);

    bool channelOpened = false;
    if (canal == 'WHATSAPP') {
      channelOpened = await WhatsappShareHelper.sendDirectMessage(
        phone: AppConstants.supportWhatsAppPhone,
        message: msg,
      );
    } else if (canal == 'EMAIL') {
      final subject = 'Demande de création d\'entreprise — ${_entrepriseCtrl.text.trim()}';
      final mailUri = Uri(
        scheme: 'mailto',
        path: AppConstants.supportEmail,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(msg)}',
      );
      try {
        channelOpened = await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        channelOpened = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submittedOk = true;
      _lastSentSummary = msg;
      if (savedInPortal) {
        _submitNotice = canal == 'WHATSAPP'
            ? 'Votre demande a bien été enregistrée dans notre portail et préparée sur WhatsApp !'
            : (channelOpened
                ? 'Votre demande a bien été enregistrée et votre messagerie a été ouverte.'
                : 'Votre demande a bien été enregistrée ! Notre équipe vous recontactera très vite (ou copiez le récapitulatif ci-dessous).');
      } else {
        _submitNotice = canal == 'WHATSAPP'
            ? 'Votre demande est prête sur WhatsApp (+226 65 18 92 61).'
            : 'Votre demande est prête pour ${AppConstants.supportEmail}.';
      }
    });
  }

  Future<void> _openDirectWhatsAppQuick() async {
    await WhatsappShareHelper.sendDirectMessage(
      phone: AppConstants.supportWhatsAppPhone,
      message:
          'Bonjour l\'équipe Quantis-Stock, je souhaite en savoir plus et créer un compte pour mon entreprise.',
    );
  }

  Future<void> _openDirectEmailQuick() async {
    final mailUri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query:
          'subject=${Uri.encodeComponent("Demande d'information — Quantis-Stock")}&body=${Uri.encodeComponent("Bonjour l'équipe Quantis-Stock,\n\nJe souhaite créer un espace entreprise sur Quantis-Stock.\n\nNom de l'entreprise :\nTéléphone :\nVille :\n")}',
    );
    try {
      await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        await Clipboard.setData(const ClipboardData(text: AppConstants.supportEmail));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email ${AppConstants.supportEmail} copié dans le presse-papiers !'),
            backgroundColor: QuantisColors.royalBlue,
          ),
        );
      }
    }
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié !'),
        backgroundColor: QuantisColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 960;
    final isTablet = width >= 650 && width < 960;
    final isMobile = width < 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopNavbar(isDesktop: isDesktop, isMobile: isMobile),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroSection(isDesktop: isDesktop, isMobile: isMobile),
                  _buildWhyQuantisSection(isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile),
                  _buildFeaturesSection(isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile),
                  _buildPricingSection(isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile),
                  _buildContactLeadSection(isDesktop: isDesktop, isMobile: isMobile),
                  _buildPwaBannerSection(isMobile: isMobile),
                  _buildFooter(isMobile: isMobile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. BARRE DE NAVIGATION FIXE EN HAUT
  // ===========================================================================
  Widget _buildTopNavbar({required bool isDesktop, required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: isMobile ? 10 : 12,
              ),
              child: Row(
                children: [
                  if (widget.canPopToLogin) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: QuantisColors.royalBlue),
                      tooltip: 'Retour à la connexion',
                      onPressed: _goToLogin,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Logo & Marque
                  Container(
                    width: isMobile ? 34 : 40,
                    height: isMobile ? 34 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: QuantisColors.luxuryGold, width: 1.5),
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          'assets/images/quantis_emblem_circle.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'Q',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w800,
                                color: QuantisColors.royalBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: isDesktop ? 0 : 1,
                    fit: isDesktop ? FlexFit.loose : FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'QUANTIS-STOCK',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: isMobile ? 14 : 17,
                            letterSpacing: 0.8,
                            color: QuantisColors.royalBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isMobile)
                          const Text(
                            'Gestion de Stock, POS & Facturation',
                            style: TextStyle(fontSize: 10.5, color: QuantisColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _navLink('Pourquoi nous ?', () => _scrollTo(_whyKey)),
                              _navLink('Fonctionnalités', () => _scrollTo(_featuresKey)),
                              _navLink('Tarifs', () => _scrollTo(_pricingKey)),
                              _navLink('Contact', () => _scrollTo(_contactKey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton(
                    onPressed: _goToLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: QuantisColors.royalBlue,
                      side: const BorderSide(color: QuantisColors.royalBlue, width: 1.3),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 18,
                        vertical: isMobile ? 8 : 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Se connecter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _scrollTo(_contactKey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuantisColors.royalBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 11 : 18,
                        vertical: isMobile ? 8 : 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isMobile ? 'Créer' : 'Créer mon entreprise',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 13.5,
                      ),
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

  Widget _navLink(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: QuantisColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
    );
  }

  // ===========================================================================
  // 2. HERO SECTION
  // ===========================================================================
  Widget _buildHeroSection({required bool isDesktop, required bool isMobile}) {
    final heroText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: QuantisColors.luxuryGold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: QuantisColors.luxuryGold.withValues(alpha: 0.55)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: QuantisColors.luxuryGold),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'SOLUTION DE GESTION POUR COMMERCES & PME',
                  style: TextStyle(
                    color: QuantisColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Pilotez votre stock, vos ventes et vos crédits clients sans aucune perte.',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: isDesktop ? 42 : (isMobile ? 27 : 34),
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Caisse tactile POS, factures PDF partageables sur WhatsApp, suivi strict des créances clients, alertes stock et multi-dépôts — accessible partout sur téléphone, tablette et ordinateur.',
          style: TextStyle(
            fontSize: isMobile ? 14.5 : 16,
            color: Colors.white.withValues(alpha: 0.86),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _scrollTo(_contactKey),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text(
                'Créer mon entreprise',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.luxuryGold,
                foregroundColor: const Color(0xFF0A1A5E),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openDirectWhatsAppQuick,
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text(
                'Discuter sur WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _goToLogin,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(
                'Déjà client ? Se connecter',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _heroTrustChip(Icons.bolt_rounded, 'Mise en place en 5 min'),
            _heroTrustChip(Icons.devices_rounded, 'Web, Android & PC'),
            _heroTrustChip(Icons.pin_outlined, 'Accès rapide Code PIN'),
            _heroTrustChip(Icons.payments_outlined, '100 000 F / 1re an. ou 10 100 F / mois'),
          ],
        ),
      ],
    );

    final heroPreview = _buildHeroShowcaseCard(isMobile: isMobile);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF091442), Color(0xFF1E2F97), Color(0xFF142474)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isDesktop ? 64 : 36,
            ),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 6, child: heroText),
                      const SizedBox(width: 42),
                      Expanded(flex: 5, child: heroPreview),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heroText,
                      const SizedBox(height: 30),
                      heroPreview,
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _heroTrustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: QuantisColors.luxuryGold),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroShowcaseCard({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tableau de bord temps réel • Quantis-Stock',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: QuantisColors.luxuryGold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: QuantisColors.luxuryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniPreviewMetric(
                  label: 'Ventes du jour',
                  value: '485 500 F',
                  badge: '+18%',
                  accent: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniPreviewMetric(
                  label: 'Crédits suivis',
                  value: '100% tracés',
                  badge: 'Zéro oubli',
                  accent: QuantisColors.luxuryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Encaissement multi-modes inclus',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _paymentPill('Espèces'),
                    _paymentPill('Orange Money'),
                    _paymentPill('Wave'),
                    _paymentPill('Moov Money'),
                    _paymentPill('Carte'),
                    _paymentPill('Crédit Client'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Facture PDF + Reçu 80mm partagés sur WhatsApp en 1 clic',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPreviewMetric({
    required String label,
    required String value,
    required String badge,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ===========================================================================
  // 3. POURQUOI CHOISIR QUANTIS-STOCK ?
  // ===========================================================================
  Widget _buildWhyQuantisSection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final pillars = [
      (
        Icons.inventory_2_rounded,
        QuantisColors.royalBlue,
        'Zéro perte de stock ni de caisse',
        'Suivez chaque entrée, sortie, transfert et inventaire en temps réel. Recevez des alertes automatiques avant toute rupture de stock.',
      ),
      (
        Icons.credit_score_rounded,
        const Color(0xFFD97706),
        'Maîtrise totale des crédits clients',
        'Fini les dettes oubliées au comptoir : identifiez le client à crédit (nom + téléphone), suivez ses acomptes et relancez-le par WhatsApp en 1 clic.',
      ),
      (
        Icons.point_of_sale_rounded,
        const Color(0xFF059669),
        'Pensé pour votre activité réelle',
        'Encaissez en Espèces, Orange Money, Wave, Moov Money ou Carte. Activez ou désactivez la TVA (0% / 18%) et le prix d\'achat selon vos besoins.',
      ),
      (
        Icons.security_rounded,
        const Color(0xFF4F46E5),
        'Multi-utilisateurs & 100% sécurisé',
        'Attribuez des permissions précises à vos caissiers et magasiniers. Vos données d\'entreprise sont cloisonnées et protégées par Code PIN.',
      ),
    ];

    return Container(
      key: _whyKey,
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 40 : 64,
            ),
            child: Column(
              children: [
                _sectionHeader(
                  eyebrow: 'POURQUOI CHOISIR QUANTIS-STOCK ?',
                  title: 'Conçu pour faire grandir votre commerce au quotidien',
                  subtitle:
                      'Un outil simple, rapide et fiable pour remplacer les cahiers papier et garder le contrôle total sur votre chiffre d\'affaires.',
                  isMobile: isMobile,
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = isDesktop || isTablet ? 2 : 1;
                    final spacing = 18.0;
                    final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: pillars.map((p) {
                        return SizedBox(
                          width: itemWidth,
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: p.$2.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(p.$1, color: p.$2, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.$3,
                                        style: const TextStyle(
                                          fontFamily: 'SpaceGrotesk',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: QuantisColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        p.$4,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: QuantisColors.textSecondary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. FONCTIONNALITÉS CLÉS
  // ===========================================================================
  Widget _buildFeaturesSection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final features = [
      (
        Icons.touch_app_rounded,
        'Caisse POS Tactile',
        'Vendez en 2 clics, saisissez directement de grandes quantités (ex: 50 unités) et imprimez des tickets 80mm.',
      ),
      (
        Icons.receipt_long_rounded,
        'Factures PDF & WhatsApp',
        'Devis, Bons de Commande, Bons de Livraison et Factures pro avec 4 modèles personnalisables et envoi WhatsApp.',
      ),
      (
        Icons.warehouse_rounded,
        'Multi-Dépôts & Arrêts Stock',
        'Suivez plusieurs magasins ou entrepôts, valorisez votre inventaire et faites des arrêts de stock en 1 clic.',
      ),
      (
        Icons.account_balance_wallet_rounded,
        'Caisse & Trésorerie',
        'Enregistrez vos entrées, dépenses et règlements clients pour connaître votre solde de caisse exact à tout moment.',
      ),
      (
        Icons.local_shipping_rounded,
        'Achats & Fournisseurs',
        'Gérez vos bons de commande fournisseurs, réceptions partielles ou complètes et dettes fournisseurs.',
      ),
      (
        Icons.bar_chart_rounded,
        'Rapports & Exports Excel',
        'Consultez vos bénéfices, produits phares et exportez vos données comptables proprement en un instant.',
      ),
    ];

    return Container(
      key: _featuresKey,
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 40 : 64,
            ),
            child: Column(
              children: [
                _sectionHeader(
                  eyebrow: 'TOUT-EN-UN',
                  title: 'Tous les outils essentiels dans une seule application',
                  subtitle: 'Accessible sur navigateur Web, application Android et ordinateur sans installation lourde.',
                  isMobile: isMobile,
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = isDesktop ? 3 : (isTablet ? 2 : 1);
                    final spacing = 16.0;
                    final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: features.map((f) {
                        return SizedBox(
                          width: itemWidth,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: QuantisColors.royalBlue.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(f.$1, color: QuantisColors.royalBlue, size: 22),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  f.$2,
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                    color: QuantisColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  f.$3,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: QuantisColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. TARIFICATION CLAIRE (ANNUEL 120 000 F / 100 000 F 1RE ANNÉE + MENSUEL 10 100 F)
  // ===========================================================================
  Widget _buildPricingSection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final included = [
      'Caisse POS tactile & Tickets 80mm',
      'Produits, clients & factures illimités',
      'Gestion multi-dépôts & alertes stock',
      'Suivi des crédits & relances WhatsApp',
      'Multi-utilisateurs & rôles personnalisés',
      'Accès Web, Android & PC + mises à jour',
      'Code PIN rapide rattaché au compte',
      'Support WhatsApp dédié (+226 65 18 92 61)',
    ];

    Widget buildPlanBullet(String text, {required bool dark}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: dark ? QuantisColors.luxuryGold : QuantisColors.success,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: dark ? Colors.white.withValues(alpha: 0.94) : QuantisColors.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final annualCard = Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1A5E), Color(0xFF1E2F97)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: QuantisColors.luxuryGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: QuantisColors.royalBlue.withValues(alpha: 0.26),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: QuantisColors.luxuryGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'OFFRE NOUVEAU CLIENT • -20 000 F',
                      style: TextStyle(
                        color: Color(0xFF0A1A5E),
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Abonnement Annuel',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Tarif de base :',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '120 000 FCFA / an',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: QuantisColors.luxuryGold,
                      decorationThickness: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    '100 000',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: isMobile ? 38 : 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'FCFA / 1re année',
                      style: TextStyle(
                        color: QuantisColors.goldLight,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: QuantisColors.luxuryGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: QuantisColors.luxuryGold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Cadeau de bienvenue : 100 000 FCFA pour votre 1re année de collaboration (soit ~8 333 FCFA/mois), puis 120 000 FCFA/an dès la 2e année.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.2,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              buildPlanBullet('Économie immédiate de 20 000 FCFA la 1re année', dark: true),
              buildPlanBullet('12 mois d\'accès complet sans coupure mensuelle', dark: true),
              buildPlanBullet('Toutes les fonctionnalités + support prioritaire', dark: true),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _selectPlanAndScroll(_formuleAnnuelle),
              icon: const Icon(Icons.workspace_premium_rounded, size: 19),
              label: const Text(
                'Choisir l\'offre Annuelle',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.luxuryGold,
                foregroundColor: const Color(0xFF0A1A5E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );

    final monthlyCard = Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'FLEXIBLE • PAIEMENT AU MOIS',
                  style: TextStyle(
                    color: QuantisColors.royalBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Abonnement Mensuel',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: QuantisColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Payer 100 000 FCFA d\'un coup vous semble élevé ? Passez à la formule mensuelle en toute souplesse.',
                style: TextStyle(
                  color: QuantisColors.textSecondary,
                  fontSize: 12.8,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    '10 100',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: isMobile ? 38 : 44,
                      fontWeight: FontWeight.w900,
                      color: QuantisColors.royalBlue,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'FCFA / mois',
                      style: TextStyle(
                        color: QuantisColors.textSecondary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Réabonnement direct par Orange Money • Sans engagement. Vous pouvez basculer en annuel à tout moment.',
                  style: TextStyle(
                    color: QuantisColors.textSecondary,
                    fontSize: 12.2,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              buildPlanBullet('Aucun gros versement initial requis', dark: false),
              buildPlanBullet('100% des fonctionnalités incluses dès le 1er jour', dark: false),
              buildPlanBullet('Paiement simple et rapide par Orange Money', dark: false),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _selectPlanAndScroll(_formuleMensuelle),
              icon: const Icon(Icons.calendar_month_rounded, size: 19),
              label: const Text(
                'Choisir l\'offre Mensuelle',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      key: _pricingKey,
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 40 : 64,
            ),
            child: Column(
              children: [
                _sectionHeader(
                  eyebrow: 'TARIFS SIMPLES & TRANSPARENTS',
                  title: 'Choisissez la formule adaptée à votre rythme',
                  subtitle:
                      'Abonnement annuel de base à 120 000 FCFA/an — offert à 100 000 FCFA la 1re année pour nos nouveaux clients, ou formule mensuelle flexible à 10 100 FCFA/mois.',
                  isMobile: isMobile,
                ),
                const SizedBox(height: 30),
                if (isDesktop || isTablet)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: annualCard),
                        const SizedBox(width: 22),
                        Expanded(child: monthlyCard),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      annualCard,
                      const SizedBox(height: 18),
                      monthlyCard,
                    ],
                  ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 18 : 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: QuantisColors.royalBlue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inclus dans les deux formules — Zéro frais caché',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: QuantisColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final twoCols = constraints.maxWidth >= 560;
                          final itemW = twoCols ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
                          return Wrap(
                            spacing: 20,
                            runSpacing: 10,
                            children: included.map((text) {
                              return SizedBox(
                                width: itemW,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: QuantisColors.royalBlue, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        text,
                                        style: const TextStyle(color: QuantisColors.textPrimary, fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 6. DEMANDE DE CRÉATION D'ENTREPRISE (FORMULAIRE + WHATSAPP + EMAIL)
  // ===========================================================================
  Widget _buildContactLeadSection({required bool isDesktop, required bool isMobile}) {
    final directContactColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact direct & rapide',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: QuantisColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Remplissez le formulaire ci-contre ou contactez-nous directement par WhatsApp ou Email. Votre espace entreprise est prêt en quelques minutes.',
          style: TextStyle(fontSize: 13.5, color: QuantisColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 18),

        // Carte WhatsApp Direct
        _directContactTile(
          icon: Icons.chat_rounded,
          color: const Color(0xFF25D366),
          title: 'WhatsApp Commercial',
          value: AppConstants.supportPhoneDisplay,
          subtitle: 'Réponse rapide 7j/7 pour créer votre compte',
          onTap: _openDirectWhatsAppQuick,
          onCopy: () => _copyText(AppConstants.supportPhoneDisplay, 'Numéro WhatsApp'),
        ),
        const SizedBox(height: 12),

        // Carte Email Direct
        _directContactTile(
          icon: Icons.email_rounded,
          color: QuantisColors.royalBlue,
          title: 'Email Officiel',
          value: AppConstants.supportEmail,
          subtitle: 'Demandes de création, devis ou assistance',
          onTap: _openDirectEmailQuick,
          onCopy: () => _copyText(AppConstants.supportEmail, 'Adresse email'),
        ),
        const SizedBox(height: 16),

        // Étapes d'onboarding
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QuantisColors.royalBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: QuantisColors.royalBlue.withValues(alpha: 0.16)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comment ça se passe ?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: QuantisColors.royalBlue),
              ),
              SizedBox(height: 10),
              _OnboardingStepRow('1', 'Vous envoyez votre demande via le formulaire, WhatsApp ou Email.'),
              SizedBox(height: 6),
              _OnboardingStepRow('2', 'Nous créons votre espace entreprise isolé + votre compte Admin.'),
              SizedBox(height: 6),
              _OnboardingStepRow('3', 'Vous recevez vos accès et commencez à vendre immédiatement !'),
            ],
          ),
        ),
      ],
    );

    final formCard = Container(
      padding: EdgeInsets.all(isMobile ? 18 : 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _submittedOk
          ? _buildSuccessConfirmation()
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demander la création de mon entreprise',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: QuantisColors.royalBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Renseignez ces quelques informations puis choisissez WhatsApp ou Email.',
                    style: TextStyle(fontSize: 12.5, color: QuantisColors.textSecondary),
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _entrepriseCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom de votre entreprise / boutique *',
                      hintText: 'Ex: Alimentation Faso, Quincaillerie Wend-Panga...',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Veuillez indiquer le nom de votre entreprise' : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _secteur,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Secteur d\'activité',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _secteurs
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _secteur = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _formule,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Formule d\'abonnement souhaitée',
                      prefixIcon: Icon(Icons.workspace_premium_outlined),
                    ),
                    items: _formules
                        .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _formule = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  if (isMobile) ...[
                    TextFormField(
                      controller: _responsableCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet du responsable *',
                        hintText: 'Ex: Moussa Ouédraogo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Veuillez indiquer votre nom complet' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telephoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone / WhatsApp *',
                        hintText: 'Ex: +226 70 12 34 56',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 6) ? 'Numéro de téléphone requis' : null,
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _responsableCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nom complet du responsable *',
                              hintText: 'Ex: Moussa Ouédraogo',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Nom complet requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _telephoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone / WhatsApp *',
                              hintText: 'Ex: +226 70 12 34 56',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 6) ? 'Téléphone requis' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  if (isMobile) ...[
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse Email *',
                        hintText: 'Ex: contact@maboutique.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email requis';
                        if (!v.contains('@') || !v.contains('.')) return 'Adresse email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _villeCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ville / Quartier',
                        hintText: 'Ex: Ouagadougou, Bobo-Dioulasso...',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Adresse Email *',
                              hintText: 'Ex: contact@maboutique.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email requis';
                              if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _villeCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Ville / Quartier',
                              hintText: 'Ex: Ouagadougou, Bobo...',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _messageCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Précisions ou besoins particuliers (optionnel)',
                      hintText: 'Ex: Nombre de boutiques/dépôts, nombre d\'utilisateurs...',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (isMobile) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : () => _submitLead(canal: 'WHATSAPP'),
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.chat_rounded, size: 19),
                        label: const Text(
                          'Envoyer via WhatsApp',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : () => _submitLead(canal: 'EMAIL'),
                        icon: const Icon(Icons.email_outlined, size: 19),
                        label: const Text(
                          'Envoyer par Email',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuantisColors.royalBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : () => _submitLead(canal: 'WHATSAPP'),
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.chat_rounded, size: 19),
                            label: const Text(
                              'Envoyer via WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : () => _submitLead(canal: 'EMAIL'),
                            icon: const Icon(Icons.email_outlined, size: 19),
                            label: const Text(
                              'Envoyer par Email',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QuantisColors.royalBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );

    return Container(
      key: _contactKey,
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 40 : 64,
            ),
            child: Column(
              children: [
                _sectionHeader(
                  eyebrow: 'DÉMARRER MAINTENANT',
                  title: 'Créez l\'espace de votre entreprise dès aujourd\'hui',
                  subtitle:
                      'Envoyez votre demande en 30 secondes — notre équipe vous accompagne sur WhatsApp ou par email.',
                  isMobile: isMobile,
                ),
                const SizedBox(height: 32),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: directContactColumn),
                      const SizedBox(width: 32),
                      Expanded(flex: 7, child: formCard),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      formCard,
                      const SizedBox(height: 24),
                      directContactColumn,
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QuantisColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: QuantisColors.success, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'Demande envoyée avec succès !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: QuantisColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _submitNotice ?? 'Notre équipe a bien reçu votre demande et vous contactera très rapidement.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: QuantisColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                if (_lastSentSummary != null) {
                  WhatsappShareHelper.sendDirectMessage(
                    phone: AppConstants.supportWhatsAppPhone,
                    message: _lastSentSummary!,
                  );
                }
              },
              icon: const Icon(Icons.chat_rounded, size: 17),
              label: const Text('Ouvrir WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                if (_lastSentSummary != null) {
                  _copyText(_lastSentSummary!, 'Récapitulatif de la demande');
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Copier le message'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _submittedOk = false;
                _entrepriseCtrl.clear();
                _responsableCtrl.clear();
                _telephoneCtrl.clear();
                _emailCtrl.clear();
                _villeCtrl.clear();
                _messageCtrl.clear();
              }),
              child: const Text('Nouvelle demande'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _directContactTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    Text(
                      value,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: Colors.grey.shade600,
                tooltip: 'Copier',
                onPressed: onCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPwaBannerSection({required bool isMobile}) {
    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: 20,
            ),
            child: const PwaInstallCard(),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 7. FOOTER PRO
  // ===========================================================================
  Widget _buildFooter({required bool isMobile}) {
    return Container(
      color: const Color(0xFF0A1438),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: 28,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 14,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUANTIS-STOCK',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© ${DateTime.now().year} Quantis Burkina Faso • ${AppConstants.supportEmail} • ${AppConstants.supportPhoneDisplay}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _goToLogin,
                  icon: const Icon(Icons.login_rounded, size: 17, color: QuantisColors.luxuryGold),
                  label: const Text(
                    'Espace Client — Se connecter',
                    style: TextStyle(color: QuantisColors.luxuryGold, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String eyebrow,
    required String title,
    required String subtitle,
    required bool isMobile,
  }) {
    return Column(
      children: [
        Text(
          eyebrow,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: QuantisColors.royalBlue,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w800,
            fontSize: isMobile ? 23 : 30,
            color: QuantisColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: QuantisColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingStepRow extends StatelessWidget {
  final String number;
  final String text;
  const _OnboardingStepRow(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
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
              number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12.5, color: QuantisColors.textPrimary)),
        ),
      ],
    );
  }
}

