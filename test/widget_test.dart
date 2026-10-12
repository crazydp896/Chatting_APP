import 'package:chattingapp/main.dart';
import 'package:chattingapp/shared/widgets/missing_config_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The test environment launches without --dart-define credentials,
/// so the app must show the configuration screen instead of crashing.
void main() {
  testWidgets('shows configuration screen when Supabase is not configured',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ChattingApp()));
    await tester.pump();

    expect(find.byType(MissingConfigScreen), findsOneWidget);
    expect(find.textContaining('flutter run'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
