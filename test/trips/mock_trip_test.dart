import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';

Future<MockTripDataSource> _repo() async => MockTripDataSource();

void main() {
  group('MockTripDataSource create', () {
    test('createTrip reserves joinCodes entry', () async {
      final ds = await _repo();
      final trip = await ds.createTrip(
        name: 'Weekend Ride',
        origin: 'Pune',
        destination: 'Lonavala',
        hostUid: 'mock-uid',
      );
      expect(trip.joinCode, matches(RegExp(r'^TRIP-[A-Z0-9]{4}$')));
      expect(ds.joinCodes[trip.joinCode], trip.id);
      expect(ds.trips[trip.id]?.id, trip.id);
    });

    test('host gets default Car vehicle', () async {
      final ds = await _repo();
      final trip = await ds.createTrip(
        name: 'Ride',
        origin: 'A',
        destination: 'B',
        hostUid: 'mock-uid',
      );
      final host = ds.membersFor(trip.id).singleWhere(
            (m) => m.uid == 'mock-uid',
          );
      expect(host.vehicleType, 'Car');
    });

    test('demo-uid create throws', () async {
      final ds = await _repo();
      expect(
        () => ds.createTrip(
          name: 'Demo Ride',
          origin: 'A',
          destination: 'B',
          hostUid: 'demo-123',
        ),
        throwsStateError,
      );
    });

    test('forced collision retries with a new code', () async {
      final ds = await _repo();
      // Seed a reservation that the first generated code will collide with.
      ds.joinCodes['TRIP-AB12'] = 'trip_existing';
      var calls = 0;
      final colliding = MockTripDataSource(
        joinCodeGenerator: () =>
            calls++ == 0 ? 'TRIP-AB12' : 'TRIP-ZZ99',
      );
      // Share the seeded reservation so the collision is real.
      colliding.joinCodes.addAll(ds.joinCodes);
      final trip = await colliding.createTrip(
        name: 'Collision Ride',
        origin: 'A',
        destination: 'B',
        hostUid: 'mock-uid',
      );
      expect(trip.joinCode, isNot('TRIP-AB12'));
      expect(trip.joinCode, 'TRIP-ZZ99');
      expect(colliding.joinCodes['TRIP-ZZ99'], trip.id);
    });

    test('exhausted retries throw', () async {
      final ds = MockTripDataSource(joinCodeGenerator: () => 'TRIP-AB12');
      ds.joinCodes['TRIP-AB12'] = 'trip_existing';
      expect(
        () => ds.createTrip(
          name: 'Stuck',
          origin: 'A',
          destination: 'B',
          hostUid: 'mock-uid',
        ),
        throwsStateError,
      );
    });
  });

  group('MockTripDataSource join', () {
    test("joinTrip('BAD') throws", () async {
      final ds = await _repo();
      expect(() => ds.joinTrip('BAD', uid: 'mock-uid'), throwsArgumentError);
    });

    test('joinTrip unknown well-formed code throws', () async {
      final ds = await _repo();
      expect(
        () => ds.joinTrip('TRIP-QQ99', uid: 'mock-uid'),
        throwsStateError,
      );
    });

    test('demo-uid join on real trip throws', () async {
      final ds = await _repo();
      final trip = await ds.createTrip(
        name: 'Real Ride',
        origin: 'A',
        destination: 'B',
        hostUid: 'mock-uid',
      );
      expect(
        () => ds.joinTrip(trip.joinCode, uid: 'demo-123'),
        throwsStateError,
      );
    });

    test('join adds member with default Car vehicle', () async {
      final ds = await _repo();
      final trip = await ds.createTrip(
        name: 'Group Ride',
        origin: 'A',
        destination: 'B',
        hostUid: 'host-uid',
      );
      final joined = await ds.joinTrip(trip.joinCode, uid: 'rider-2');
      expect(joined.id, trip.id);
      final member = ds.membersFor(trip.id).singleWhere(
            (m) => m.uid == 'rider-2',
          );
      expect(member.vehicleType, 'Car');
    });

    test('joinTrip throws when trip is full', () async {
      final ds = await _repo();
      final trip = await ds.createTrip(
        name: 'Small Ride',
        origin: 'A',
        destination: 'B',
        hostUid: 'host-uid',
        maxParticipants: 2,
      );
      await ds.joinTrip(trip.joinCode, uid: 'rider-2');
      expect(
        () => ds.joinTrip(trip.joinCode, uid: 'rider-3'),
        throwsStateError,
      );
      // Re-joining an existing member does not count as over capacity.
      await ds.joinTrip(trip.joinCode, uid: 'rider-2');
    });

    test('createTrip defaults maxParticipants to 5 (spec P0<=5)', () async {
      final ds = await _repo();
      final trip = await ds.createTrip(
        name: 'Default Cap',
        origin: 'A',
        destination: 'B',
        hostUid: 'mock-uid',
      );
      expect(trip.maxParticipants, 5);
    });
  });
}
