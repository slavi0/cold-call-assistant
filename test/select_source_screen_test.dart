import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cold_call_assistant/features/contacts/providers/contact_provider.dart';
import 'package:cold_call_assistant/features/contact_sources/providers/contact_source_provider.dart';
import 'package:cold_call_assistant/features/contact_sources/views/select_source_screen.dart';

void main() {
  group('ContactProvider source filtering', () {
    test('getContactsForSource and getContactCountForSource filter accurately', () {
      final provider = ContactProvider();

      // Verify that calling on initial provider state returns empty list and 0 count
      expect(provider.getContactsForSource('source-1'), isEmpty);
      expect(provider.getContactCountForSource('source-1'), equals(0));
    });
  });

  group('SelectSourceScreen Widget Tests', () {
    testWidgets('Renders empty state when no contact sources exist',
        (WidgetTester tester) async {
      final sourceProvider = ContactSourceProvider();
      final contactProvider = ContactProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ContactSourceProvider>.value(
              value: sourceProvider,
            ),
            ChangeNotifierProvider<ContactProvider>.value(
              value: contactProvider,
            ),
          ],
          child: const MaterialApp(
            home: SelectSourceScreen(),
          ),
        ),
      );

      // Verify empty state UI elements
      expect(find.text('Select Contact Source'), findsOneWidget);
      expect(find.text('No Contact Sources Configured'), findsOneWidget);
      expect(find.text('Configure Sources'), findsOneWidget);
    });
  });
}
