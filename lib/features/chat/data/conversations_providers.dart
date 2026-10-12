import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';

/// Bumped whenever new message inserts arrive over Realtime so that
/// conversation lists (last-message preview + ordering) refresh.
final _messageTickProvider = StateProvider<int>((ref) => 0);

/// Global Realtime subscription: bumps [_messageTickProvider] on every
/// visible message insert. Kept alive by [chatsProvider].
class _RealtimeWatcher {
  _RealtimeWatcher(this._ref, this._repo) {
    _sub = _repo.watchAllMessageInserts().listen((_) {
      _ref.read(_messageTickProvider.notifier).state++;
    });
  }

  final Ref _ref;
  final ChatRepository _repo;
  late final StreamSubscription<Map<String, dynamic>> _sub;

  void dispose() => _sub.cancel();
}

/// Recent conversations for the signed-in user, newest activity first.
final chatsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  // Keep one realtime watcher alive while this provider is alive.
  final repo = ref.watch(chatRepositoryProvider);
  final watcher = _RealtimeWatcher(ref, repo);
  ref.onDispose(watcher.dispose);

  // Refetch whenever a new message lands anywhere.
  ref.watch(_messageTickProvider);

  return repo.listConversations(user.id);
});

/// Single conversation (chat screen header + other-user info).
final conversationProvider =
    FutureProvider.autoDispose.family<Conversation?, String>((ref, id) {
  return ref.watch(chatRepositoryProvider).getConversation(id);
});
