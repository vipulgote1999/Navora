import 'package:flutter_riverpod/legacy.dart';
import 'package:tripmesh/shared/models/trip.dart';

/// Camera follow behavior for the maps-home view.
enum FollowMode { none, me, convoy }

/// Bottom-nav index. 0 = Explore (maps-home).
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Current place/member search query.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Currently selected trip id, null when nothing selected.
final selectedTripIdProvider = StateProvider<String?>((ref) => null);

/// Camera follow mode for the map view.
final mapFollowModeProvider = StateProvider<FollowMode>(
  (ref) => FollowMode.none,
);

/// Default map center (Wagholi, Pune) — shared fallback for map + sheet.
const defaultMapCenterLat = 18.6545;
const defaultMapCenterLng = 73.9412;
const defaultMapZoom = 14.0;

/// Active trip id: explicit selection wins, else the most-recent trip.
/// `trips` arrive in insertion order (oldest first), so "last" is newest.
/// Null when [trips] is empty and nothing is selected.
String? activeTripId(List<Trip> trips, String? selected) {
  if (selected != null) return selected;
  return trips.isEmpty ? null : trips.last.id;
}

/// Case-insensitive trip filter for search: matches name/origin/destination.
/// Empty/blank query returns all trips.
List<Trip> filterTripsByQuery(List<Trip> trips, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return trips;
  return trips
      .where(
        (t) =>
            t.name.toLowerCase().contains(q) ||
            t.origin.toLowerCase().contains(q) ||
            t.destination.toLowerCase().contains(q),
      )
      .toList();
}
