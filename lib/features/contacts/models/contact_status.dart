import 'package:hive/hive.dart';

part 'contact_status.g.dart';

/// Represents the outcome or call status for a contact.
///
/// Values are serialised by their **index** in the Hive adapter, so the order
/// must never change and new values must always be appended at the end.
///
/// Design note: these values are post-call statuses deliberately set by
/// the salesperson after speaking with (or attempting to reach) the contact.
/// They replace the previous pipeline-stage enum that was not granular
/// enough for the cold-calling workflow.
@HiveType(typeId: 10)
enum ContactStatus {
  /// The contact expressed interest in the product or service.
  @HiveField(0)
  interested,

  /// The contact explicitly declined and should not be called again.
  @HiveField(1)
  notInterested,

  /// Something specific needs to be done before the next call (e.g. send info).
  @HiveField(2)
  actionRequired,

  /// The contact asked to be called back at a later time.
  @HiveField(3)
  callLater,

  /// The call was placed but the contact did not answer.
  @HiveField(4)
  didntPickUp,

  /// The phone number is invalid or the contact no longer exists.
  @HiveField(5)
  doesntExist,
}

/// Extension providing a human-readable label for each [ContactStatus] value.
extension ContactStatusLabel on ContactStatus {
  String get displayLabel {
    switch (this) {
      case ContactStatus.interested:
        return 'Interested';
      case ContactStatus.notInterested:
        return 'Not Interested';
      case ContactStatus.actionRequired:
        return 'Action Required';
      case ContactStatus.callLater:
        return 'Call Later';
      case ContactStatus.didntPickUp:
        return "Didn't Pick Up";
      case ContactStatus.doesntExist:
        return "Doesn't Exist";
    }
  }
}
