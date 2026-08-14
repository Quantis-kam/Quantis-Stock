import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/features/auth/presentation/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('Affiche les champs email et mot de passe', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(onLoginSuccess: () {}),
      ));

      expect(find.text('Quantis Stock'), findsOneWidget);
      expect(find.text('Connectez-vous pour continuer'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('Validation: champs vides', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(onLoginSuccess: () {}),
      ));

      // Vider le champ email (pré-rempli)
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, '');

      await tester.tap(find.text('Se connecter'));
      await tester.pump();

      expect(find.text('Email requis'), findsOneWidget);
      expect(find.text('Mot de passe requis'), findsOneWidget);
    });

    testWidgets('Toggle visibilité mot de passe', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(onLoginSuccess: () {}),
      ));

      // Le champ password est obscure par défaut
      final passwordField = find.byType(TextFormField).last;
      expect(passwordField, findsOneWidget);

      // Toggle visibility
      final visibilityIcon = find.byIcon(Icons.visibility_off);
      expect(visibilityIcon, findsOneWidget);
      await tester.tap(visibilityIcon);
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });
}
