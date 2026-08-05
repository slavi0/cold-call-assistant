import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'features/contacts/models/contact_model.dart';
import 'features/calls/models/call_model.dart';
import 'features/recordings/models/recording_model.dart';
import 'features/excel_import/models/excel_table_model.dart';

import 'features/contacts/services/contact_service.dart';
import 'features/calls/services/call_service.dart';
import 'features/recordings/services/recording_service.dart';
import 'features/excel_import/services/excel_table_service.dart';
import 'features/contact_sources/services/contact_source_service.dart';

import 'features/contacts/providers/contact_provider.dart';
import 'features/calls/providers/phone_call_provider.dart';
import 'features/calls/providers/calling_sequence_provider.dart';
import 'features/contact_sources/providers/contact_source_provider.dart';

import 'features/calls/views/home_screen.dart';
import 'features/contacts/views/contacts_screen.dart';
import 'features/contacts/views/contact_detail_screen.dart';
import 'features/contacts/views/post_call_review_screen.dart';
import 'features/contact_sources/views/contact_sources_screen.dart';
import 'features/contact_sources/views/google_sheets_config_screen.dart';

/// Schema version for the contacts Hive box.
///
/// Increment this constant whenever:
/// - A [ContactModel] field is added or removed.
/// - The [ContactStatus] enum values are reordered or replaced.
///
/// On a version mismatch, the contacts box is cleared and re-seeded so
/// existing data with incompatible indices is not misread.
const _contactsSchemaVersion = 2;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Hive with the Flutter path provider so it resolves the
  // correct documents directory on each platform.
  await Hive.initFlutter();

  // Register all type adapters before opening any box.
  // TypeId allocation:
  //   0  ContactModel
  //   1  CallModel
  //   2  RecordingModel
  //   3  ExcelTableModel
  //  10  ContactStatus (enum)
  //  11  CallDirection  (enum)
  //  12  CallOutcome    (enum)
  //  13  TranscriptStatus (enum)
  Hive
    ..registerAdapter(ContactModelAdapter())
    ..registerAdapter(ContactStatusAdapter())
    ..registerAdapter(CallModelAdapter())
    ..registerAdapter(CallDirectionAdapter())
    ..registerAdapter(CallOutcomeAdapter())
    ..registerAdapter(RecordingModelAdapter())
    ..registerAdapter(TranscriptStatusAdapter())
    ..registerAdapter(ExcelTableModelAdapter());

  // Open all feature boxes at startup so services can access them synchronously.
  await Future.wait([
    ContactService.openBox(),
    CallService.openBox(),
    RecordingService.openBox(),
    ExcelTableService.openBox(),
    ContactSourceService.openBox(),
  ]);

  // ── Schema migration ──────────────────────────────────────────────────────
  // A primitive int box stores schema version numbers (no adapter needed).
  // If the stored version doesn't match _contactsSchemaVersion, the contacts
  // box is cleared so old records with incompatible enum indices are removed.
  // The ContactProvider will re-seed on next startup.
  final schemaBox = await Hive.openBox<int>('schema');
  final storedVersion = schemaBox.get('contacts') ?? 0;
  if (storedVersion != _contactsSchemaVersion) {
    await Hive.box<ContactModel>('contacts').clear();
    await schemaBox.put('contacts', _contactsSchemaVersion);
  }

  runApp(const ColdCallAssistantApp());
}


class ColdCallAssistantApp extends StatelessWidget {
  const ColdCallAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PhoneCallProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CallingSequenceProvider()),
        // ContactProvider seeds + loads contacts on creation.
        ChangeNotifierProvider(
          create: (_) => ContactProvider()..seedAndLoad(),
        ),
        // ContactSourceProvider loads configured sources on creation.
        ChangeNotifierProvider(
          create: (_) => ContactSourceProvider()..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Cold Call Assistant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        // Named routes keep navigation declarative and testable.
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/contacts': (_) => const ContactsScreen(),
          '/contact-detail': (_) => const ContactDetailScreen(),
          '/post-call-review': (_) => const PostCallReviewScreen(),
          '/settings': (_) => const ContactSourcesScreen(),
          '/settings/google-sheets': (_) => const GoogleSheetsConfigScreen(),
        },
      ),
    );
  }
}
