import 'dart:async';

import '../../../core/utils/join_code.dart';
import '../../../shared/models/live_position.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/trip.dart';
import '../../../shared/repositories/trip_repository.dart';

/// In-memory [TripRepository] for tests, demos, and mock mode.
///
/// Mirrors the Firestore transaction parity documented in `firestore.rules`:
/// the `joinCodes` reservation map is claimed *before* the trip document is
/// written, and [createTrip] retries up to [maxCodeAttempts] on collision.
/// Demo UIDs (`demo-*`) are denied on real trips, matching the rules.
class MockTripDataSource implements TripRepository {
  /// Max join-code generation attempts before surfacing a collision error.
  static const int maxCodeAttempts = 3;

  /// tripId -> Trip, mirrors `trips/{tripId}`.
  final Map<String, Trip> trips = {};

  /// joinCode -> tripId reservation, mirrors `joinCodes/{code}`.
  final Map<String, String> joinCodes = {};

  /// tripId -> (uid -> Member), mirrors `trips/{tripId}/members/{uid}`.
  final Map<String, Map<String, Member>> _members = {};

  final String Function() _joinCodeGenerator;
  int _tripCounter = 0;

  MockTripDataSource({String Function()? joinCodeGenerator})
      : _joinCodeGenerator = joinCodeGenerator ?? generateJoinCode;

  /// Members of [tripId] in join order. Empty list for unknown trips.
  List<Member> membersFor(String tripId) =>
      List.unmodifiable(_members[tripId]?.values.toList() ?? const []);

  static bool _isDemoUid(String uid) => uid.startsWith('demo-');

  @override
  Future<Trip> createTrip({
    required String name,
    required String origin,
    required String destination,
    required String hostUid,
    int maxParticipants = 8,
  }) async {
    if (_isDemoUid(hostUid)) {
      throw StateError('Demo UIDs cannot create real trips.');
    }
    // Transaction parity: claim the joinCodes reservation first, retry on
    // collision (another trip already holding the generated code).
    for (var attempt = 0; attempt < maxCodeAttempts; attempt++) {
      final code = _joinCodeGenerator();
      if (!Trip.isValidJoinCode(code)) continue;
      if (joinCodes.containsKey(code)) continue;
      final id = 'trip_${++_tripCounter}';
      final trip = Trip(
        id: id,
        name: name,
        origin: origin,
        destination: destination,
        status: TripStatus.planning,
        hostUid: hostUid,
        joinCode: code,
        maxParticipants: maxParticipants,
      );
      joinCodes[code] = id;
      trips[id] = trip;
      _members[id] = {
        hostUid: Member(
          uid: hostUid,
          role: MemberRole.host,
          vehicleType: 'Car',
          vehicleLabel: '',
        ),
      };
      return trip;
    }
    throw StateError(
      'Could not reserve a unique join code after $maxCodeAttempts attempts.',
    );
  }

  @override
  Future<Trip> joinTrip(String code, {required String uid}) async {
    if (!Trip.isValidJoinCode(code)) {
      throw ArgumentError.value(code, 'code', 'Invalid join code format.');
    }
    if (_isDemoUid(uid)) {
      throw StateError('Demo UIDs are denied on real trips.');
    }
    final tripId = joinCodes[code];
    if (tripId == null) {
      throw StateError('No trip found for join code $code.');
    }
    final trip = trips[tripId];
    if (trip == null) {
      throw StateError('No trip found for join code $code.');
    }
    final members = _members.putIfAbsent(tripId, () => {});
    members.putIfAbsent(
      uid,
      () => Member(
        uid: uid,
        role: MemberRole.member,
        vehicleType: 'Car',
        vehicleLabel: '',
      ),
    );
    return trip;
  }

  @override
  Stream<Trip?> watchTrip(String tripId) async* {
    yield trips[tripId];
  }

  @override
  Stream<List<LivePosition>> watchLive(String tripId) async* {
    yield const <LivePosition>[];
  }
}
