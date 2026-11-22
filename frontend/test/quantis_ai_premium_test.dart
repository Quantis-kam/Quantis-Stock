import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/core/constants/app_constants.dart';
import 'package:quantis_stock/features/quantis_ai/presentation/quantis_ai_launcher.dart';
import 'package:quantis_stock/features/quantis_ai/presentation/quantis_ai_premium_view.dart';
import 'package:quantis_stock/features/quantis_ai/services/quantis_voice_service.dart';

void main() {
  test('Quantis AI est verrouillé en mode Premium par défaut', () {
    expect(AppConstants.isQuantisAiPremiumEnabled, isFalse);
  });

  test('QuantisVoiceService ne démarre pas l\'écoute quand Premium IA est désactivé', () {
    final voice = QuantisVoiceService();
    voice.initJarvisMode();
    expect(voice.state, VoiceState.standby);

    voice.startListening();
    expect(voice.state, VoiceState.standby);
  });

  testWidgets('QuantisAiScreen affiche l\'écran Premium et aucun bouton micro', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuantisAiScreen(),
      ),
    );

    expect(find.byType(QuantisAiPremiumView), findsOneWidget);
    expect(find.text('OFFRE QUANTIS PRO IA'), findsOneWidget);
    expect(find.text('Passer à l\'abonnement Premium'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });
}

