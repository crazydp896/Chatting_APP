/// Message types supported by the app.
abstract final class MessageTypes {
  static const String text = 'text';
  static const String image = 'image';
}

/// A row of `public.messages`.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.type = MessageTypes.text,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  Message copyWith({String? id, DateTime? createdAt, DateTime? readAt}) => Message(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        type: type,
        createdAt: createdAt ?? this.createdAt,
        readAt: readAt ?? this.readAt,
      );

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        senderId: map['sender_id'] as String,
        content: map['content'] as String,
        type: map['type'] as String? ?? MessageTypes.text,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        readAt: map['read_at'] == null ? null : DateTime.parse(map['read_at'] as String).toLocal(),
      );

  Map<String, dynamic> toMap() => {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'type': type,
      };
}
