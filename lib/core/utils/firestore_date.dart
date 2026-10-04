/// Tolerant Firestore date parsing. Plain Dart — no Firebase imports.
///
/// Accepts int millis, any num millis, [DateTime], or a Firestore
/// Timestamp-shaped object (duck-typed via `toDate()` /
/// `millisecondsSinceEpoch` so models stay Firebase-free). Falls back to
/// [fallback] or `DateTime.now()` when the value is missing/unrecognized.
DateTime parseFirestoreDate(dynamic value, {DateTime? fallback}) {
  if (value == null) return fallback ?? DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  // Firestore Timestamp duck-typing (no cloud_firestore import on purpose).
  try {
    final dynamic ts = value;
    final DateTime viaToDate = ts.toDate() as DateTime;
    return viaToDate;
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    // Fall through to millisecondsSinceEpoch probe.
  }
  try {
    final dynamic ts = value;
    final dynamic millis = ts.millisecondsSinceEpoch;
    if (millis is int) return DateTime.fromMillisecondsSinceEpoch(millis);
    if (millis is num) {
      return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
    }
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    // Fall through to fallback below.
  }
  return fallback ?? DateTime.now();
}
