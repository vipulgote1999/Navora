import 'package:flutter_riverpod/legacy.dart';

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
