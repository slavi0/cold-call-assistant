import 'package:hive/hive.dart';

part 'call_direction.g.dart';

/// Whether the call was placed by the salesperson or received from the prospect.
///
/// Stored by Hive via the generated adapter. Never reorder or remove values.
@HiveType(typeId: 11)
enum CallDirection {
  @HiveField(0)
  outgoing,

  @HiveField(1)
  incoming,
}
