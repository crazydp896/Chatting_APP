import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// The initialized Supabase client.
///
/// Throws if the app was launched without `--dart-define` credentials —
/// the root widget prevents reaching this state by showing a configuration
/// screen instead (see [AppConfig.isSupabaseConfigured]).
final supabaseProvider = Provider<SupabaseClient>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    throw StateError(
      'Supabase is not configured. Launch with '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  return Supabase.instance.client;
});

/// Emits every auth event (signed in, signed out, token refreshed, ...).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// The currently signed-in user, or null. Rebuilds on auth changes.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});
