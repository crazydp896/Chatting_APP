import 'package:chattingapp/features/chat/domain/message.dart';
import 'package:chattingapp/features/chat/presentation/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Message _message({String content = 'Hello there', bool read = false}) => Message(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'me',
      content: content,
      createdAt: DateTime(2026, 1, 5, 14, 30),
      readAt: read ? DateTime(2026, 1, 5, 14, 31) : null,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('renders message content and time', (tester) async {
    await _pump(tester, MessageBubble(message: _message(), isMine: false));

    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('aligns own messages right and others left', (tester) async {
    await _pump(tester, MessageBubble(message: _message(), isMine: true));
    final own = tester.getCenter(find.text('Hello there'));
    final ownRight = own.dx;

    await _pump(tester, MessageBubble(message: _message(), isMine: false));
    final other = tester.getCenter(find.text('Hello there'));
    final otherLeft = other.dx;

    expect(ownRight, greaterThan(otherLeft));
  });

  testWidgets('shows double check for read messages', (tester) async {
    await _pump(tester, MessageBubble(message: _message(read: true), isMine: true));
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('shows single check when unread', (tester) async {
    await _pump(tester, MessageBubble(message: _message(read: false), isMine: true));
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('no receipt icons on incoming messages', (tester) async {
    await _pump(tester, MessageBubble(message: _message(read: true), isMine: false));
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.done), findsNothing);
  });
}
