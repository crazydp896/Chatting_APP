import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_providers.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../chat/data/chat_repository.dart';
import '../data/user_repository.dart';
import '../domain/profile.dart';

/// Searchable list of all other users; tapping one opens a conversation.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or username',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Profile>>(
                    key: ValueKey(_query),
                    future: ref.read(userRepositoryProvider).listProfiles(
                          query: _query,
                          excludeId: user.id,
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ErrorView(
                          message: 'Could not load people.',
                          details: '${snapshot.error}',
                          onRetry: () => setState(() {}),
                        );
                      }
                      final profiles = snapshot.data ?? const <Profile>[];
                      if (profiles.isEmpty) {
                        return EmptyView(
                          icon: Icons.people_outline,
                          title: _query.isEmpty ? 'No other users yet' : 'No matches',
                          subtitle: _query.isEmpty
                              ? 'When others sign up, they will appear here.'
                              : 'Try a different search term.',
                        );
                      }
                      return ListView.separated(
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) => const Divider(indent: 76),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          return ListTile(
                            leading: ProfileAvatar(profile: profile, radius: 26),
                            title: Text(
                              profile.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('@${profile.username}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openChat(profile),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openChat(Profile profile) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final conversation = await ref.read(chatRepositoryProvider).openConversation(
            userId: user.id,
            otherId: profile.id,
          );
      if (!mounted) return;
      context.push('/chat/${conversation.id}');
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not start the conversation.')),
      );
    }
  }
}
