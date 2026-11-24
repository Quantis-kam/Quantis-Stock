import 'package:flutter/material.dart';

/// Conteneur de dialogue conçu pour rester lisible et scrollable au-dessus du clavier
/// virtuel sur mobile (Android / iOS / Navigateur Web mobile).
class KeyboardSafeDialog extends StatelessWidget {
  final double desktopWidth;
  final Widget child;
  final ScrollController? scrollController;

  const KeyboardSafeDialog({
    super.key,
    this.desktopWidth = 520,
    required this.child,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600;
    final keyboardOpen = media.viewInsets.bottom > 60;
    final double pad = isMobile ? (keyboardOpen ? 14 : 16) : 24;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 32,
        vertical: keyboardOpen ? 6 : 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : desktopWidth,
          maxHeight: (media.size.height - media.viewInsets.bottom - (keyboardOpen ? 16 : 36))
              .clamp(220.0, media.size.height * 0.94),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (keyboardOpen ? 140 : 0),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Enveloppe n'importe quel champ de saisie (`TextField` / `TextFormField`) pour le faire
/// défiler automatiquement au-dessus du clavier virtuel dès qu'il prend le focus ET dès
/// que la hauteur d'écran change (ouverture du clavier sur navigateur mobile & APK).
class EnsureVisibleWhenFocused extends StatefulWidget {
  final Widget child;
  final double alignment;

  const EnsureVisibleWhenFocused({
    super.key,
    required this.child,
    this.alignment = 0.2,
  });

  @override
  State<EnsureVisibleWhenFocused> createState() => _EnsureVisibleWhenFocusedState();
}

class _EnsureVisibleWhenFocusedState extends State<EnsureVisibleWhenFocused>
    with WidgetsBindingObserver {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_hasFocus) {
      _scrollIntoView();
    }
  }

  void _scrollIntoView() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: widget.alignment,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _onFocusChange(bool focused) {
    _hasFocus = focused;
    if (!focused) return;
    _scrollIntoView();
    // Relance après la fin de l'animation du clavier sur mobile Web / Android
    Future.delayed(const Duration(milliseconds: 280), _scrollIntoView);
    Future.delayed(const Duration(milliseconds: 520), _scrollIntoView);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: _onFocusChange,
      child: widget.child,
    );
  }
}

