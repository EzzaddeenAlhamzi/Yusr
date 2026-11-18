import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'voice/voice_demo_page.dart';

/// Isolated Track B entry — NOT the production Yusr `lib/main.dart`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArabicVoiceFeasibilityApp());
}

class ArabicVoiceFeasibilityApp extends StatelessWidget {
  const ArabicVoiceFeasibilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yusr Voice Feasibility (NON-PROD)',
      debugShowCheckedModeBanner: true,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4B3A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const VoiceDemoPage(),
    );
  }
}
