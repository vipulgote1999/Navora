import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navora/features/home/map/map_tiles.dart';
import 'package:navora/features/home/places/geocode_repository.dart';
import 'package:navora/features/home/places/place_poi.dart';
import 'package:navora/shared/models/trip.dart';

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

/// Last known real GPS fix. Null until My Location succeeds once.
/// Written by [MapFabs], consumed by [ConvoyMap] for follow-me + blue dot.
final myPositionProvider = StateProvider<LatLng?>((ref) => null);

/// GPS accuracy of [myPositionProvider] in meters. Null when unknown.
/// Sizes the blue-dot accuracy circle (clamped at render).
final myAccuracyMProvider = StateProvider<double?>((ref) => null);

/// Travel bearing of [myPositionProvider] in degrees (0-360).
/// Null when unknown or stationary — the heading wedge hides.
/// Written by [MapFabs], consumed by [ConvoyMap].
final myHeadingDegProvider = StateProvider<double?>((ref) => null);

/// Nearby OSM places for the current viewport. Refreshed on map idle
/// (zoom-gated, debounced, distance-gated by [ConvoyMap]); empty when
/// nothing fetched yet or the fetch failed.
final nearbyPoisProvider =
    StateProvider<List<PlacePoi>>((ref) => const []);

/// Live Nominatim suggestions for the search field. Written debounced by
/// [MapsSearchBar]; cleared on select or empty query.
final searchResultsProvider =
    StateProvider<List<PlaceSearchResult>>((ref) => const []);

/// In-flight search flag for the suggestion dropdown spinner.
final searchingProvider = StateProvider<bool>((ref) => false);

/// Accepted search result. [ConvoyMap] flies to it and pins it.
final searchFocusProvider =
    StateProvider<PlaceSearchResult?>((ref) => null);

/// Active base-map style. [ConvoyMap] switches MapLibre style on change.
final mapStyleProvider = StateProvider<MapStyle>((ref) => MapStyle.standard);

/// Renders the native MapLibre view when true.
///
/// Tests override this to false: platform views cannot pump in `flutter
/// test`, so [ConvoyMap] shows a placeholder pin with identical semantics
/// instead. Production always leaves this true.
final mapNativeProvider = StateProvider<bool>((ref) => true);

/// GPS ground speed in m/s. Null when unknown or stationary.
///
/// Written by [MapFabs] from the geolocator fix; consumed by the drive
/// camera for zoom-by-speed. Displayed by the speed badge (Task 6).
final mySpeedMpsProvider = StateProvider<double?>((ref) => null);

/// Default map center (Wagholi, Pune) — shared fallback for map + sheet.
const defaultMapCenterLat = 18.6545;
const defaultMapCenterLng = 73.9412;
const defaultMapZoom = 14.0;

/// Prefs key for the locally saved trip ids (string list).
const savedTripIdsKey = 'tripmesh_saved_ids';

/// Ids of trips the user saved. Hydrated once from prefs in
/// [MapShell.initState]; failures fall back to in-memory only, never throw.
final savedTripIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Exact system-share text for [trip].
String shareTextFor(Trip trip) =>
    'Join my Navora trip "${trip.name}" with code ${trip.joinCode}:\n'
    'navora://join/${trip.joinCode}';

/// Loads saved ids from prefs into [savedTripIdsProvider]. Silent on failure.
Future<void> loadSavedTripIds(WidgetRef ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(savedTripIdsKey);
    if (ids != null) {
      ref.read(savedTripIdsProvider.notifier).state = ids.toSet();
    }
  } catch (_) {
    // Offline/corrupt prefs: stay in-memory only, never throw.
  }
}

/// Toggles [id] in [savedTripIdsProvider] and persists. Silent on failure.
Future<void> toggleSavedTrip(WidgetRef ref, String id) async {
  final current = Set<String>.from(ref.read(savedTripIdsProvider));
  if (current.contains(id)) {
    current.remove(id);
  } else {
    current.add(id);
  }
  ref.read(savedTripIdsProvider.notifier).state = current;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(savedTripIdsKey, current.toList()..sort());
  } catch (_) {
    // Persist failed: in-memory state still updated, never throw.
  }
}

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
