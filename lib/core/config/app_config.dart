/// Compile-time configuration injected with `--dart-define`, e.g.:
///
/// ```sh
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
abstract final class AppConfig {
  /// Display name shown in the app bar / task switcher.
  static const String appName = 'Chat App';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether the app has been given Supabase credentials.
  /// When false the app boots into a "configuration needed" screen
  /// instead of crashing on an empty URL.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
