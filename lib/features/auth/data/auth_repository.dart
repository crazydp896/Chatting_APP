import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_providers.dart';

/// Result of a sign-up attempt: Supabase may require email confirmation
/// before a session exists, which the UI must communicate differently.
class SignUpResult {
  const SignUpResult._({required this.needsEmailConfirmation});

  const SignUpResult.signedIn() : this._(needsEmailConfirmation: false);
  const SignUpResult.emailConfirmationSent() : this._(needsEmailConfirmation: true);

  final bool needsEmailConfirmation;
}

/// Auth operations over Supabase Auth.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'username': username.trim(),
        if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
      },
    );
    // session == null means email confirmation is required before sign-in.
    return response.session == null
        ? const SignUpResult.emailConfirmationSent()
        : const SignUpResult.signedIn();
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException {
      // Sign-out is best-effort; a stale local session is cleared anyway.
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});
