import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../data/user_repository.dart';
import '../domain/profile.dart';

/// The signed-in user's own profile row (null when signed out).
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(userRepositoryProvider).getProfile(user.id);
});

/// All profiles except the current user, optionally filtered by [query].
final profilesSearchProvider =
    FutureProvider.family<List<Profile>, String>((ref, query) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(userRepositoryProvider).listProfiles(
        query: query,
        excludeId: user.id,
      );
});
