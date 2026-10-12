import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../data/conversations_providers.dart';
import '../domain/conversation.dart';

/// Root tab: recent conversations with search + sign-out.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => context.push('/people'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  context.push('/profile');
                case 'sign_out':
                  await ref.read(authRepositoryProvider).signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'sign_out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: chatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: 'Could not load your conversations.',
                details: '$e',
                onRetry: () => ref.invalidate(chatsProvider),
              ),
              data: (chats) {
                final filtered = _query.isEmpty
                    ? chats
                    : chats
                        .where((c) =>
                            c.otherUser.displayName.toLowerCase().contains(_query) ||
                            c.otherUser.username.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return EmptyView(
                    icon: Icons.chat_outlined,
                    title: _query.isEmpty ? 'No chats yet' : 'No matches',
                    subtitle: _query.isEmpty
                        ? 'Tap + to find people and start a conversation.'
                        : 'Try a different search term.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(chatsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(indent: 76),
                    itemBuilder: (context, index) =>
                        _ConversationTile(conversation: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/people'),
        tooltip: 'New chat',
        child: const Icon(Icons.chat),
      ),
    );
  }
}

/// One row in the chats list: avatar, name, last-message preview, time.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = conversation.lastMessage;

    final preview = last == null
        ? 'Say hello 👋'
        : last.type == 'image'
            ? '📷 Photo'
            : last.content;

    return ListTile(
      leading: ProfileAvatar(profile: conversation.otherUser, radius: 26),
      title: Text(
        conversation.otherUser.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            TimeFormat.listTimestamp(conversation.lastMessageAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      onTap: () => context.push('/chat/${conversation.id}'),
    );
  }
}

