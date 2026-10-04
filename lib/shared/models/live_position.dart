/// Latest known live position for one member (`live/{uid}` doc).
/// Plain Dart — no Firebase imports.
class LivePosition {
  /// Stale threshold: positions older than 90s render greyed.
  static const staleThresholdSeconds = 90;

  final String uid;
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  final double accuracy;
  final String status;
  final DateTime updatedAt;
  final DateTime expiresAt;

  const LivePosition({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    required this.accuracy,
    required this.status,
    required this.updatedAt,
    required this.expiresAt,
  });

  bool isStale(DateTime now) =>
      now.difference(updatedAt).inSeconds > staleThresholdSeconds;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'speed': speed,
        'accuracy': accuracy,
        'status': status,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };

  factory LivePosition.fromMap(Map<String, dynamic> map) => LivePosition(
        uid: map['uid'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        heading: (map['heading'] as num).toDouble(),
        speed: (map['speed'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        status: map['status'] as String,
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
      );
}
