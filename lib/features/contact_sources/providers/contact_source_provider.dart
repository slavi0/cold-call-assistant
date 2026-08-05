import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_source.dart';
import '../models/contact_source_test_result.dart';
import '../services/contact_source_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// Manages the list of configured contact sources.
///
/// Acts as the single source of truth for contact source configuration state.
/// All screens read and modify sources through this provider — they never
/// interact with [ContactSourceService] or Hive directly.
///
/// ## Lifecycle
/// [load] is called at app startup (wired in [main.dart]).
/// Subsequent changes (add, update, remove) are immediately reflected in
/// [sources] without requiring a full reload.
class ContactSourceProvider extends ChangeNotifier {
  ContactSourceProvider({ContactSourceService? service})
      : _service = service ?? ContactSourceService();

  final ContactSourceService _service;
  final _uuid = const Uuid();

  List<ContactSource> _sources = [];

  /// The current list of configured contact sources.
  List<ContactSource> get sources => List.unmodifiable(_sources);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True while [testSource] is executing. Use to disable the Test button
  /// and show a loading indicator.
  bool _isTesting = false;
  bool get isTesting => _isTesting;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Loads all configured sources from persistent storage.
  ///
  /// Should be called once at app startup after the Hive box is open.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sources = _service.loadAll();
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load contact sources.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Persists [source] as a new entry and adds it to [sources].
  Future<void> addSource(ContactSource source) async {
    _errorMessage = null;
    try {
      await _service.save(source);
      _sources = [..._sources, source];
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Persists the updated [source] and replaces the matching entry in [sources].
  Future<void> updateSource(ContactSource source) async {
    _errorMessage = null;
    try {
      await _service.save(source);
      _sources = _sources
          .map((s) => s.id == source.id ? source : s)
          .toList();
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Removes the source with [id] from storage and from [sources].
  Future<void> removeSource(String id) async {
    _errorMessage = null;
    try {
      await _service.delete(id);
      _sources = _sources.where((s) => s.id != id).toList();
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  /// Generates a new RFC-4122 UUID for use as a source ID.
  String generateId() => _uuid.v4();

  // ── Connection Testing ─────────────────────────────────────────────────────

  /// Tests the connection to [source].
  ///
  /// **Phase 1 — placeholder**: always returns
  /// [ContactSourceTestResult.notImplemented] after a brief artificial delay
  /// so the loading state is visible to the user.
  ///
  /// **Phase 2**: replace the switch body with real API calls per source type.
  /// The switch is intentionally exhaustive — adding a new source type will
  /// produce a compile error here until its test logic is implemented.
  Future<ContactSourceTestResult> testSource(ContactSource source) async {
    _isTesting = true;
    notifyListeners();

    // Simulate network latency so the loading indicator is visible.
    await Future.delayed(const Duration(milliseconds: 800));

    _isTesting = false;
    notifyListeners();

    return switch (source) {
      // Phase 2: replace with actual Sheets API connectivity check.
      GoogleSheetsSource() => ContactSourceTestResult.notImplemented,
    };
  }
}
