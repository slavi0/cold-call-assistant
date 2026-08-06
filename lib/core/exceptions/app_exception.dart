/// Base exception for all application-level errors.
///
/// Using a typed exception hierarchy means providers can catch [AppException]
/// specifically, show the user a meaningful message, and avoid swallowing
/// unexpected errors silently (Rule 8: Error Handling).
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;

  /// The underlying error, if any (e.g. a Hive error or IO exception).
  final Object? cause;

  @override
  String toString() =>
      cause != null ? 'AppException: $message (caused by: $cause)' : 'AppException: $message';
}

/// Thrown when a requested record does not exist in storage.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Thrown when a storage read or write operation fails.
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// Thrown when a device hardware or system service feature fails (e.g. dialer unavailable).
class DeviceException extends AppException {
  const DeviceException(super.message, {super.cause});
}

/// Thrown when an operation involving the Google Sheets API fails.
///
/// The [message] is always user-friendly and can be displayed directly in the UI.
/// Common causes: invalid URL, access denied (403), spreadsheet not found (404),
/// missing worksheet, network errors, or authentication failures.
class GoogleSheetsException extends AppException {
  const GoogleSheetsException(super.message, {super.cause});
}

/// Thrown when a row from a contact source cannot be converted to a [ContactModel].
///
/// Used by [ContactImportService] to record per-row failures in the
/// [ContactImportSummary] without aborting the entire import.
class ContactImportException extends AppException {
  const ContactImportException(super.message, {super.cause});
}

/// Thrown when a background sync operation fails for a specific contact.
///
/// Caught by [SyncProvider] to record the failure, increment
/// [ContactModel.syncRetryCount], and schedule a retry with backoff.
/// Sub-classify using specific messages rather than sub-types — the
/// engine only needs to decide "retry" vs. "give up", not inspect the cause.
class SyncException extends AppException {
  const SyncException(super.message, {super.cause});
}
