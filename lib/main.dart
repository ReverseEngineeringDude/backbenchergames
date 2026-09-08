import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/auth/auth_service.dart';
import 'core/plugin/game_registry.dart';
import 'games/tic_tac_toe/tic_tac_toe_plugin.dart';
import 'platform/screens/home_screen.dart';
import 'platform/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the provided options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error (running in offline/local fallback): $e');
  }

  // Register game plugins to the platform registry
  GameRegistry().register(TicTacToePlugin());

  // Initialize Auth Service
  await AuthService().initialize();

  runApp(
    const ProviderScope(
      child: BackbenchGamesApp(),
    ),
  );
}

class BackbenchGamesApp extends StatelessWidget {
  const BackbenchGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Backbench Games',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
