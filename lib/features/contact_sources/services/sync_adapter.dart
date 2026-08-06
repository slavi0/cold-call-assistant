import '../../contacts/models/contact_model.dart';
import '../models/contact_source.dart';

/// The interface every synchronization adapter must implement.
///
/// ## Extension point for future integrations
///
/// Adding a new integration (GoHighLevel, HubSpot, Salesforce, Supabase, etc.)
/// requires creating exactly one new class that implements this interface.
/// [SyncProvider] is never modified — it dispatches by matching
/// [SyncAdapter.adapterId] against [ContactSource.type].
///
/// ## Adapter responsibilities
///
/// Each adapter owns:
/// 1. **Matching** — finding the remote record that corresponds to a local
///    [ContactModel]. For Google Sheets this is phone-number scanning.
///    For Supabase it would be UUID lookup. The engine never knows.
/// 2. **Writing** — pushing local field values to the remote record.
/// 3. **Availability** — reporting whether it can currently sync
///    (e.g., signed in, network reachable).
///
/// ## Error contract
///
/// Adapters MUST throw an [AppException] subclass on any failure.
/// Never return false or swallow errors silently — the [SyncProvider] uses
/// the exception to classify the failure and apply the retry/backoff strategy.
///
/// ## Naming convention
///
/// Concrete adapters are named `<IntegrationName>SyncAdapter`, e.g.:
/// - [GoogleSheetsSyncAdapter]
/// - `HubSpotSyncAdapter` (future)
/// - `SupabaseSyncAdapter` (future)
abstract class SyncAdapter {
  /// Unique identifier for this adapter's source type.
  ///
  /// Must match the value returned by [ContactSource.type] for the source
  /// this adapter handles. The [SyncProvider] uses this to dispatch each
  /// contact to the correct adapter without any hard-coded type checks.
  ///
  /// Example: `'google_sheets'` (matches [GoogleSheetsSource.typeKey]).
  String get adapterId;

  /// Returns true if this adapter is currently capable of processing sync
  /// requests.
  ///
  /// Called by [SyncProvider] before dispatching. If false, the contact
  /// remains [SyncStatus.pendingSync] and will be retried on the next
  /// periodic run or connectivity change.
  ///
  /// Should NOT throw — a false return is sufficient to signal unavailability.
  Future<bool> isAvailable();

  /// Pushes the current local state of [contact] to the external source
  /// described by [source].
  ///
  /// [source] is guaranteed to have the same [ContactSource.id] as
  /// [contact.importedFromTableId].
  ///
  /// Throws [AppException] (or a subclass) on any failure. The
  /// [SyncProvider] catches this, increments the retry count, and schedules
  /// a backoff retry.
  Future<void> pushUpdate({
    required ContactModel contact,
    required ContactSource source,
  });
}
