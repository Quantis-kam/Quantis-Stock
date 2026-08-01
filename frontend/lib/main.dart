import 'package:flutter/material.dart';
import 'core/theme/quantis_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuantisStockApp());
}

class QuantisStockApp extends StatelessWidget {
  const QuantisStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantis Stock',
      debugShowCheckedModeBanner: false,
      theme: QuantisTheme.lightTheme,
      darkTheme: QuantisTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

/// Écran de démarrage temporaire (Phase 1).
/// Sera remplacé par le router go_router en Phase 2.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Q
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: QuantisColors.royalBlue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text(
                  'Q',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'QUANTIS STOCK',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: QuantisColors.royalBlue,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gestion de Stock Intelligente',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: QuantisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: QuantisColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  QuantisColors.luxuryGold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
