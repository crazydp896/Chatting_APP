import 'package:chattingapp/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LoginScreen())),
      ),
    );
  }

  testWidgets('shows validation errors when submitting empty form',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('rejects malformed email', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('password field toggles visibility', (tester) async {
    await pumpLogin(tester);

    final passwordField = find.byType(TextFormField).last;
    final editable = find.descendant(of: passwordField, matching: find.byType(EditableText));

    // Initially obscured, so the suffix shows the "off" icon.
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(tester.widget<EditableText>(editable).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });
}
