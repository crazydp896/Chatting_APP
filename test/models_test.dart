import 'package:chattingapp/features/chat/domain/message.dart';
import 'package:chattingapp/features/users/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile', () {
    const createdAt = '2026-01-05T10:00:00+00:00';

    test('fromMap parses a profiles row', () {
      final profile = Profile.fromMap({
        'id': 'u1',
        'username': 'alice_99',
        'full_name': 'Alice Wonder',
        'avatar_url': null,
        'last_seen': '2026-01-06T08:30:00+00:00',
        'created_at': createdAt,
      });

      expect(profile.id, 'u1');
      expect(profile.username, 'alice_99');
      expect(profile.displayName, 'Alice Wonder');
      expect(profile.avatarUrl, isNull);
      expect(profile.lastSeen, isNotNull);
      expect(profile.createdAt.isUtc, isFalse); // converted to local
    });

    test('displayName falls back to username when full name missing', () {
      final profile = Profile.fromMap({
        'id': 'u1',
        'username': 'bob',
        'full_name': '   ',
        'created_at': createdAt,
      });
      expect(profile.displayName, 'bob');
    });

    test('initials uses first letters of first and last name', () {
      final profile = Profile.fromMap({
        'id': 'u1',
        'username': 'carol',
        'full_name': 'Carol Danvers',
        'created_at': createdAt,
      });
      expect(profile.initials, 'CD');
    });

    test('initials handles single-word display name', () {
      final profile = Profile.fromMap({
        'id': 'u1',
        'username': 'dave',
        'created_at': createdAt,
      });
      expect(profile.initials, 'D');
    });
  });

  group('Message', () {
    test('fromMap parses a messages row with defaults', () {
      final message = Message.fromMap({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content': 'Hello!',
        'created_at': '2026-01-05T10:00:00+00:00',
      });

      expect(message.id, 'm1');
      expect(message.type, MessageTypes.text);
      expect(message.isRead, isFalse);
    });

    test('isRead is true only when read_at set', () {
      final message = Message.fromMap({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content': 'Hi',
        'created_at': '2026-01-05T10:00:00+00:00',
        'read_at': '2026-01-05T10:05:00+00:00',
      });
      expect(message.isRead, isTrue);
    });

    test('copyWith overrides only provided fields', () {
      final message = Message.fromMap({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content': 'Hi',
        'created_at': '2026-01-05T10:00:00+00:00',
      });
      final updated = message.copyWith(id: 'server-id');

      expect(updated.id, 'server-id');
      expect(updated.conversationId, message.conversationId);
      expect(updated.content, message.content);
    });

    test('toMap excludes server-generated fields', () {
      final message = Message.fromMap({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content': 'Hi',
        'created_at': '2026-01-05T10:00:00+00:00',
      });
      final map = message.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
      expect(map['conversation_id'], 'c1');
      expect(map['type'], MessageTypes.text);
    });
  });
}
