/// Remplace ces valeurs par celles de ton projet Supabase.
/// Dashboard Supabase → Settings → API
class SupabaseConfig {
  static const String url = 'https://qzofoftfdomhlodawhlf.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6b2ZvZnRmZG9taGxvZGF3aGxmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNzczMzIsImV4cCI6MjA5MzY1MzMzMn0.BxoQz8C-9nGOutHugXJ0tBR9_wTmp7Ucq0Yu4lNX_1c';
}

/// Configuration du backend IA/ML prédictif
class BackendConfig {
  // Déployer le backend Python sur Render.com ou Railway.app
  // puis mettre à jour cette URL
  static const String baseUrl = 'https://depgest-predictive.onrender.com';
  // Pour localhost: 'http://localhost:8000'

  static const Duration timeout = Duration(seconds: 30);
  static const Duration cacheTtl = Duration(hours: 24);
  static const int retryCount = 2;
}
