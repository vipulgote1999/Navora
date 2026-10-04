import 'package:tripmesh/shared/models/live_position.dart';
import 'package:tripmesh/shared/models/trip.dart';

/// Trip data operations. Real Firestore + mock datasources implement this.
abstract class TripRepository {
  Future<Trip> createTrip({
    required String name,
    required String origin,
    required String destination,
    required String hostUid,
    int maxParticipants = 5,
  });

  Future<Trip> joinTrip(String code, {required String uid});

  Stream<Trip?> watchTrip(String tripId);

  Stream<List<LivePosition>> watchLive(String tripId);
}
