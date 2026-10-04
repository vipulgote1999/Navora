/// Trip status lifecycle: planning -> active -> completed.
enum TripStatus { planning, active, completed }

/// Core trip entity. Plain Dart — no Firebase imports.
class Trip {
  static final RegExp joinCodePattern = RegExp(r'^TRIP-[A-Z0-9]{4}$');

  static bool isValidJoinCode(String code) => joinCodePattern.hasMatch(code);

  final String id;
  final String name;
  final String origin;
  final String destination;
  final TripStatus status;
  final String hostUid;
  final String joinCode;
  final int maxParticipants;

  const Trip({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.status,
    required this.hostUid,
    required this.joinCode,
    required this.maxParticipants,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'origin': origin,
        'destination': destination,
        'status': status.name,
        'hostUid': hostUid,
        'joinCode': joinCode,
        'maxParticipants': maxParticipants,
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
      );
}
