import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'features/contacts/models/contact_model.dart';
import 'features/contacts/models/contact_status.dart';
import 'features/contacts/models/sync_status.dart';
import 'features/calls/models/call_model.dart';
import 'features/calls/models/call_direction.dart';
import 'features/calls/models/call_outcome.dart';
import 'features/recordings/models/recording_model.dart';
import 'features/recordings/models/transcript_status.dart';
import 'features/excel_import/models/excel_table_model.dart';

import 'features/contacts/services/contact_service.dart';
import 'features/calls/services/call_service.dart';
import 'features/recordings/services/recording_service.dart';
import 'features/excel_import/services/excel_table_service.dart';
import 'features/contact_sources/services/contact_source_service.dart';
import 'features/contact_sources/services/google_sheets_integration.dart';
import 'features/contact_sources/services/google_sheets_sync_adapter.dart';

import 'features/contacts/providers/contact_provider.dart';
import 'features/calls/providers/phone_call_provider.dart';
import 'features/calls/providers/calling_sequence_provider.dart';
import 'features/contact_sources/providers/contact_source_provider.dart';
import 'features/contact_sources/providers/contact_import_provider.dart';
import 'features/contact_sources/providers/sync_provider.dart';

import 'features/calls/views/home_screen.dart';
import 'features/contacts/views/contacts_screen.dart';
import 'features/contacts/views/contact_detail_screen.dart';
import 'features/contacts/views/post_call_review_screen.dart';
import 'features/contact_sources/views/contact_sources_screen.dart';
import 'features/contact_sources/views/google_sheets_config_screen.dart';
import 'features/contact_sources/views/import_summary_screen.dart';
import 'features/contact_sources/views/select_source_screen.dart';

/// Schema version for the contacts Hive box.
///
/// Increment this constant ONLY when existing Hive records become unreadable:
/// - A [ContactStatus] enum value is **reordered or removed** (breaks index-based
///   serialization).
///
/// Do NOT increment just for adding new fields — Hive's generated adapter
/// reads fields by their @HiveField index and defaults missing ones to null,
/// so new fields are backward-compatible without clearing the box.
///
/// On a version mismatch, the contacts box is cleared and re-seeded with demo
/// data. Any real imported contacts would be lost. Use a proper migration path
/// before incrementing this in a production build.
///
/// Version history:
///   1 — initial schema
///   2 — ContactStatus enum got @HiveType annotations
///   3 — Phase 3: added syncStatus (field 11), syncRetryCount (field 12)
///   4 — Phone normalization: added rawSourcePhoneNumber (field 13), phoneCountry (field 14)
const _contactsSchemaVersion = 4;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Hive with the Flutter path provider so it resolves the
  // correct documents directory on each platform.
  await Hive.initFlutter();

  // Register all type adapters before opening any box.
  //
  // TypeId allocation:
  //   0  ContactModel
  //   1  CallModel
  //   2  RecordingModel
  //   3  ExcelTableModel
  //  10  ContactStatus (enum)
  //  11  CallDirection  (enum)
  //  12  CallOutcome    (enum)
  //  13  TranscriptStatus (enum)
  //  14  SyncStatus (enum) ← Phase 3
  Hive
    ..registerAdapter(ContactModelAdapter())
    ..registerAdapter(ContactStatusAdapter())
    ..registerAdapter(
      SyncStatusAdapter(),
    ) // Phase 3: must register before openBox
    ..registerAdapter(CallModelAdapter())
    ..registerAdapter(CallDirectionAdapter())
    ..registerAdapter(CallOutcomeAdapter())
    ..registerAdapter(RecordingModelAdapter())
    ..registerAdapter(TranscriptStatusAdapter())
    ..registerAdapter(ExcelTableModelAdapter());

  // ── Schema migration ──────────────────────────────────────────────────────
  // Check schema version BEFORE opening feature boxes.
  // If the stored version doesn't match _contactsSchemaVersion, delete the
  // contacts box from disk so old records with incompatible field layouts
  // are removed before Hive attempts to deserialize them.
  final schemaBox = await Hive.openBox<int>('schema');
  final storedVersion = schemaBox.get('contacts') ?? 0;
  if (storedVersion != _contactsSchemaVersion) {
    await Hive.deleteBoxFromDisk('contacts');
    await schemaBox.put('contacts', _contactsSchemaVersion);
  }

  // Open all feature boxes at startup so services can access them synchronously.
  await Future.wait([
    ContactService.openBox(),
    CallService.openBox(),
    RecordingService.openBox(),
    ExcelTableService.openBox(),
    ContactSourceService.openBox(),
  ]);

  runApp(const ColdCallAssistantApp());
}

/// Root application widget.
///
/// Converted from [StatelessWidget] to [StatefulWidget] in Phase 3 to:
/// 1. Create providers with cross-references that require initialization order.
/// 2. Properly stop the [SyncProvider] periodic timer in [dispose] (avoiding
///    a timer leak if the widget tree is ever torn down in tests).
///
/// The build method uses [ChangeNotifierProvider.value] for the providers
/// created in [initState] so the Provider framework does NOT dispose them
/// when the widget is removed (their lifecycle is managed by this [State]).
class ColdCallAssistantApp extends StatefulWidget {
  const ColdCallAssistantApp({super.key});

  @override
  State<ColdCallAssistantApp> createState() => _ColdCallAssistantAppState();
}

class _ColdCallAssistantAppState extends State<ColdCallAssistantApp> {
  // ── Shared services ────────────────────────────────────────────────────────

  // A single GoogleSheetsIntegration instance is shared between all providers
  // so they use the same authenticated OAuth session.
  late final GoogleSheetsIntegration _sheetsIntegration;
  late final ContactService _contactService;
  late final ContactSourceService _contactSourceService;

  // ── Providers ──────────────────────────────────────────────────────────────

  late final ContactProvider _contactProvider;
  late final ContactSourceProvider _contactSourceProvider;
  late final ContactImportProvider _contactImportProvider;
  late final SyncProvider _syncProvider;

  @override
  void initState() {
    super.initState();

    // ── Create shared services ───────────────────────────────────────────────
    _sheetsIntegration = GoogleSheetsIntegration();
    _contactService = ContactService();
    _contactSourceService = ContactSourceService();

    // ── Create ContactProvider first ─────────────────────────────────────────
    // SyncProvider needs to reference contactProvider.reload, so ContactProvider
    // must exist before SyncProvider is created.
    _contactProvider = ContactProvider(service: _contactService)..seedAndLoad();

    // ── Create SyncProvider with reference to ContactProvider ────────────────
    _syncProvider = SyncProvider(
      adapters: [
        GoogleSheetsSyncAdapter(sheetsIntegration: _sheetsIntegration),
      ],
      contactService: _contactService,
      contactSourceService: _contactSourceService,
      // When any contact's syncStatus changes in Hive, reload the in-memory
      // contact list so the UI immediately reflects the new sync badge.
      onSyncStatusChanged: () => unawaited(_contactProvider.reload()),
    );

    // ── Wire the sync trigger ────────────────────────────────────────────────
    // ContactProvider.updateContact() calls this after every local save.
    // Avoids a direct import of SyncProvider from the contacts feature.
    _contactProvider.setSyncCallback(_syncProvider.enqueue);

    // ── Start the sync engine ────────────────────────────────────────────────
    // Re-queues pending contacts from the previous session and starts the
    // 5-minute periodic safety-net timer.
    unawaited(_syncProvider.start());

    // ── Create remaining providers ───────────────────────────────────────────
    _contactSourceProvider = ContactSourceProvider(
      sheetsIntegration: _sheetsIntegration,
    )..load();

    _contactImportProvider = ContactImportProvider(
      sheetsIntegration: _sheetsIntegration,
    );
  }

  @override
  void dispose() {
    // Stop the periodic sync timer when the widget tree is torn down.
    // In normal app usage this never fires (the process exits first), but
    // it prevents timer leaks in widget tests.
    _syncProvider.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Providers without cross-references use the standard create pattern.
        ChangeNotifierProvider(
          create: (_) => PhoneCallProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => CallingSequenceProvider()),
        // Providers created in initState use .value so the framework does
        // not dispose them when their ChangeNotifierProvider is removed.
        ChangeNotifierProvider<ContactProvider>.value(value: _contactProvider),
        ChangeNotifierProvider<ContactSourceProvider>.value(
          value: _contactSourceProvider,
        ),
        ChangeNotifierProvider<ContactImportProvider>.value(
          value: _contactImportProvider,
        ),
        ChangeNotifierProvider<SyncProvider>.value(value: _syncProvider),
        // Expose ContactService so views can pass it to deleteSourceWithContacts
        // without creating a direct dependency between contact_sources and hive.
        Provider<ContactService>.value(value: _contactService),
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
          '/select-source': (_) => const SelectSourceScreen(),
          '/contacts': (_) => const ContactsScreen(),
          '/contact-detail': (_) => const ContactDetailScreen(),
          '/post-call-review': (_) => const PostCallReviewScreen(),
          '/settings': (_) => const ContactSourcesScreen(),
          '/settings/google-sheets': (_) => const GoogleSheetsConfigScreen(),
          '/import-summary': (_) => const ImportSummaryScreen(),
        },
      ),
    );
  }
}
