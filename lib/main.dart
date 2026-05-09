import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Anonymous auth gives every installation a Supabase user_id for RLS.
  // Enable "Anonymous sign-ins" in Supabase Auth settings.
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentSession == null) {
    try {
      await supabase.auth.signInAnonymously();
    } catch (e) {
      debugPrint('[Supabase] Anonymous sign-in failed: $e');
    }
  }

  SyncService.instance.init();

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
      home: const HomeScreen(),
    );
  }
}
