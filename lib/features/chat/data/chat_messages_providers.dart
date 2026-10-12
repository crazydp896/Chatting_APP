import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/message.dart';

/// State of one open chat screen: ordered messages (newest first),
/// pagination and realtime appends.
class ChatMessagesState {
  const ChatMessagesState({
    this.messages = const [],
    this.loading = false,
    this.loadingOlder = false,
    this.hasMore = true,
    this.sending = false,
  });

  final List<Message> messages;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;

  /// True while a send is in flight (disables the send button).
  final bool sending;

  ChatMessagesState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    bool? sending,
  }) =>
      ChatMessagesState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        hasMore: hasMore ?? this.hasMore,
        sending: sending ?? this.sending,
      );
}

/// Notifier driving a single conversation screen.
class ChatMessagesNotifier extends FamilyAsyncNotifier<ChatMessagesState, String> {
  StreamSubscription<Message>? _sub;

  String get _conversationId => arg;

  @override
  Future<ChatMessagesState> build(String conversationId) async {
    ref.onDispose(() => _sub?.cancel());
    _sub = ref
        .watch(chatRepositoryProvider)
        .watchMessages(conversationId)
        .listen(_onRealtimeMessage);

    final repo = ref.watch(chatRepositoryProvider);
    final page = await repo.listMessages(conversationId);
    return ChatMessagesState(
      messages: page,
      loading: false,
      hasMore: page.length >= 30,
    );
  }

  void _onRealtimeMessage(Message incoming) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.messages.any((m) => m.id == incoming.id)) return;
    // Newest first: index 0.
    state = AsyncData(
      current.copyWith(messages: [incoming, ...current.messages]),
    );
  }

  /// Sends [content] and optimistically prepends the returned message.
  Future<void> send(String content, String senderId) {
    return _send(content, senderId, type: MessageTypes.text);
  }

  /// Sends an image [url] as an image-type message.
  Future<void> sendImage(String url, String senderId) {
    return _send(url, senderId, type: MessageTypes.image);
  }

  Future<void> _send(String content, String senderId, {required String type}) async {
    final current = state.valueOrNull;
    if (current == null || content.trim().isEmpty) return;

    state = AsyncData(current.copyWith(sending: true));
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: _conversationId,
            senderId: senderId,
            content: content.trim(),
            type: type,
          );
      final latest = state.valueOrNull ?? current;
      if (!latest.messages.any((m) => m.id == message.id)) {
        state = AsyncData(latest.copyWith(
          messages: [message, ...latest.messages],
          sending: false,
        ));
      } else {
        state = AsyncData(latest.copyWith(sending: false));
      }
    } catch (e) {
      state = AsyncData((state.valueOrNull ?? current).copyWith(sending: false));
      rethrow;
    }
  }

  /// Loads the next (older) page and appends it to the tail of the list.
  Future<void> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingOlder || !current.hasMore) return;

    state = AsyncData(current.copyWith(loadingOlder: true));
    final oldest = current.messages.isNotEmpty ? current.messages.last : null;
    final page = await ref.read(chatRepositoryProvider).listMessages(
          _conversationId,
          before: oldest?.createdAt.toUtc().toIso8601String(),
        );
    final latest = state.valueOrNull ?? current;
    state = AsyncData(latest.copyWith(
      messages: [...latest.messages, ...page],
      loadingOlder: false,
      hasMore: page.length >= 30,
    ));
  }

  /// Marks messages from the other user as read.
  Future<void> markRead(String otherId) {
    return ref.read(chatRepositoryProvider).markConversationRead(
          conversationId: _conversationId,
          otherId: otherId,
        );
  }
}

final chatMessagesProvider = AsyncNotifierProvider.family<
    ChatMessagesNotifier, ChatMessagesState, String>(ChatMessagesNotifier.new);
