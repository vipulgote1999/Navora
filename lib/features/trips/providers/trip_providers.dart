import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/live_position.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/trip.dart';
import '../../../shared/repositories/trip_repository.dart';
import '../data/mock_trip_datasource.dart';

/// Default [TripRepository]. Mock in-memory; a later plan swaps in Firestore.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return MockTripDataSource();
});

/// All trips as a stream. Single [MockTripDataSource] downcast site in
/// non-test app code: non-mock repos fall back to an empty stream until a
/// Firestore-backed `watchAllTrips` exists. All widgets consume this instead
/// of downcasting the repo themselves.
final watchTripsProvider = StreamProvider<List<Trip>>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  if (repo is MockTripDataSource) return repo.watchAllTrips();
  return Stream.value(const <Trip>[]);
});

/// Members of [tripId]. Downcast lives here next to [watchTripsProvider].
/// Single-key watches only (e.g. the convoy map's focused trip) — list UIs
/// with a variable number of rows must use [tripMemberCountsProvider] /
/// [userTripIdsProvider] below, never one family watch per row.
final tripMembersProvider =
    Provider.family<List<Member>, String>((ref, tripId) {
      // Rebuild on trip-list emissions; value itself is unused.
      ref.watch(watchTripsProvider);
      final repo = ref.watch(tripRepositoryProvider);
      if (repo is MockTripDataSource) return repo.membersFor(tripId);
      return const <Member>[];
    });

/// Member count per trip id, computed in ONE place. List UIs watch this
/// once and look up `counts[id] ?? 0` per row instead of watching
/// [tripMembersProvider] inside dynamic loops (variable watch count is a
/// Riverpod anti-pattern). Rebuilds on [watchTripsProvider] emissions.
final tripMemberCountsProvider = Provider<Map<String, int>>((ref) {
  // Rebuild on trip-list emissions; value itself is unused.
  ref.watch(watchTripsProvider);
  final repo = ref.watch(tripRepositoryProvider);
  if (repo is MockTripDataSource) {
    return {
      for (final trip in repo.trips.values)
        trip.id: repo.membersFor(trip.id).length,
    };
  }
  return const <String, int>{};
});

/// Trip ids [uid] is a member of. Keyed by uid so consumers make ONE stable
/// watch call per build instead of one family watch per trip row.
final userTripIdsProvider =
    Provider.family<Set<String>, String>((ref, uid) {
      // Rebuild on trip-list emissions; value itself is unused.
      ref.watch(watchTripsProvider);
      final repo = ref.watch(tripRepositoryProvider);
      if (repo is MockTripDataSource) {
        return {
          for (final trip in repo.trips.values)
            if (repo.membersFor(trip.id).any((m) => m.uid == uid)) trip.id,
        };
      }
      return const <String>{};
    });

/// Live positions for [tripId], empty until P0-02 wires real GPS writes.
/// Mock [MockTripDataSource.watchLive] yields `[]`, so consumers must treat
/// empty as "unknown" (keep primary colors / createdAt proxy with TODO),
/// never as "everyone stale".
final livePositionsProvider =
    StreamProvider.family<List<LivePosition>, String>((ref, tripId) {
      return ref.watch(tripRepositoryProvider).watchLive(tripId);
    });
