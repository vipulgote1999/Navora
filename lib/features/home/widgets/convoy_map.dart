import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';

/// OSM light tiles (CARTO dark when the theme is dark).
const lightTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const darkTileUrl =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

/// Shared convoy map center (Wagholi, Pune).
const convoyMapCenter = LatLng(defaultMapCenterLat, defaultMapCenterLng);

/// Deterministic mock position for member [uid] at join [index]:
/// base center + `index * 0.002` on lat/lng.
LatLng memberOffset(String uid, int index) => LatLng(
  defaultMapCenterLat + index * 0.002,
  defaultMapCenterLng + index * 0.002,
);

/// OSM convoy map canvas: tile layer + destination H pin + member pins.
///
/// Marker taps write [selectedTripIdProvider]. Tile errors are swallowed via
/// [TileLayer.errorTileCallback] so offline use shows an empty grid, no crash.
class ConvoyMap extends ConsumerWidget {
  const ConvoyMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tripRepositoryProvider);
    final selectedId = ref.watch(selectedTripIdProvider);
    // TODO(P0-02): replace MockTripDataSource downcast with a watchTrips
    // provider/stream; downcast is a P0-01 stopgap, do not expand its use.
    final trips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    Trip? active;
    if (selectedId != null) {
      for (final t in trips) {
        if (t.id == selectedId) active = t;
      }
    }
    active ??= trips.isNotEmpty ? trips.last : null;
    final activeId = active?.id ?? 'mock-trip';
    final members = active != null && repo is MockTripDataSource
        ? repo.membersFor(active.id)
        : const [];

    void select() =>
        ref.read(selectedTripIdProvider.notifier).state = activeId;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FlutterMap(
      options: const MapOptions(
        initialCenter: convoyMapCenter,
        initialZoom: defaultMapZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: isDark ? darkTileUrl : lightTileUrl,
          userAgentPackageName: 'tripmesh',
          errorTileCallback: (tile, error, stack) {},
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: convoyMapCenter,
              width: 48,
              height: 48,
              child: GestureDetector(
                onTap: select,
                child: Semantics(
                  label: 'Trip destination',
                  button: true,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'H',
                      semanticsLabel: '',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < members.length; i++)
              Marker(
                point: memberOffset(members[i].uid, i),
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: select,
                  child: Semantics(
                    label: 'Convoy member ${members[i].uid}',
                    button: true,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        members[i].uid.isEmpty
                            ? '?'
                            : members[i].uid[0].toUpperCase(),
                        semanticsLabel: '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
          // Open on load so attribution is visible (and testable) immediately.
          // Zero auto-hide duration: the popup still renders on the first
          // frame, but no 5s Timer outlives the widget-test fake clock
          // (MapShell's drawer test settles via pumpAndSettle, which never
          // advances 5s, and teardown fails on pending timers).
          popupInitialDisplayDuration: Duration.zero,
        ),
      ],
    );
  }
}
