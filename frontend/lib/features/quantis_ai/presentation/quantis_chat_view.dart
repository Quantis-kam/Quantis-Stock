import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/quantis_theme.dart';
import 'providers/quantis_ai_controller.dart';
import '../services/quantis_voice_service.dart';
import 'widgets/jarvis_voice_modal.dart';
import 'widgets/quantis_chat_bubble.dart';
import 'widgets/quantis_typing_indicator.dart';

class QuantisChatView extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final bool isFullScreen;

  const QuantisChatView({
    super.key,
    this.onClose,
    this.isFullScreen = false,
  });

  @override
  ConsumerState<QuantisChatView> createState() => _QuantisChatViewState();
}

class _QuantisChatViewState extends ConsumerState<QuantisChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _voiceService = QuantisVoiceService();

  VoiceState _voiceState = VoiceState.standby;
  StreamSubscription? _voiceSub;
  StreamSubscription? _partialSub;
  StreamSubscription? _finalSub;

  @override
  void initState() {
    super.initState();
    _voiceSub = _voiceService.stateStream.listen((state) {
      if (mounted) setState(() => _voiceState = state);
    });

    _partialSub = _voiceService.partialTranscriptStream.listen((text) {
      if (mounted) {
        setState(() {
          _textController.text = text;
        });
      }
    });

    _finalSub = _voiceService.finalTranscriptStream.listen((text) {
      if (mounted && text.trim().isNotEmpty) {
        setState(() {
          _textController.text = text;
        });
        _handleSubmit();
      }
    });
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    _partialSub?.cancel();
    _finalSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  void _toggleVoiceInput() {
    if (_voiceState == VoiceState.listening) {
      _voiceService.stopListening();
    } else {
      _textController.clear();
      _voiceService.startListening();
    }
  }

  void _handleSubmit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _voiceService.stopListening();
    _textController.clear();
    ref.read(quantisAiProvider.notifier).sendMessage(text).then((response) {
      if (response != null && !_voiceService.isMuted) {
        _voiceService.speak(response.text);
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(quantisAiProvider);

    // Auto-scroll when new messages arrive
    ref.listen(quantisAiProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.isLoading != next.isLoading) {
        _scrollToBottom();
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: QuantisColors.bgLight,
        borderRadius: widget.isFullScreen
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: QuantisColors.border),
          Expanded(
            child: aiState.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount:
                        aiState.messages.length + (aiState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < aiState.messages.length) {
                        final msg = aiState.messages[index];
                        return QuantisChatBubble(
                          message: msg,
                          onSuggestionSelected: (suggestion) {
                            ref
                                .read(quantisAiProvider.notifier)
                                .sendMessage(suggestion);
                            _scrollToBottom();
                          },
                        );
                      } else {
                        return const QuantisTypingIndicator();
                      }
                    },
                  ),
          ),
          if (aiState.currentSuggestions.isNotEmpty)
            _buildSuggestionsBar(aiState.currentSuggestions),
          _buildInputBar(aiState.isLoading),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 420;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 10),
      decoration: const BoxDecoration(
        color: QuantisColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: QuantisColors.luxuryGold,
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text(
                'Q',
                style: TextStyle(
                  color: QuantisColors.luxuryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Quantis AI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: QuantisColors.royalBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: QuantisColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  isCompact ? 'Assistant Stock & IA' : 'Assistant Vocal & Stock connecté',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: QuantisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Bouton Mode Vocal Jarvis
          Tooltip(
            message: 'Ouvrir le Mode Vocal Jarvis',
            child: InkWell(
              onTap: () => JarvisVoiceModal.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF00B4D8),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompact ? 'Jarvis' : 'Vocal Jarvis',
                      style: const TextStyle(
                        color: Color(0xFF0077B6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: QuantisColors.textSecondary),
            tooltip: 'Nouvelle conversation',
            onPressed: () {
              ref.read(quantisAiProvider.notifier).clearHistory();
            },
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: QuantisColors.textSecondary),
              tooltip: 'Fermer',
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Jarvis Orb Miniature
            InkWell(
              onTap: () => JarvisVoiceModal.show(context),
              borderRadius: BorderRadius.circular(36),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF00E5FF),
                      QuantisColors.royalBlue,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bonjour, je suis Quantis 🎙️✨',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: QuantisColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre copilote vocal expert en gestion de stock.\nParlez ou tapez pour exécuter vos mouvements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: QuantisColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => JarvisVoiceModal.show(context),
              icon: const Icon(Icons.graphic_eq_rounded, size: 20),
              label: const Text("Lancer le Mode Vocal Jarvis"),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuantisColors.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsBar(List<String> suggestions) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(
              suggestions[index],
              style: const TextStyle(
                fontSize: 12,
                color: QuantisColors.royalBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: QuantisColors.white,
            side: const BorderSide(color: QuantisColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onPressed: () {
              ref
                  .read(quantisAiProvider.notifier)
                  .sendMessage(suggestions[index]);
              _scrollToBottom();
            },
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    final isListening = _voiceState == VoiceState.listening;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: QuantisColors.white,
        border: Border(top: BorderSide(color: QuantisColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Bouton Micro dans la barre d'entrée
            IconButton(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isListening
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: isListening
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: isListening ? Colors.white : const Color(0xFF0077B6),
                  size: 20,
                ),
              ),
              tooltip: isListening ? 'Arrêter écoute' : 'Parler à Quantis',
              onPressed: isLoading ? null : _toggleVoiceInput,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: QuantisColors.bgLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isListening
                        ? const Color(0xFF00E5FF)
                        : QuantisColors.border,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _handleSubmit(),
                  decoration: InputDecoration(
                    hintText: isListening
                        ? 'Écoute en cours... parlez !'
                        : 'Demandez à Quantis (voix ou texte)...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: isListening
                          ? const Color(0xFF0077B6)
                          : QuantisColors.textMuted,
                      fontStyle: isListening ? FontStyle.italic : FontStyle.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: QuantisColors.royalBlue.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: QuantisColors.luxuryGold,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: QuantisColors.white,
                        size: 20,
                      ),
                onPressed: isLoading ? null : _handleSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
