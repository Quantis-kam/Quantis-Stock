import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/quantis_theme.dart';
import '../models/chat_ui_message.dart';
import '../../services/quantis_voice_service.dart';

class QuantisChatBubble extends StatelessWidget {
  final ChatUiMessage message;
  final Function(String suggestion)? onSuggestionSelected;

  const QuantisChatBubble({
    super.key,
    required this.message,
    this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _buildAssistantAvatar(),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [
                              QuantisColors.royalBlue,
                              QuantisColors.blueLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : (message.isError
                            ? QuantisColors.error.withValues(alpha: 0.08)
                            : QuantisColors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: message.isError
                                ? QuantisColors.error.withValues(alpha: 0.3)
                                : QuantisColors.border,
                            width: 1,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Quantis',
                              style: TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: QuantisColors.royalBlue,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: QuantisColors.luxuryGold
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'AI STOCK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: QuantisColors.goldDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!isUser) const SizedBox(height: 6),
                      _buildFormattedContent(isUser),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: isUser
                                  ? Colors.white70
                                  : QuantisColors.textMuted,
                            ),
                          ),
                          if (!isUser) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                QuantisVoiceService().speak(message.text);
                              },
                              child: const Icon(
                                Icons.volume_up_rounded,
                                size: 14,
                                color: QuantisColors.royalBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: message.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Texte copié !'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: QuantisColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                _buildUserAvatar(),
              ],
            ],
          ),
          if (!isUser && message.suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 40.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.suggestions.map((suggestion) {
                  return ActionChip(
                    avatar: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: QuantisColors.royalBlue,
                    ),
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: QuantisColors.royalBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: QuantisColors.white,
                    side: const BorderSide(
                      color: QuantisColors.border,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () => onSuggestionSelected?.call(suggestion),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssistantAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [QuantisColors.royalBlue, QuantisColors.blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: QuantisColors.luxuryGold.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: QuantisColors.royalBlue.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Q',
          style: TextStyle(
            color: QuantisColors.luxuryGold,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'SpaceGrotesk',
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: QuantisColors.luxuryGold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: QuantisColors.luxuryGold,
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: QuantisColors.royalBlue,
        size: 18,
      ),
    );
  }

  Widget _buildFormattedContent(bool isUser) {
    final textColor = isUser ? QuantisColors.white : QuantisColors.textPrimary;
    final lines = message.text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();

        // Titre niveau 1 ou 2 (# Titre ou ## Titre)
        if (trimmed.startsWith('# ') || trimmed.startsWith('## ')) {
          final headerText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              headerText,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isUser ? Colors.white : QuantisColors.royalBlue,
              ),
            ),
          );
        }

        // Ligne de tableau Markdown (| col1 | col2 |)
        if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
          if (trimmed.contains('---')) {
            return const Divider(height: 8, thickness: 0.8);
          }
          final cells = trimmed
              .split('|')
              .where((c) => c.isNotEmpty)
              .map((c) => c.trim())
              .toList();

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              children: cells.map((cell) {
                final isHeader = line.contains('**');
                return Expanded(
                  child: Text(
                    cell.replaceAll('**', ''),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
                      color: isUser ? Colors.white : QuantisColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        // Puces (- item ou * item)
        if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          final itemText = trimmed.substring(2);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: isUser
                        ? QuantisColors.luxuryGold
                        : QuantisColors.royalBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: _buildRichInlineText(itemText, textColor),
                ),
              ],
            ),
          );
        }

        // Ligne normale
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: _buildRichInlineText(line, textColor),
        );
      }).toList(),
    );
  }

  Widget _buildRichInlineText(String text, Color defaultColor) {
    // Parser les **gras** et *italique*
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: defaultColor, fontSize: 13.5, height: 1.4),
        ));
      }

      if (match.group(2) != null) {
        // Gras **text**
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            color: defaultColor,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
      } else if (match.group(3) != null) {
        // Italique *text*
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(
            color: defaultColor,
            fontStyle: FontStyle.italic,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
      } else if (match.group(4) != null) {
        // Code `text`
        spans.add(TextSpan(
          text: match.group(4),
          style: const TextStyle(
            fontFamily: 'monospace',
            backgroundColor: Color(0x22000000),
            fontSize: 12.5,
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: defaultColor, fontSize: 13.5, height: 1.4),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
