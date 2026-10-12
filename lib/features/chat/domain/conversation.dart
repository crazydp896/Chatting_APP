import 'message.dart';
import '../../users/domain/profile.dart';

/// A 1:1 conversation row (`public.conversations`), enriched with the
/// other participant's profile and the last message for list previews.
///
/// The pair is stored canonically (`user_a_id < user_b_id`) so a given pair
/// of users maps to exactly one conversation row.
class Conversation {
  const Conversation({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.lastMessageAt,
    required this.createdAt,
    required this.otherUser,
    this.lastMessage,
  });

  final String id;
  final String userAId;
  final String userBId;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  /// The participant who is *not* the current user.
  final Profile otherUser;

  /// Most recent message, if the conversation has any.
  final Message? lastMessage;

  bool involves(String userId) => userAId == userId || userBId == userId;

  Conversation copyWith({DateTime? lastMessageAt, Message? lastMessage}) => Conversation(
        id: id,
        userAId: userAId,
        userBId: userBId,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        createdAt: createdAt,
        otherUser: otherUser,
        lastMessage: lastMessage ?? this.lastMessage,
      );

  /// Builds a [Conversation] from a row of the `conversation_summaries` view.
  ///
  /// Expects `other_user` (jsonb) and `last_message` (jsonb) embeds produced
  /// by the view defined in `supabase/migrations/`.
  factory Conversation.fromSummaryMap(Map<String, dynamic> map) {
    final otherUser = map['other_user'];
    final lastMessage = map['last_message'];
    return Conversation(
      id: map['id'] as String,
      userAId: map['user_a_id'] as String,
      userBId: map['user_b_id'] as String,
      lastMessageAt: DateTime.parse(map['last_message_at'] as String).toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      otherUser: Profile.fromMap(Map<String, dynamic>.from(otherUser as Map)),
      lastMessage: lastMessage == null
          ? null
          : Message.fromMap(Map<String, dynamic>.from(lastMessage as Map)),
    );
  }
}
