import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_providers.dart';
import '../domain/profile.dart';

/// Reads/updates `public.profiles`.
class UserRepository {
  UserRepository(this._client);

  final SupabaseClient _client;

  /// All profiles except [excludeId], optionally filtered by [query]
  /// (matches username or display name, case-insensitive).
  Future<List<Profile>> listProfiles({String? query, required String excludeId}) {
    final q = query?.trim();
    PostgrestFilterBuilder<List<Map<String, dynamic>>> builder = _client
        .from('profiles')
        .select()
        .neq('id', excludeId);
    if (q != null && q.isNotEmpty) {
      builder = builder.or('username.ilike.%$q%,full_name.ilike.%$q%');
    }
    return builder.order('username').then((rows) => rows.map(Profile.fromMap).toList());
  }

  Future<Profile?> getProfile(String id) async {
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  Future<void> updateProfile({
    required String id,
    String? fullName,
    String? avatarUrl,
  }) async {
    final values = <String, dynamic>{};
    if (fullName != null) values['full_name'] = fullName;
    if (avatarUrl != null) values['avatar_url'] = avatarUrl;
    await _client.from('profiles').update(values).eq('id', id);
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseProvider));
});
