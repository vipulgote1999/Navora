import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/trip_repository.dart';
import '../data/mock_trip_datasource.dart';

/// Default [TripRepository]. Mock in-memory; a later plan swaps in Firestore.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return MockTripDataSource();
});
