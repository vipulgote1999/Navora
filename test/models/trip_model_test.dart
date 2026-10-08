import 'package:flutter_test/flutter_test.dart';
import 'package:navora/shared/models/trip.dart';
import 'package:navora/shared/models/member.dart';
import 'package:navora/shared/models/live_position.dart';
import 'package:navora/shared/models/quick_message.dart';

void main() {
  group('Trip', () {
    test('fromMap/toMap roundtrip preserves all fields', () {
      final trip = Trip(
        id: 'trip-1',
        name: 'Desert Convoy',
        origin: 'Phoenix',
        destination: 'Sedona',
        status: TripStatus.active,
        hostUid: 'host-uid-1',
        joinCode: 'TRIP-AB12',
        maxParticipants: 8,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1759531200000),
      );
      final restored = Trip.fromMap(trip.toMap());
      expect(restored.id, trip.id);
      expect(restored.name, trip.name);
      expect(restored.origin, trip.origin);
      expect(restored.destination, trip.destination);
      expect(restored.status, trip.status);
      expect(restored.hostUid, trip.hostUid);
      expect(restored.joinCode, trip.joinCode);
      expect(restored.maxParticipants, trip.maxParticipants);
      expect(restored.createdAt, trip.createdAt);
    });

    test('createdAt defaults to now when omitted', () {      final before = DateTime.now();
      final trip = Trip(
        id: 'trip-2',
        name: 'No Date Ride',
        origin: 'A',
        destination: 'B',
        status: TripStatus.planning,
        hostUid: 'host-uid-1',
        joinCode: 'TRIP-CD34',
        maxParticipants: 4,
      );
      expect(
        trip.createdAt.isAfter(before.subtract(const Duration(seconds: 5))),
        isTrue,
      );
    });

    test('fromMap accepts Firestore Timestamp for createdAt', () {
      final when = DateTime.fromMillisecondsSinceEpoch(1759531200000);
      final map = <String, dynamic>{
        'id': 'trip-ts',
        'name': 'TS Ride',
        'origin': 'A',
        'destination': 'B',
        'status': 'planning',
        'hostUid': 'host-uid-1',
        'joinCode': 'TRIP-EF56',
        'maxParticipants': 5,
        'createdAt': _FakeTimestamp(when),
      };
      expect(Trip.fromMap(map).createdAt, when);
    });

    test('joinCode matches ^TRIP-[A-Z0-9]{4}\$', () {
      final pattern = RegExp(r'^TRIP-[A-Z0-9]{4}$');
      expect(pattern.hasMatch('TRIP-AB12'), isTrue);
      expect(pattern.hasMatch('TRIP-9Z3Q'), isTrue);
      expect(Trip.isValidJoinCode('TRIP-AB12'), isTrue);
      expect(Trip.isValidJoinCode('BAD'), isFalse);
      expect(Trip.isValidJoinCode('trip-ab12'), isFalse);
      expect(Trip.isValidJoinCode('TRIP-ABCDE'), isFalse);
    });

    test('Member fromMap/toMap roundtrip', () {
      const member = Member(
        uid: 'uid-1',
        displayName: 'Abhi',
        role: MemberRole.host,
        vehicleType: 'Car',
        vehicleLabel: 'Red SUV',
      );
      final restored = Member.fromMap(member.toMap());
      expect(restored.uid, member.uid);
      expect(restored.displayName, 'Abhi');
      expect(restored.role, member.role);
      expect(restored.vehicleType, member.vehicleType);
      expect(restored.vehicleLabel, member.vehicleLabel);
    });

    test('Member displayName defaults empty when absent', () {
      final restored = Member.fromMap(const {
        'uid': 'uid-2',
        'role': 'member',
        'vehicleType': 'Bike',
        'vehicleLabel': '',
      });
      expect(restored.displayName, '');
    });
  });

  group('LivePosition', () {
    test('isStale true when updatedAt >90s ago', () {
      final now = DateTime.now();
      final stale = LivePosition(
        uid: 'uid-1',
        lat: 33.4,
        lng: -112.0,
        heading: 90,
        speed: 10,
        accuracy: 5,
        status: 'driving',
        updatedAt: now.subtract(const Duration(seconds: 91)),
        expiresAt: now.add(const Duration(hours: 4)),
      );
      expect(stale.isStale(now), isTrue);
    });

    test('isStale false when updatedAt within 90s', () {
      final now = DateTime.now();
      final fresh = LivePosition(
        uid: 'uid-1',
        lat: 33.4,
        lng: -112.0,
        heading: 90,
        speed: 10,
        accuracy: 5,
        status: 'driving',
        updatedAt: now.subtract(const Duration(seconds: 10)),
        expiresAt: now.add(const Duration(hours: 4)),
      );
      expect(fresh.isStale(now), isFalse);
    });

    test('fromMap/toMap roundtrip', () {
      final now = DateTime.now();
      final pos = LivePosition(
        uid: 'uid-1',
        lat: 33.4,
        lng: -112.0,
        heading: 45,
        speed: 12.5,
        accuracy: 8,
        status: 'driving',
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
      );
      final restored = LivePosition.fromMap(pos.toMap());
      expect(restored.uid, pos.uid);
      expect(restored.lat, pos.lat);
      expect(restored.lng, pos.lng);
      expect(restored.status, pos.status);
    });
  });

  group('QuickMessage', () {
    test('expiresAt auto 4h after sentAt', () {
      final sentAt = DateTime(2026, 10, 4, 12, 0, 0);
      final msg = QuickMessage(
        id: 'msg-1',
        tripId: 'trip-1',
        senderUid: 'uid-1',
        type: QuickMessageType.needFuel,
        sentAt: sentAt,
      );
      expect(
        msg.expiresAt,
        sentAt.add(const Duration(hours: 4)),
      );
    });

    test('isExpired true after expiresAt', () {
      final sentAt = DateTime(2026, 10, 4, 12, 0, 0);
      final msg = QuickMessage(
        id: 'msg-1',
        tripId: 'trip-1',
        senderUid: 'uid-1',
        type: QuickMessageType.regroup,
        sentAt: sentAt,
      );
      expect(msg.isExpired(sentAt.add(const Duration(hours: 5))), isTrue);
      expect(msg.isExpired(sentAt.add(const Duration(hours: 1))), isFalse);
    });
  });
}

/// Minimal Firestore Timestamp stand-in (duck-typed via toDate()).
class _FakeTimestamp {
  final DateTime _date;
  _FakeTimestamp(this._date);
  DateTime toDate() => _date;
  int get millisecondsSinceEpoch => _date.millisecondsSinceEpoch;
}
