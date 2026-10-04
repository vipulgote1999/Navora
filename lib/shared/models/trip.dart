import '../../core/utils/firestore_date.dart';
import '../../core/utils/join_code.dart' as join_code;

/// Trip status lifecycle: planning -> active -> completed.
enum TripStatus { planning, active, completed }

/// Core trip entity. Plain Dart — no Firebase imports.
class Trip {
  /// Canonical join-code pattern, single-sourced from `join_code.dart`.
  static RegExp get joinCodePattern => join_code.joinCodePattern;

  static bool isValidJoinCode(String code) =>
      join_code.joinCodePattern.hasMatch(code);

  final String id;
  final String name;
  final String origin;
  final String destination;
  final TripStatus status;
  final String hostUid;
  final String joinCode;
  final int maxParticipants;

  /// When the trip was created. Defaults to now; serialized as millis.
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.status,
    required this.hostUid,
    required this.joinCode,
    required this.maxParticipants,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'origin': origin,
        'destination': destination,
        'status': status.name,
        'hostUid': hostUid,
        'joinCode': joinCode,
        'maxParticipants': maxParticipants,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Trip.fromMap(Map<String, dynamic> map) => Trip(
        id: map['id'] as String,
        name: map['name'] as String,
        origin: map['origin'] as String,
        destination: map['destination'] as String,
        status: TripStatus.values.byName(map['status'] as String),
        hostUid: map['hostUid'] as String,
        joinCode: map['joinCode'] as String,
        maxParticipants: map['maxParticipants'] as int,
        // Tolerant of docs written before createdAt existed, millis as
        // int/num, DateTime, or Firestore Timestamp (see firestore_date.dart).
        createdAt: parseFirestoreDate(map['createdAt']),
      );
}
