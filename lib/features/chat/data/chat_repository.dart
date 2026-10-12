import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_providers.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';

/// Reads/writes `public.conversations` and `public.messages`.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// The shared select used for conversation lists: the row plus the other
  /// participant's profile and the last message (from the summary view).
  static const _summarySelect = '''
      id, user_a_id, user_b_id, last_message_at, created_at,
      other_user, last_message''';

  /// Recent conversations for [userId], newest activity first.
  Future<List<Conversation>> listConversations(String userId) async {
    final rows = await _client
        .from('conversation_summaries')
        .select(_summarySelect)
        .order('last_message_at', ascending: false);
    return rows
        .map((row) => Conversation.fromSummaryMap(row))
        .where((c) => c.involves(userId))
        .toList();
  }

  /// Opens (or creates) the 1:1 conversation between [userId] and [otherId].
  Future<Conversation> openConversation({
    required String userId,
    required String otherId,
  }) async {
    final response = await _client.rpc('get_or_create_conversation', params: {
      'other_user_id': otherId,
    });
    final row = Map<String, dynamic>.from(response as Map);
    return Conversation.fromSummaryMap(row);
  }

  Future<Conversation?> getConversation(String id) async {
    final row = await _client
        .from('conversation_summaries')
        .select(_summarySelect)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Conversation.fromSummaryMap(row);
  }

  /// Latest [limit] messages of [conversationId], newest first
  /// (ready for a `reverse: true` ListView).
  Future<List<Message>> listMessages(
    String conversationId, {
    String? before,
    int limit = 30,
  }) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> builder = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);
    if (before != null) {
      builder = builder.lt('created_at', before);
    }
    final rows = await builder.order('created_at', ascending: false).limit(limit);
    return rows.map(Message.fromMap).toList();
  }

  /// Sends a message. Returns the stored row (with server-generated id/timestamps).
  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String type = MessageTypes.text,
  }) async {
    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'content': content,
          'type': type,
        })
        .select()
        .single();
    return Message.fromMap(row);
  }

  /// Marks all messages in [conversationId] sent by [otherId] as read.
  Future<void> markConversationRead({
    required String conversationId,
    required String otherId,
  }) async {
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('sender_id', otherId)
        .isFilter('read_at', null);
  }

  /// Live stream of new messages for one conversation (inserts only).
  Stream<Message> watchMessages(String conversationId) {
    final controller = StreamController<Message>();
    final channel = _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            if (!controller.isClosed) controller.add(Message.fromMap(payload.newRecord));
          },
        );
    channel.subscribe();
    controller.onCancel = () => channel.unsubscribe();
    return controller.stream;
  }

  /// Realtime stream: emits whenever any message the current scope can see
  /// is inserted. The UI filters by conversation.
  Stream<Map<String, dynamic>> watchAllMessageInserts() {
    final controller = StreamController<Map<String, dynamic>>();
    final channel = _client
        .channel('global-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (!controller.isClosed) controller.add(payload.newRecord);
          },
        );
    channel.subscribe();
    controller.onCancel = () => channel.unsubscribe();
    return controller.stream;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseProvider));
});
