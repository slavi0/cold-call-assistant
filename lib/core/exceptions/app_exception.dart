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
