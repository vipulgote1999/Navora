import '../../core/utils/firestore_date.dart';

/// Pre-canned quick messages a rider can broadcast.
// TODO(P0-02): spec defines 7 quick-message templates; this enum currently
// carries 5. Align toward the spec 7 without breaking existing tests/usages.
enum QuickMessageType {
  needFuel,
  needRestroom,
  needHelp,
  regroup,
  allGood,
}

/// One broadcast quick message. Plain Dart — no Firebase imports.
///
/// [expiresAt] defaults to 4h after [sentAt]; clients hide expired messages.
class QuickMessage {
  static const expiryDuration = Duration(hours: 4);

  final String id;
  final String tripId;
  final String senderUid;
  final QuickMessageType type;
  final DateTime sentAt;
  final DateTime expiresAt;

  QuickMessage({
    required this.id,
    required this.tripId,
    required this.senderUid,
    required this.type,
    required this.sentAt,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? sentAt.add(expiryDuration);

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'id': id,
        'tripId': tripId,
        'senderUid': senderUid,
        'type': type.name,
        'sentAt': sentAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };

  factory QuickMessage.fromMap(Map<String, dynamic> map) => QuickMessage(
        id: map['id'] as String,
        tripId: map['tripId'] as String,
        senderUid: map['senderUid'] as String,
        type: QuickMessageType.values.byName(map['type'] as String),
        sentAt: parseFirestoreDate(map['sentAt']),
        expiresAt: parseFirestoreDate(map['expiresAt']),
      );
}
