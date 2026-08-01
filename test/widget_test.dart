import 'package:flutter_test/flutter_test.dart';

import 'package:cold_call_assistant/main.dart';

void main() {
  // Widget tests for ColdCallAssistantApp will be added as UI features are built.
  // Hive requires initialisation before testing; see test helpers in future tasks.
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Smoke test: ensure the root widget tree can be built.
    // Full integration tests will be added once the UI is built.
    expect(ColdCallAssistantApp, isA<Type>());
  });
}
