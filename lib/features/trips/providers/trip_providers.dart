import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/live_position.dart';
import '../../../shared/repositories/trip_repository.dart';
import '../data/mock_trip_datasource.dart';

/// Default [TripRepository]. Mock in-memory; a later plan swaps in Firestore.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return MockTripDataSource();
});

/// Live positions for [tripId], empty until P0-02 wires real GPS writes.
/// Mock [MockTripDataSource.watchLive] yields `[]`, so consumers must treat
/// empty as "unknown" (keep primary colors / createdAt proxy with TODO),
/// never as "everyone stale".
final livePositionsProvider =
    StreamProvider.family<List<LivePosition>, String>((ref, tripId) {
      return ref.watch(tripRepositoryProvider).watchLive(tripId);
    });
