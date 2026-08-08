import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retailflow_pos/app.dart';

void main() {
  testWidgets('login opens the application', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RetailFlowApp()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
