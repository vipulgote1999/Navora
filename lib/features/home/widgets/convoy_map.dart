import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:navora/features/home/places/geocode_repository.dart';
import 'package:navora/features/home/places/place_poi.dart';
import 'package:navora/features/home/places/places_repository.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';
import 'package:navora/shared/models/live_position.dart';
import 'package:navora/shared/models/trip.dart';

/// OSM standard tiles for both themes (keyless). CARTO dark_all now
/// requires an API key, so dark mode reuses OSM to avoid the watermark.
const lightTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const darkTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Shared convoy map center (Wagholi, Pune).
const convoyMapCenter = LatLng(defaultMapCenterLat, defaultMapCenterLng);

/// Deterministic mock position for member [uid] at join [index]:
/// base center + `index * 0.002` on lat/lng.
LatLng memberOffset(String uid, int index) => LatLng(
  defaultMapCenterLat + index * 0.002,
  defaultMapCenterLng + index * 0.002,
);

/// Per-member pin: grey only when a live position exists and is stale
/// ([LivePosition.isStale], 90s). Unknown (no live fix) keeps [primary] —
/// see the watchLive TODO in [_ConvoyMapState.build].
class _MemberPin extends StatelessWidget {
  const _MemberPin({
    required this.uid,
    required this.live,
    required this.now,
    required this.primary,
    required this.onTap,
  });

  final String uid;
  final LivePosition? live;
  final DateTime now;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stale = live != null && live!.isStale(now);
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Convoy member $uid',
        button: true,
        child: Container(
          decoration: BoxDecoration(
            color: stale ? Colors.grey : primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            uid.isEmpty ? '?' : uid[0].toUpperCase(),
            semanticsLabel: '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Google-Maps-style heading wedge: a soft cone pointing along [headingDeg]
/// (0 = north). Painted behind the blue dot, hidden while stationary.
class _HeadingWedge extends StatelessWidget {
  final double headingDeg;

  const _HeadingWedge({required this.headingDeg});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: headingDeg * math.pi / 180,
      child: CustomPaint(
        size: const Size(44, 44),
        painter: _WedgePainter(),
      ),
    );
  }
}

class _WedgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.withAlpha(90);
    final path = Path()
      ..moveTo(size.width / 2, 2)
      ..lineTo(size.width / 2 - 9, size.height / 2 + 6)
      ..lineTo(size.width / 2 + 9, size.height / 2 + 6)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Grey Google-style POI pin: dot on the coordinate, name below.
class _PoiPin extends StatelessWidget {
  final PlacePoi poi;
  final VoidCallback onTap;

  const _PoiPin({required this.poi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: '${poi.name}, ${poi.kind}',
        button: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF757575),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            Text(
              poi.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF616161)),
            ),
          ],
        ),
      ),
    );
  }
}
/// OSM convoy map canvas: tiles + destination H pin + member pins +
/// Google-style my-location dot (accuracy circle, heading wedge) + nearby
/// OSM place pins (fetched on map idle, zoom-gated, debounced).
///
/// Marker taps write [selectedTripIdProvider]. Tile errors never crash
/// ([TileLayer.errorTileCallback] is a no-op) and failed tiles render an
/// inline `Failed to load map tiles — check connection` retry widget —
/// tapping it bumps a local [ValueKey] to refetch, markers keep rendering.
/// Consumes [mapFollowModeProvider] (write path: [MapFabs]) via a
/// [MapController]: follow-me moves to the real GPS fix in
/// [myPositionProvider]; convoy (and me-before-first-fix) centers the trip
/// area at [convoyMapCenter]. A blue dot marks the real fix when known.
class ConvoyMap extends ConsumerStatefulWidget {
  const ConvoyMap({super.key});

  @override
  ConsumerState<ConvoyMap> createState() => _ConvoyMapState();
}

class _ConvoyMapState extends ConsumerState<ConvoyMap> {
  final _mapController = MapController();
  final _places = PlacesRepository();
  static const _distance = Distance();

  /// Bumped on tile-error retry tap; [ValueKey] on [TileLayer] refetches.
  int _tileRetryKey = 0;

  /// POI fetch gating: debounced, zoom-gated, distance-gated.
  Timer? _poiDebounce;
  LatLng? _lastPoiAt;
  double? _lastPoiZoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePoiFetch());
  }

  @override
  void dispose() {
    _poiDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) _schedulePoiFetch();
  }

  void _schedulePoiFetch() {
    _poiDebounce?.cancel();
    _poiDebounce = Timer(const Duration(milliseconds: 700), _fetchPois);
  }

  /// Refreshes [nearbyPoisProvider] for the current viewport.
  /// Skipped below z14 or when the camera barely moved. A failed fetch
  /// yields [] and must not wipe already-shown pins, so empty results
  /// overwrite state only when nothing is shown yet.
  Future<void> _fetchPois() async {
    late final LatLng center;
    late final double zoom;
    try {
      center = _mapController.camera.center;
      zoom = _mapController.camera.zoom;
    } catch (_) {
      return; // Controller not attached yet.
    }
    if (zoom < 14) return;
    final last = _lastPoiAt;
    if (last != null &&
        _lastPoiZoom != null &&
        (zoom - _lastPoiZoom!).abs() < 0.5 &&
        _distance.as(LengthUnit.Meter, last, center) < 250) {
      return;
    }
    final pois = await _places.fetchNearby(lat: center.latitude, lng: center.longitude);
    if (!mounted) return;
    if (pois.isNotEmpty || ref.read(nearbyPoisProvider).isEmpty) {
      ref.read(nearbyPoisProvider.notifier).state = pois;
    }
    _lastPoiAt = center;
    _lastPoiZoom = zoom;
  }

  void _follow(FollowMode mode) {
    if (mode == FollowMode.none) return;
    // Post-frame: the controller may not be attached yet on first listen.
    // FollowMode.me targets the real GPS fix; without one yet (or for
    // convoy) fall back to the trip area. Never jump to a stale default
    // as if it were the user's position.
    final me = ref.read(myPositionProvider);
    final target = (mode == FollowMode.me && me != null)
        ? me
        : convoyMapCenter;
    final zoom = (mode == FollowMode.me && me != null)
        ? defaultMapZoom + 1
        : defaultMapZoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(target, zoom);
      } catch (_) {
        // Controller not attached yet (e.g. test teardown): stay put.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FollowMode>(mapFollowModeProvider, (_, next) => _follow(next));
    ref.listen<PlaceSearchResult?>(searchFocusProvider, (_, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(LatLng(next.lat, next.lng), 15);
        } catch (_) {
          // Controller not attached yet: stay put.
        }
      });
    });

    final tripsAsync = ref.watch(watchTripsProvider);
    final selectedId = ref.watch(selectedTripIdProvider);
    final trips = tripsAsync.value ?? const <Trip>[];
    final resolvedId = activeTripId(trips, selectedId);
    Trip? active;
    if (resolvedId != null) {
      for (final t in trips) {
        if (t.id == resolvedId) active = t;
      }
    }
    active ??= trips.isNotEmpty ? trips.last : null;
    final activeId = active?.id ?? 'mock-trip';
    final members = active == null
        ? const []
        : ref.watch(tripMembersProvider(active.id));

    // Live liveness: consumed where available via livePositionsProvider.
    // TODO(P0-02): Member carries no timestamp, so per-member staleness is
    // honest only when watchLive yields positions (mock yields [] — markers
    // keep the primary color, never grey). Do not grey on empty.
    final liveAsync = ref.watch(livePositionsProvider(activeId));
    final live = liveAsync.value ?? const <LivePosition>[];
    final now = DateTime.now();
    final byUid = <String, LivePosition>{for (final p in live) p.uid: p};
    final me = ref.watch(myPositionProvider);
    final accuracyM = ref.watch(myAccuracyMProvider);
    final headingDeg = ref.watch(myHeadingDegProvider);
    final pois = ref.watch(nearbyPoisProvider);
    final searchFocus = ref.watch(searchFocusProvider);
    final routes = ref.watch(routesProvider).value ?? const <TripRoute>[];
    final selected = ref.watch(selectedRouteIndexProvider);
    final selectedRoute =
        routes.isEmpty ? null : routes[selected.clamp(0, routes.length - 1)];

    void select() =>
        ref.read(selectedTripIdProvider.notifier).state = activeId;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: convoyMapCenter,
        initialZoom: defaultMapZoom,
        onMapEvent: _onMapEvent,
      ),
      children: [
        TileLayer(
          key: ValueKey<int>(_tileRetryKey),
          urlTemplate: isDark ? darkTileUrl : lightTileUrl,
          userAgentPackageName: 'navora',
          errorTileCallback: (tile, error, stack) {},
          tileBuilder: (context, tileWidget, tile) {
            if (!tile.loadError) return tileWidget;
            return GestureDetector(
              onTap: () => setState(() => _tileRetryKey++),
              child: Container(
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                child: Text(
                  'Failed to load map tiles — check connection',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        ),
        if (routes.isNotEmpty)
          PolylineLayer(
            polylines: [
              // Gray alternates first, selected route (teal) on top —
              // Maps-style: alternates visible but clearly unselected.
              for (var i = 0; i < routes.length; i++)
                if (routes[i].points.length >= 2 &&
                    routes[i] != selectedRoute)
                  Polyline(
                    points: routes[i].points,
                    strokeWidth: 4,
                    color: Colors.grey,
                  ),
              if (selectedRoute != null &&
                  selectedRoute.points.length >= 2)
                Polyline(
                  points: selectedRoute.points,
                  strokeWidth: 5,
                  // Google Maps route blue (alternates stay gray).
                  color: const Color(0xFF4285F4),
                ),
            ],
          ),
        if (me != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: me,
                radius: (accuracyM ?? 40).clamp(15, 250).toDouble(),
                useRadiusInMeter: true,
                color: Colors.blue.withAlpha(36),
                borderColor: Colors.blue.withAlpha(110),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: convoyMapCenter,
              width: 40,
              height: 40,
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
                        fontSize: 16,
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
                child: _MemberPin(
                  uid: members[i].uid,
                  live: byUid[members[i].uid],
                  now: now,
                  primary: colorScheme.primary,
                  onTap: select,
                ),
              ),
            if (me != null) ...[
              if (headingDeg != null)
                Marker(
                  point: me,
                  width: 44,
                  height: 44,
                  child: _HeadingWedge(headingDeg: headingDeg),
                ),
              Marker(
                point: me,
                width: 20,
                height: 20,
                child: Semantics(
                  label: 'Your current location',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            for (final poi in pois)
              Marker(
                point: LatLng(poi.lat, poi.lng),
                width: 84,
                height: 36,
                child: _PoiPin(
                  poi: poi,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${poi.name} · ${poi.kind}')),
                    );
                  },
                ),
              ),
            if (searchFocus != null)
              Marker(
                point: LatLng(searchFocus.lat, searchFocus.lng),
                width: 120,
                height: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Search result ${searchFocus.title}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          searchFocus.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.place,
                      color: Colors.red,
                      size: 28,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
          // Open on load so attribution is visible (and testable) immediately.
          popupInitialDisplayDuration: Duration(seconds: 5),
        ),
      ],
    );
    if (!tripsAsync.hasError) return map;
    // Stream error: keep the map, banner the failure with a retry.
    return Stack(
      children: [
        map,
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Expanded(child: Text("Couldn't load trips")),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => ref.invalidate(watchTripsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
