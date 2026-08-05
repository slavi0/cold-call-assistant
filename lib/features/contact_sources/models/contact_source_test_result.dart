/// The result of a contact source connection test.
///
/// Returned by [ContactSourceProvider.testSource] so the UI can display
/// an appropriate message without knowing how the test was performed.
///
/// ## Phase 2 notes
/// When the Google Sheets API is integrated, [testSource] will attempt a
/// real connection and return [success] or [failed]. The [notImplemented]
/// value will no longer be returned for Google Sheets, but remains in the
/// enum for future source types that have not yet been connected.
enum ContactSourceTestResult {
  /// The connection to the source was verified successfully.
  success,

  /// The connection attempt failed (network error, invalid credentials, etc.).
  /// A descriptive error message is provided separately via the provider's
  /// [errorMessage] field.
  failed,

  /// Connection testing is not yet implemented for this source type.
  /// This is the placeholder returned for all source types in Phase 1.
  notImplemented,
}
