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

/// Members of [tripId]. Downcast lives here next to [watchTripsProvider];
/// widgets must use this, never `repo as/is MockTripDataSource`. Watches
/// [watchTripsProvider] so create/join emissions refresh counts/lists.
final tripMembersProvider =
    Provider.family<List<Member>, String>((ref, tripId) {
      // Rebuild on trip-list emissions; value itself is unused.
      ref.watch(watchTripsProvider);
      final repo = ref.watch(tripRepositoryProvider);
      if (repo is MockTripDataSource) return repo.membersFor(tripId);
      return const <Member>[];
    });

/// Live positions for [tripId], empty until P0-02 wires real GPS writes.
/// Mock [MockTripDataSource.watchLive] yields `[]`, so consumers must treat
/// empty as "unknown" (keep primary colors / createdAt proxy with TODO),
/// never as "everyone stale".
final livePositionsProvider =
    StreamProvider.family<List<LivePosition>, String>((ref, tripId) {
      return ref.watch(tripRepositoryProvider).watchLive(tripId);
    });
