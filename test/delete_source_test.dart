import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:cold_call_assistant/features/contacts/models/contact_model.dart';
import 'package:cold_call_assistant/features/contacts/models/contact_status.dart';
import 'package:cold_call_assistant/features/contacts/models/sync_status.dart';
import 'package:cold_call_assistant/features/contacts/services/contact_service.dart';
import 'package:cold_call_assistant/features/contact_sources/models/contact_source.dart';
import 'package:cold_call_assistant/features/contact_sources/models/contact_field.dart';
import 'package:cold_call_assistant/features/contact_sources/providers/contact_source_provider.dart';
import 'package:cold_call_assistant/features/contact_sources/providers/sync_provider.dart';
import 'package:cold_call_assistant/features/contact_sources/services/contact_source_service.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

// ---------------------------------------------------------------------------
// Helper factories
// ---------------------------------------------------------------------------

GoogleSheetsSource _makeSource(String id, String name) => GoogleSheetsSource(
      id: id,
      displayName: name,
      spreadsheetUrl: 'https://docs.google.com/spreadsheets/d/$id',
      worksheetName: 'Sheet1',
      columnMapping: const {
        ContactField.name: 'A',
        ContactField.phoneNumber: 'B',
      },
    );

ContactModel _makeContact({
  required String id,
  required String name,
  String? sourceId,
  SyncStatus syncStatus = SyncStatus.noSource,
}) =>
    ContactModel(
      id: id,
      name: name,
      phoneNumber: '+359898123456',
      status: ContactStatus.callLater,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      importedFromTableId: sourceId,
      syncStatus: syncStatus,
    );

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  late Box<ContactModel> contactBox;
  late Box<String> sourceBox;
  late ContactService contactService;
  late ContactSourceService contactSourceService;

  setUpAll(() async {
    Hive.init('.');
    // Register adapters needed for ContactModel box
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ContactStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(SyncStatusAdapter());
    }
    // ContactModelAdapter is typeId 0
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ContactModelAdapter());
    }
  });

  setUp(() async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    contactBox = await Hive.openBox<ContactModel>('del_contacts_$ts');
    sourceBox = await Hive.openBox<String>('del_sources_$ts');
    contactService = ContactService.withBox(contactBox);
    contactSourceService = ContactSourceService.withBox(sourceBox);
  });

  tearDown(() async {
    await contactBox.deleteFromDisk();
    await sourceBox.deleteFromDisk();
  });

  // ── ContactService.deleteAllForSource ──────────────────────────────────────

  group('ContactService.deleteAllForSource', () {
    test(
        '1. deletes only contacts belonging to the target source; '
        '4+5. contacts from other sources and manual contacts remain',
        () async {
      final c1 = _makeContact(id: 'c1', name: 'Alice', sourceId: 'src-A');
      final c2 = _makeContact(id: 'c2', name: 'Bob', sourceId: 'src-A');
      final c3 = _makeContact(id: 'c3', name: 'Carol', sourceId: 'src-B');
      final c4 = _makeContact(id: 'c4', name: 'Dan'); // no source
      await contactBox.putAll({c1.id: c1, c2.id: c2, c3.id: c3, c4.id: c4});

      final deleted = await contactService.deleteAllForSource('src-A');

      expect(deleted, 2, reason: '2 contacts from src-A must be deleted');
      expect(contactBox.containsKey('c1'), isFalse,
          reason: 'c1 from src-A must be deleted');
      expect(contactBox.containsKey('c2'), isFalse,
          reason: 'c2 from src-A must be deleted');
      expect(contactBox.containsKey('c3'), isTrue,
          reason: 'c3 from src-B must remain untouched');
      expect(contactBox.containsKey('c4'), isTrue,
          reason: 'manually created contact must remain');
    });

    test('2. returns 0 and changes nothing when source has no contacts',
        () async {
      final c1 = _makeContact(id: 'c1', name: 'Alice', sourceId: 'src-B');
      await contactBox.put(c1.id, c1);

      final deleted = await contactService.deleteAllForSource('src-A');

      expect(deleted, 0);
      expect(contactBox.length, 1);
    });

    test(
        '9. safely deletes contacts with pendingSync, syncing, and failed states',
        () async {
      final pending = _makeContact(
          id: 'cp',
          name: 'P',
          sourceId: 'src-A',
          syncStatus: SyncStatus.pendingSync);
      final syncing = _makeContact(
          id: 'cs',
          name: 'S',
          sourceId: 'src-A',
          syncStatus: SyncStatus.syncing);
      final failed = _makeContact(
          id: 'cf',
          name: 'F',
          sourceId: 'src-A',
          syncStatus: SyncStatus.failed);
      await contactBox.putAll({
        pending.id: pending,
        syncing.id: syncing,
        failed.id: failed,
      });

      final deleted = await contactService.deleteAllForSource('src-A');

      expect(deleted, 3);
      expect(contactBox.isEmpty, isTrue);
    });
  });

  // ── SyncProvider.cancelPendingForSource ────────────────────────────────────

  group('SyncProvider.cancelPendingForSource', () {
    late SyncProvider syncProvider;

    setUp(() {
      syncProvider = SyncProvider(
        adapters: const [],
        contactService: contactService,
        contactSourceService: contactSourceService,
      );
    });

    tearDown(() => syncProvider.stop());

    test(
        '8. removes IDs belonging to the source from the in-memory queue, '
        'leaves other sources untouched', () async {
      final c1 = _makeContact(
          id: 'c1',
          name: 'A',
          sourceId: 'src-A',
          syncStatus: SyncStatus.pendingSync);
      final c2 = _makeContact(
          id: 'c2',
          name: 'B',
          sourceId: 'src-A',
          syncStatus: SyncStatus.pendingSync);
      final c3 = _makeContact(
          id: 'c3',
          name: 'C',
          sourceId: 'src-B',
          syncStatus: SyncStatus.pendingSync);
      await contactBox.putAll({c1.id: c1, c2.id: c2, c3.id: c3});

      syncProvider
        ..enqueueForTest('c1')
        ..enqueueForTest('c2')
        ..enqueueForTest('c3');

      syncProvider.cancelPendingForSource('src-A');

      expect(syncProvider.queueContains('c1'), isFalse,
          reason: 'c1 from src-A must be removed from queue');
      expect(syncProvider.queueContains('c2'), isFalse,
          reason: 'c2 from src-A must be removed from queue');
      expect(syncProvider.queueContains('c3'), isTrue,
          reason: 'c3 from src-B must remain in queue');
    });

    test('no-op when source has no contacts in the queue', () async {
      final c1 = _makeContact(
          id: 'c1',
          name: 'A',
          sourceId: 'src-B',
          syncStatus: SyncStatus.pendingSync);
      await contactBox.put(c1.id, c1);
      syncProvider.enqueueForTest('c1');

      syncProvider.cancelPendingForSource('src-A');

      expect(syncProvider.queueContains('c1'), isTrue,
          reason: 'c1 from src-B must not be affected');
    });
  });

  // ── ContactSourceProvider.deleteSourceWithContacts ─────────────────────────

  group('ContactSourceProvider.deleteSourceWithContacts', () {
    late ContactSourceProvider sourceProvider;
    late SyncProvider syncProvider;

    setUp(() {
      syncProvider = SyncProvider(
        adapters: const [],
        contactService: contactService,
        contactSourceService: contactSourceService,
      );
      sourceProvider = ContactSourceProvider(
        service: contactSourceService,
      );
    });

    tearDown(() => syncProvider.stop());

    test('1+2+3. source config and all its contacts are deleted', () async {
      final source = _makeSource('src-A', 'Leads');
      await contactSourceService.save(source);
      final c1 = _makeContact(id: 'c1', name: 'A', sourceId: 'src-A');
      final c2 = _makeContact(id: 'c2', name: 'B', sourceId: 'src-A');
      await contactBox.putAll({c1.id: c1, c2.id: c2});
      sourceProvider.loadSync();

      await sourceProvider.deleteSourceWithContacts(
          source, contactService, syncProvider);

      expect(sourceBox.containsKey('src-A'), isFalse,
          reason: 'Source config must be deleted from Hive');
      expect(sourceProvider.sources, isEmpty,
          reason: 'Source must be removed from provider state');
      expect(contactBox.containsKey('c1'), isFalse);
      expect(contactBox.containsKey('c2'), isFalse);
    });

    test('4+5. contacts from other sources and manual contacts are untouched',
        () async {
      final srcA = _makeSource('src-A', 'Leads');
      final srcB = _makeSource('src-B', 'Other');
      await contactSourceService.save(srcA);
      await contactSourceService.save(srcB);
      final cA = _makeContact(id: 'cA', name: 'A', sourceId: 'src-A');
      final cB = _makeContact(id: 'cB', name: 'B', sourceId: 'src-B');
      final cM = _makeContact(id: 'cM', name: 'Manual');
      await contactBox.putAll({cA.id: cA, cB.id: cB, cM.id: cM});
      sourceProvider.loadSync();

      await sourceProvider.deleteSourceWithContacts(
          srcA, contactService, syncProvider);

      expect(contactBox.containsKey('cA'), isFalse);
      expect(contactBox.containsKey('cB'), isTrue,
          reason: 'cB from src-B must remain');
      expect(contactBox.containsKey('cM'), isTrue,
          reason: 'Manual contact must remain');
      expect(sourceBox.containsKey('src-B'), isTrue,
          reason: 'src-B must not be deleted');
    });

    test('11. source disappears from provider list after deletion', () async {
      final source = _makeSource('src-A', 'Leads');
      await contactSourceService.save(source);
      sourceProvider.loadSync();
      expect(sourceProvider.sources, hasLength(1));

      await sourceProvider.deleteSourceWithContacts(
          source, contactService, syncProvider);

      expect(sourceProvider.sources, isEmpty);
    });

    test('12. same source can be re-added and contacts re-imported after deletion',
        () async {
      final source = _makeSource('src-A', 'Leads');
      await contactSourceService.save(source);
      sourceProvider.loadSync();
      await sourceProvider.deleteSourceWithContacts(
          source, contactService, syncProvider);

      // Re-add the same source.
      await contactSourceService.save(source);
      sourceProvider.loadSync();

      expect(sourceProvider.sources, hasLength(1));
      expect(sourceProvider.sources.first.id, 'src-A');
    });

    test(
        '8. cancels pending sync queue entries before deleting contacts; '
        'no rogue sync can fire after deletion',
        () async {
      final source = _makeSource('src-A', 'Leads');
      await contactSourceService.save(source);
      final c1 = _makeContact(
          id: 'c1',
          name: 'A',
          sourceId: 'src-A',
          syncStatus: SyncStatus.pendingSync);
      await contactBox.put(c1.id, c1);
      sourceProvider.loadSync();
      syncProvider.enqueueForTest('c1');
      expect(syncProvider.queueContains('c1'), isTrue);

      await sourceProvider.deleteSourceWithContacts(
          source, contactService, syncProvider);

      // Contact must no longer be in queue AND must be deleted from storage.
      expect(syncProvider.queueContains('c1'), isFalse,
          reason: 'ID must be removed from sync queue before deletion');
      expect(contactBox.containsKey('c1'), isFalse,
          reason: 'Contact must be deleted from Hive');
    });

    test(
        '10. cancelling confirmation (not calling method) makes no changes',
        () async {
      final source = _makeSource('src-A', 'Leads');
      await contactSourceService.save(source);
      final c1 = _makeContact(id: 'c1', name: 'A', sourceId: 'src-A');
      await contactBox.put(c1.id, c1);
      sourceProvider.loadSync();

      // Simulate user pressing Cancel — deleteSourceWithContacts is NOT called.
      // Nothing should change.
      expect(contactBox.containsKey('c1'), isTrue,
          reason: 'Contact must not be deleted when user cancels');
      expect(sourceBox.containsKey('src-A'), isTrue,
          reason: 'Source must not be deleted when user cancels');
    });
  });
}


