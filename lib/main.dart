import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const DepGestApp());
}

class DepGestApp extends StatelessWidget {
  const DepGestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DepGest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
      home: const _AppEntry(),
    );
  }
}

/// Point d'entrée intelligent : redirige vers Auth ou Home selon la session.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  void initState() {
    super.initState();
    // Écoute les changements d'état d'authentification en temps réel
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final session = data.session;
      if (session != null) {
        // Utilisateur connecté → réinitialiser les erreurs de sync
        // puis démarrer la sync (important après changement de compte)
        SyncService.instance.resetSyncErrors().then((_) {
          SyncService.instance.init();
        });
      }
    });

    // Si session déjà active au démarrage, lancer la sync
    if (Supabase.instance.client.auth.currentSession != null) {
      SyncService.instance.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const HomeScreen();
    }
    return const AuthScreen();
  }
}
