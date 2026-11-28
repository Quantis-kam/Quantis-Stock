import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/pin_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/quantis_theme.dart';

/// Écran de déverrouillage rapide par code PIN à 4 chiffres (modèle Wave / Orange Money).
///
/// Affiché en surcouche par-dessus l'application pour ne jamais perdre l'écran ou
/// le panier en cours lors d'un verrouillage après 30 minutes d'inactivité.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorText;
  String? _verifyingStatus;
  bool _verifying = false;
  Timer? _slowServerTimer;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    // Pré-chauffer silencieusement le serveur + JWT pendant que l'utilisateur tape ses 4 chiffres
    unawaited(ApiClient.warmUpInBackground());
  }

  @override
  void dispose() {
    _slowServerTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _shakeController.dispose();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (!mounted || _verifying || event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return true;
    }
    final char = event.character;
    if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
      _onDigit(char);
      return true;
    }
    return false;
  }

  void _onDigit(String digit) {
    if (_verifying || _enteredPin.length >= PinService.pinLength) return;
    setState(() {
      _errorText = null;
      _enteredPin += digit;
    });
    if (_enteredPin.length == PinService.pinLength) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_verifying || _enteredPin.isEmpty) return;
    setState(() {
      _errorText = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    if (_verifying || _enteredPin.isEmpty) return;
    setState(() {
      _errorText = null;
      _enteredPin = '';
    });
  }

  Future<void> _submitPin() async {
    final email = ApiClient.userEmail;
    if (email == null || email.isEmpty) {
      ApiClient.clearToken(
        expiredMessage: 'Veuillez vous reconnecter avec votre mot de passe.',
      );
      return;
    }

    final pinAttempt = _enteredPin;
    setState(() {
      _verifying = true;
      _verifyingStatus = 'Vérification...';
    });

    // 1. Voie ultra-rapide (locale d'abord, < 50 ms) : si le PIN est en cache sécurisé sur cet appareil
    // et correspond, on déverrouille INSTANTANÉMENT sans attendre un réveil serveur (Render).
    final hasLocalPin = await PinService.instance.hasPin(email);
    if (!mounted) return;

    if (hasLocalPin) {
      final localMatch = await PinService.instance.matchesPin(email, pinAttempt);
      if (!mounted) return;

      if (localMatch) {
        await PinService.instance.resetFailedAttempts(email);
        final unlocked = await ApiClient.unlockSessionWithPin();
        if (unlocked) {
          // Synchroniser en arrière-plan si le compte serveur n'a pas encore le PIN
          unawaited(ApiClient.syncLocalPinToAccountIfNeeded(pinAttempt));
        } else if (mounted) {
          setState(() {
            _verifying = false;
            _verifyingStatus = null;
            _enteredPin = '';
          });
        }
        return;
      }

      // Si le PIN saisi diffère du cache local, vérifier rapidement sur le serveur (4 s max)
      // uniquement au cas où l'utilisateur aurait modifié son PIN depuis un autre appareil.
      if (ApiClient.accountHasPin) {
        final serverValid = await ApiClient.verifyAccountPin(
          pinAttempt,
          maxWait: const Duration(seconds: 4),
        );
        if (!mounted) return;
        if (serverValid == true) {
          await PinService.instance.setPin(email, pinAttempt);
          await ApiClient.refreshQuickPinStatus();
          final unlocked = await ApiClient.unlockSessionWithPin();
          if (!unlocked && mounted) {
            setState(() {
              _verifying = false;
              _verifyingStatus = null;
              _enteredPin = '';
            });
          }
          return;
        }
      }

      await _handleInvalidPin(email);
      return;
    }

    // 2. Premier déverrouillage sur un nouvel appareil (aucun cache local encore) :
    // vérification auprès du compte serveur avec feedback clair si le serveur Cloud se réveille.
    _slowServerTimer?.cancel();
    _slowServerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _verifying) {
        setState(() {
          _verifyingStatus = 'Réveil du serveur Cloud en cours...';
        });
      }
    });

    final serverValid = await ApiClient.verifyAccountPin(
      pinAttempt,
      maxWait: const Duration(seconds: 25),
    );
    _slowServerTimer?.cancel();
    if (!mounted) return;

    if (serverValid == true) {
      // Mémoriser localement pour que tous les prochains déverrouillages soient instantanés (< 0.1 s)
      await PinService.instance.setPin(email, pinAttempt);
      await ApiClient.refreshQuickPinStatus();
      final unlocked = await ApiClient.unlockSessionWithPin();
      if (!unlocked && mounted) {
        setState(() {
          _verifying = false;
          _verifyingStatus = null;
          _enteredPin = '';
        });
      }
      return;
    }

    if (serverValid == false) {
      await _handleInvalidPin(email);
      return;
    }

    _shakeController.forward(from: 0);
    setState(() {
      _verifying = false;
      _verifyingStatus = null;
      _enteredPin = '';
      _errorText = 'Serveur momentanément lent ou hors-ligne. Réessayez ou utilisez votre mot de passe.';
    });
  }

  Future<void> _handleInvalidPin(String email) async {
    final fail = await PinService.instance.recordFailedAttempt(email);
    if (!mounted) return;
    if (fail.isLockedOut) {
      ApiClient.clearToken(
        expiredMessage:
            'Trop de tentatives de code PIN. Veuillez vous reconnecter avec votre mot de passe.',
      );
      return;
    }
    _shakeController.forward(from: 0);
    setState(() {
      _verifying = false;
      _verifyingStatus = null;
      _enteredPin = '';
      _errorText =
          'Code PIN incorrect (${fail.remainingAttempts} essai${fail.remainingAttempts > 1 ? 's' : ''} restant${fail.remainingAttempts > 1 ? 's' : ''})';
    });
  }

  void _switchToPassword() {
    ApiClient.clearToken();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final userName = ApiClient.userName ?? 'Utilisateur';
    final entreprise = ApiClient.entrepriseNom;
    final reason = ApiClient.lockReasonMessage ?? 'Déverrouillage rapide';

    return Material(
      color: QuantisColors.bgLight,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [QuantisColors.blueDark, QuantisColors.royalBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 32,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Quantis
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: QuantisColors.luxuryGold,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            'assets/images/quantis_emblem_circle.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'Q',
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: QuantisColors.royalBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Bon retour, $userName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entreprise,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: QuantisColors.luxuryGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: QuantisColors.luxuryGold,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              reason,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: QuantisColors.goldLight,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Indicateurs 4 chiffres avec animation shake
                    AnimatedBuilder(
                      animation: _shakeOffset,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeOffset.value, 0),
                        child: child,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(PinService.pinLength, (index) {
                          final filled = index < _enteredPin.length;
                          final hasErr = _errorText != null;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? (hasErr
                                      ? QuantisColors.error
                                      : QuantisColors.luxuryGold)
                                  : Colors.transparent,
                              border: Border.all(
                                color: hasErr
                                    ? QuantisColors.error
                                    : (filled
                                        ? QuantisColors.luxuryGold
                                        : Colors.white60),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: _verifying
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: QuantisColors.luxuryGold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _verifyingStatus ?? 'Vérification...',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: QuantisColors.goldLight,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _errorText != null
                              ? Text(
                                  _errorText!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const Text(
                                  'Saisissez votre code PIN à 4 chiffres',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                    ),
                    const SizedBox(height: 20),

                    // Pavé numérique tactile
                    _PinKeypad(
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onClear: _onClear,
                      darkSurface: true,
                    ),
                    const SizedBox(height: 20),

                    TextButton.icon(
                      onPressed: _verifying ? null : _switchToPassword,
                      icon: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        'Changer de compte / Code PIN oublié',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialogue de configuration / modification / suppression du code PIN rapide (4 chiffres).
class PinSetupDialog extends StatefulWidget {
  final bool isPostLoginPrompt;

  const PinSetupDialog({
    super.key,
    this.isPostLoginPrompt = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    bool isPostLoginPrompt = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !isPostLoginPrompt,
      builder: (_) => PinSetupDialog(isPostLoginPrompt: isPostLoginPrompt),
    );
  }

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  bool _hasExistingPin = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final hasLocal = await PinService.instance.hasPin(ApiClient.userEmail);
    if (mounted) {
      setState(() {
        _hasExistingPin = ApiClient.hasQuickPin || hasLocal;
        _loading = false;
      });
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    if (!mounted || _saving || _loading || event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return true;
    }
    final char = event.character;
    if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
      _onDigit(char);
      return true;
    }
    return false;
  }

  String get _activeValue => _isConfirmStep ? _confirmPin : _firstPin;

  void _onDigit(String digit) {
    if (_saving || _activeValue.length >= PinService.pinLength) return;
    setState(() {
      _error = null;
      if (_isConfirmStep) {
        _confirmPin += digit;
      } else {
        _firstPin += digit;
      }
    });

    if (!_isConfirmStep && _firstPin.length == PinService.pinLength) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          setState(() => _isConfirmStep = true);
        }
      });
    } else if (_isConfirmStep && _confirmPin.length == PinService.pinLength) {
      _validateAndSave();
    }
  }

  void _onBackspace() {
    if (_saving) return;
    setState(() {
      _error = null;
      if (_isConfirmStep) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirmStep = false;
        }
      } else if (_firstPin.isNotEmpty) {
        _firstPin = _firstPin.substring(0, _firstPin.length - 1);
      }
    });
  }

  void _onClear() {
    if (_saving) return;
    setState(() {
      _error = null;
      _firstPin = '';
      _confirmPin = '';
      _isConfirmStep = false;
    });
  }

  Future<void> _validateAndSave() async {
    final email = ApiClient.userEmail;
    if (email == null || email.isEmpty) return;

    if (_firstPin != _confirmPin) {
      setState(() {
        _error = 'Les deux codes PIN ne correspondent pas. Réessayez.';
        _firstPin = '';
        _confirmPin = '';
        _isConfirmStep = false;
      });
      return;
    }

    setState(() => _saving = true);
    await PinService.instance.setPin(email, _firstPin);
    final syncedToAccount = await ApiClient.saveAccountPin(_firstPin);
    await ApiClient.refreshQuickPinStatus();

    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          syncedToAccount
              ? 'Code PIN enregistré sur votre compte ! Vous n\'aurez plus à le recréer.'
              : 'Code PIN activé ! Il sera synchronisé avec votre compte dès la prochaine connexion.',
        ),
        backgroundColor: QuantisColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return PopScope(
      canPop: !widget.isPostLoginPrompt,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 40,
          vertical: 20,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: _loading
                ? const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: QuantisColors.royalBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.pin_outlined,
                              color: QuantisColors.royalBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasExistingPin
                                      ? 'Modifier mon code PIN'
                                      : 'Créez votre Code PIN (4 chiffres)',
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: QuantisColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  widget.isPostLoginPrompt
                                      ? 'Créé une seule fois et rattaché à votre compte — plus besoin de le recréer'
                                      : 'Rattaché à votre compte pour déverrouiller tous vos appareils en 1 seconde',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: QuantisColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!widget.isPostLoginPrompt)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: QuantisColors.royalBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _isConfirmStep
                              ? 'Étape 2/2 : Confirmez votre code PIN à 4 chiffres'
                              : 'Étape 1/2 : Choisissez un code PIN à 4 chiffres',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: QuantisColors.royalBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4 points de saisie
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(PinService.pinLength, (index) {
                          final filled = index < _activeValue.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? QuantisColors.royalBlue
                                  : Colors.transparent,
                              border: Border.all(
                                color: _error != null
                                    ? QuantisColors.error
                                    : (filled
                                        ? QuantisColors.royalBlue
                                        : QuantisColors.textMuted),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 22,
                        child: _saving
                            ? const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _error != null
                                ? Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: QuantisColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),

                      _PinKeypad(
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                        onClear: _onClear,
                        darkSurface: false,
                      ),
                      if (!widget.isPostLoginPrompt) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(
                                color: QuantisColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Dialogue intelligent au clic sur « Déconnexion » lorsque le code PIN est actif :
/// propose en priorité de verrouiller par Code PIN (pour ne pas retaper email + mot de passe),
/// tout en laissant l'option « Changer de compte » pour une déconnexion complète.
class LockOrLogoutDialog extends StatelessWidget {
  final VoidCallback onLockWithPin;
  final VoidCallback onFullLogout;

  const LockOrLogoutDialog({
    super.key,
    required this.onLockWithPin,
    required this.onFullLogout,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onLockWithPin,
    required VoidCallback onFullLogout,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LockOrLogoutDialog(
        onLockWithPin: onLockWithPin,
        onFullLogout: onFullLogout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: QuantisColors.royalBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fermer la session ?',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Verrouillez avec votre code PIN à 4 chiffres pour revenir en 1 seconde sans retaper votre email et mot de passe, ou changez complètement de compte.',
        style: TextStyle(fontSize: 13, color: QuantisColors.textSecondary, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onLockWithPin();
              },
              icon: const Icon(Icons.pin_outlined, size: 18),
              label: const Text('Verrouiller par Code PIN (Recommandé)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onFullLogout();
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: QuantisColors.error),
              label: const Text(
                'Changer de compte (Déconnexion complète)',
                style: TextStyle(color: QuantisColors.error, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: QuantisColors.error.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool darkSurface;

  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.darkSurface,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '<'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key == 'C') {
                return _buildKey(
                  label: 'Effacer',
                  isTextAction: true,
                  onTap: onClear,
                );
              }
              if (key == '<') {
                return _buildKey(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                );
              }
              return _buildKey(
                label: key,
                onTap: () => onDigit(key),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey({
    String? label,
    IconData? icon,
    bool isTextAction = false,
    required VoidCallback onTap,
  }) {
    final bgColor = darkSurface
        ? Colors.white.withValues(alpha: isTextAction || icon != null ? 0.06 : 0.14)
        : (isTextAction || icon != null
            ? QuantisColors.bgLight
            : QuantisColors.royalBlue.withValues(alpha: 0.07));
    final fgColor = darkSurface ? Colors.white : QuantisColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(
              color: darkSurface
                  ? Colors.white.withValues(alpha: 0.16)
                  : QuantisColors.border,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: fgColor, size: 22)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontFamily: isTextAction ? 'Inter' : 'SpaceGrotesk',
                      fontSize: isTextAction ? 11.5 : 24,
                      fontWeight: isTextAction ? FontWeight.w600 : FontWeight.w700,
                      color: isTextAction
                          ? (darkSurface ? Colors.white70 : QuantisColors.textSecondary)
                          : fgColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

