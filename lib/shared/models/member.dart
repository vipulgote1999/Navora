/// Membership role within a trip.
enum MemberRole { host, member }

/// Trip member. Plain Dart — no Firebase imports.
class Member {
  final String uid;
  final String displayName;
  final MemberRole role;
  final String vehicleType;
  final String vehicleLabel;

  const Member({
    required this.uid,
    this.displayName = '',
    required this.role,
    required this.vehicleType,
    required this.vehicleLabel,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'role': role.name,
        'vehicleType': vehicleType,
        'vehicleLabel': vehicleLabel,
      };

  factory Member.fromMap(Map<String, dynamic> map) => Member(
        uid: map['uid'] as String,
        displayName: (map['displayName'] as String?) ?? '',
        role: MemberRole.values.byName(map['role'] as String),
        vehicleType: map['vehicleType'] as String,
        vehicleLabel: map['vehicleLabel'] as String,
      );
}
