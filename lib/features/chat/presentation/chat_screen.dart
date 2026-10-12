import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/supabase_providers.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../data/chat_messages_providers.dart';
import '../data/conversations_providers.dart';
import '../data/storage_repository.dart';
import '../data/typing_watcher.dart';
import '../domain/message.dart';
import 'message_bubble.dart';

/// One open conversation: header, message list, composer.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _uploadingImage = false;
  DateTime? _otherTypingAt;
  DateTime _lastPingAt = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<DateTime?>? _typingSub;
  TypingWatcher? _typingWatcher;

  @override
  void initState() {
    super.initState();
    // Mark the other party's messages as read when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
      _subscribeTyping();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typingSub?.cancel();
    _typingWatcher?.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Listens for the other user's typing pings (once the conversation —
  /// and therefore the other user's id — has loaded).
  void _subscribeTyping() {
    final conversation =
        ref.read(conversationProvider(widget.conversationId)).valueOrNull;
    final user = ref.read(currentUserProvider);
    if (conversation == null || user == null) return;

    // Hold the watcher directly in widget state rather than via an
    // autoDispose provider: a `ref.read` of an unlistened autoDispose
    // family would be scheduled for disposal at end of frame, closing the
    // channel immediately. Tying it to the State keeps it alive until the
    // screen is popped, where [dispose] tears it down.
    final watcher = TypingWatcher(
      ref.read(supabaseProvider),
      widget.conversationId,
      user.id,
    );
    _typingWatcher = watcher;
    _typingSub = watcher.events.listen((at) {
      if (mounted) setState(() => _otherTypingAt = at);
    });
  }

  /// Throttled typing ping fired on each composer change.
  void _onComposerChanged() {
    setState(() {});
    final now = DateTime.now();
    if (now.difference(_lastPingAt).inMilliseconds > 1500) {
      _lastPingAt = now;
      _typingWatcher?.ping();
    }
  }

  void _onScroll() {
    // At the top of a reverse list => oldest visible => load more history.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  Future<void> _markRead() async {
    final conversation =
        ref.read(conversationProvider(widget.conversationId)).valueOrNull;
    if (conversation == null) return;
    await ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .markRead(conversation.otherUser.id);
  }

  Future<void> _send() async {
    final text = _inputController.text;
    final user = ref.read(currentUserProvider);
    if (user == null || text.trim().isEmpty) return;
    _inputController.clear();
    try {
      await ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .send(text, user.id);
      _markRead();
      ref.invalidate(chatsProvider); // refresh preview ordering
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message failed to send. Tap send to retry.')),
        );
        _inputController.text = text; // restore draft
      }
    }
  }

  /// Picks an image from the gallery, uploads it to Storage and sends it
  /// as an image-type message.
  Future<void> _sendImage() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      if (mounted) setState(() => _uploadingImage = true);
      final url = await ref.read(storageRepositoryProvider).uploadChatImage(
            file: File(picked.path),
            ownerId: user.id,
          );
      await ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .sendImage(url, user.id);
      _markRead();
      ref.invalidate(chatsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync = ref.watch(conversationProvider(widget.conversationId));
    final chatAsync = ref.watch(chatMessagesProvider(widget.conversationId));

    // The other user's id only becomes known once the conversation loads;
    // subscribe to typing pings at that point.
    final conversation = conversationAsync.valueOrNull;
    if (conversation != null && _typingSub == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _typingSub == null) _subscribeTyping();
      });
    }

    final otherName = conversation?.otherUser.displayName;
    final showTyping = _otherTypingAt != null &&
        DateTime.now().difference(_otherTypingAt!) < const Duration(seconds: 4);

    return Scaffold(
      appBar: AppBar(
        title: conversationAsync.when(
          loading: () => const Text('Chat'),
          error: (_, _) => const Text('Chat'),
          data: (conversation) => Row(
            children: [
              if (conversation != null) ...[
                ProfileAvatar(profile: conversation.otherUser, radius: 18),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: showTyping
                    ? Text(
                        '$otherName is typing…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                        ),
                      )
                    : Text(
                        conversation?.otherUser.displayName ?? 'Chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(chatMessagesProvider(widget.conversationId)),
                  child: const Text('Retry'),
                ),
              ),
              data: (state) {
                if (state.messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet — say hello!'),
                  );
                }
                return _MessageList(
                  state: state,
                  scrollController: _scrollController,
                  isMine: (m) => m.senderId == ref.watch(currentUserProvider)?.id,
                );
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _inputController.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Send photo',
              icon: _uploadingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_outlined),
              onPressed: _uploadingImage ? null : _sendImage,
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onChanged: (_) => _onComposerChanged(),
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Type a message…'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: FilledButton(
                onPressed: canSend ? _send : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.send_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reverse-list message thread with day separators and pagination spinner.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.scrollController,
    required this.isMine,
  });

  final ChatMessagesState state;
  final ScrollController scrollController;
  final bool Function(Message) isMine;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages; // newest first
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (state.loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.loadingOlder && index == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final message = messages[index];
        // In a reversed list index+1 is older (chronologically previous).
        final older = index + 1 < messages.length ? messages[index + 1] : null;
        final showSeparator =
            TimeFormat.isNewDay(older?.createdAt, message.createdAt);
        // Tail bubble = last of its run (the next-newer differs or none).
        final newer = index > 0 ? messages[index - 1] : null;
        final showTail = newer == null || newer.senderId != message.senderId;

        return Column(
          children: [
            if (showSeparator)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      TimeFormat.daySeparator(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            MessageBubble(
              message: message,
              isMine: isMine(message),
              showTail: showTail,
            ),
          ],
        );
      },
    );
  }
}


