import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:navora/features/home/map/map_tiles.dart';
import 'package:navora/features/home/places/geocode_repository.dart';
import 'package:navora/features/home/places/places_repository.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/tracking/location_permission.dart';
import 'package:navora/features/navigation/drive_camera.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';
import 'package:navora/shared/models/live_position.dart';
import 'package:navora/shared/models/member.dart';
import 'package:navora/shared/models/trip.dart';

/// Shared convoy map center (Wagholi, Pune).
const convoyMapCenter = LatLng(defaultMapCenterLat, defaultMapCenterLng);

/// Deterministic mock position for member [uid] at join [index]:
/// base center + `index * 0.002` on lat/lng.
LatLng memberOffset(String uid, int index) => LatLng(
      defaultMapCenterLat + index * 0.002,
      defaultMapCenterLng + index * 0.002,
    );

/// Drive-mode tilt in degrees (MapLibre pitch).
const double _driveTilt = 60.0;

/// Route lines arrive in Task 4b; until then the canvas shows camera +
/// markers only.

ml.LatLng _mlLatLng(LatLng p) => ml.LatLng(p.latitude, p.longitude);

LatLng _toLatLng(ml.LatLng p) => LatLng(p.latitude, p.longitude);

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// OSM convoy map canvas on MapLibre vector tiles (OpenFreeMap, keyless).
///
/// Same provider contract as before: consumes [mapFollowModeProvider]
/// (write path: [MapFabs]), [myPositionProvider] for follow-me + chevron,
/// trip/member providers for pins, [nearbyPoisProvider] for place pins.
/// While guiding + following, the camera rides the fix course-up at
/// tilt 60 with the chevron at the lower third (see [drive_camera.dart]).
/// A manual pan breaks follow (camera-move heuristic below); the recenter
/// FAB restores `FollowMode.me`. Markers are MapLibre symbols/circles;
/// taps route through [_tapActions] by symbol id.
class ConvoyMap extends ConsumerStatefulWidget {
  const ConvoyMap({super.key});

  @override
  ConsumerState<ConvoyMap> createState() => _ConvoyMapState();
}

class _ConvoyMapState extends ConsumerState<ConvoyMap> {
  ml.MapLibreMapController? _ml;
  final _places = PlacesRepository();
  static const _distance = Distance();

  /// Style-load watchdog: without `onStyleLoaded` in 12s the retry card
  /// shows; retry re-sets the style (never a blank map).
  Timer? _styleTimer;
  bool _styleLoaded = false;
  bool _styleFailed = false;
  final int _styleKey = 0;

  /// Annotation handles by stable key (`dest`, `m-<uid>`, `me-bg`,
  /// `me-arrow`, `me-acc`, `poi-<i>`, `search`).
  final Map<String, ml.Symbol> _syms = {};
  final Map<String, ml.Circle> _circles = {};
  final Map<String, Map<String, String>> _tapActions = {};

  /// Route line handles. Rebuilt only when the route signature changes
  /// ([_linesKey]) — never per frame.
  final List<ml.Line> _altLines = [];
  String _linesKey = '';
  bool _esriAdded = false;

  /// Smoothed camera heading + last sent target (throttle state).
  double _smooth = 0;
  LatLng? _lastSentTarget;
  double _lastSentHeading = 0;

  /// True while a programmatic `animateCamera` is in flight; camera moves
  /// otherwise are the user's — those break follow.
  bool _progMove = false;

  /// Last observed camera center/zoom (for POI fetch gating).
  ml.LatLng? _camCenter;
  double _camZoom = defaultMapZoom;

  /// POI fetch gating: debounced, zoom-gated, distance-gated.
  Timer? _poiDebounce;
  LatLng? _lastPoiAt;
  double? _lastPoiZoom;

  @override
  void dispose() {
    _poiDebounce?.cancel();
    _styleTimer?.cancel();
    super.dispose();
  }

  void _onCreated(ml.MapLibreMapController c) {
    _ml = c;
    c.onSymbolTapped.add(_onSymbolTapped);
    _styleTimer?.cancel();
    _styleTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _styleLoaded) return;
      setState(() => _styleFailed = true);
    });
    _applyFollow(ref.read(mapFollowModeProvider));
  }

  void _onStyleLoaded() {
    _styleTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _styleLoaded = true;
      _styleFailed = false;
    });
    unawaited(_addSatelliteOverlay());
    unawaited(_syncSymbols());
  }

  /// Esri World Imagery overlay for satellite style (hybrid look).
  ///
  /// No-op unless satellite is active. Runs after every style load
  /// because a style reset wipes sources. Never throws.
  Future<void> _addSatelliteOverlay() async {
    final c = _ml;
    if (c == null) return;
    if (ref.read(mapStyleProvider) != MapStyle.satellite) return;
    if (_esriAdded) return;
    try {
      // MapLibre substitutes {x}/{y}/{z} by name, so Esri's z/y/x
      // order in the template is honored as-is.
      await c.addSource(
        'esri',
        ml.RasterSourceProperties(tiles: [esriRasterTemplate]),
      );
      await c.addRasterLayer('esri', 'esri-layer', ml.RasterLayerProperties());
      _esriAdded = true;
    } catch (_) {
      // Offline / source exists: labels-only map still works.
    }
  }

  void _retryStyle() {
    final c = _ml;
    if (c == null) return;
    setState(() {
      _styleFailed = false;
      _styleLoaded = false;
    });
    unawaited(c.setStyle(mapStyleUrl(ref.read(mapStyleProvider))));
    _styleTimer?.cancel();
    _styleTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _styleLoaded) return;
      setState(() => _styleFailed = true);
    });
  }

  Future<void> _driveTo(
    LatLng target,
    double zoom,
    double bearing,
    double tilt,
  ) async {
    final c = _ml;
    if (c == null) return;
    _progMove = true;
    try {
      await c.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: _mlLatLng(target),
            zoom: zoom,
            bearing: bearing,
            tilt: tilt,
          ),
        ),
        duration: const Duration(milliseconds: 300),
      );
    } catch (_) {
      // Controller detached (e.g. test teardown): stay put.
    } finally {
      _progMove = false;
    }
  }

  void _applyFollow(FollowMode mode) {
    if (mode == FollowMode.none || _ml == null) return;
    final me = ref.read(myPositionProvider);
    final navigating = ref.read(navigatingProvider);
    final target =
        (mode == FollowMode.me && me != null) ? me : convoyMapCenter;
    final speed = ref.read(mySpeedMpsProvider);
    final zoom = (mode == FollowMode.me && me != null)
        ? (navigating
            ? (speed == null ? 16.0 : zoomForSpeed(speed))
            : defaultMapZoom + 1)
        : defaultMapZoom;
    final tilt = navigating ? _driveTilt : 0.0;
    unawaited(_driveTo(target, zoom, navigating ? _smooth : 0.0, tilt));
    _lastSentTarget = target;
  }

  /// Immediate jump to the current fix on entering guidance (Google Maps:
  /// Navigate disappears, camera is already on the chevron).
  void _moveToMeNow() {
    final me = ref.read(myPositionProvider);
    if (me == null) return;
    final speed = ref.read(mySpeedMpsProvider);
    unawaited(_driveTo(
      me,
      speed == null ? 16.0 : zoomForSpeed(speed),
      _smooth,
      _driveTilt,
    ));
    _lastSentTarget = me;
  }

  void _onCameraMove(ml.CameraPosition pos) {
    _camCenter = pos.target;
    _camZoom = pos.zoom;
    // Google Maps: a manual pan breaks follow so continuous tracking
    // never fights the user. Programmatic moves set [_progMove].
    if (!_progMove && ref.read(mapFollowModeProvider) != FollowMode.none) {
      ref.read(mapFollowModeProvider.notifier).state = FollowMode.none;
    }
  }

  void _onCameraIdle() {
    _schedulePoiFetch();
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
    final center = _camCenter;
    if (center == null) return;
    final zoom = _camZoom;
    if (zoom < 14) return;
    final at = _toLatLng(center);
    final last = _lastPoiAt;
    if (last != null &&
        _lastPoiZoom != null &&
        (zoom - _lastPoiZoom!).abs() < 0.5 &&
        _distance.as(LengthUnit.Meter, last, at) < 250) {
      return;
    }
    final pois =
        await _places.fetchNearby(lat: at.latitude, lng: at.longitude);
    if (!mounted) return;
    if (pois.isNotEmpty || ref.read(nearbyPoisProvider).isEmpty) {
      ref.read(nearbyPoisProvider.notifier).state = pois;
    }
    _lastPoiAt = at;
    _lastPoiZoom = zoom;
  }

  /// Reconciles MapLibre symbols/circles with current provider state.
  ///
  /// No-op until the style loads (annotations need a live style).
  /// Keys keep handles stable across rebuilds; surplus annotations are
  /// removed. Member pins are colored circles + initial letter; the own
  /// position is a blue circle + white rotated triangle (chevron).
  Future<void> _syncSymbols() async {
    final c = _ml;
    if (c == null || !_styleLoaded) return;
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();

    final tripsAsync = ref.read(watchTripsProvider);
    final trips = tripsAsync.value ?? const <Trip>[];
    final active = _resolveActive(trips, ref.read(selectedTripIdProvider));
    final activeId = active?.id ?? 'mock-trip';
    final members =
        active == null ? const <Member>[] : ref.read(tripMembersProvider(active.id));
    final liveAsync = ref.read(livePositionsProvider(activeId));
    final live = liveAsync.value ?? const <LivePosition>[];
    final byUid = <String, LivePosition>{for (final p in live) p.uid: p};

    final me = ref.read(myPositionProvider);
    final pois = ref.read(nearbyPoisProvider);
    final searchFocus = ref.read(searchFocusProvider);

    final keep = <String>{};
    try {
      // Destination pin.
      keep.add('dest');
      await _upsertSymbol(
        c,
        'dest',
        ml.SymbolOptions(
          geometry: _mlLatLng(convoyMapCenter),
          iconImage: 'marker',
          iconSize: 1.4,
          iconColor: '#E53935',
        ),
        {'kind': 'trip'},
      );
      // Member pins.
      for (var i = 0; i < members.length; i++) {
        final m = members[i];
        final key = 'm-${m.uid}';
        keep.add(key);
        final stale = byUid[m.uid]?.isStale(now) ?? false;
        final color = stale ? Colors.grey : primary;
        await _upsertCircle(
          c,
          key,
          ml.CircleOptions(
            geometry: _mlLatLng(memberOffset(m.uid, i)),
            circleRadius: 10,
            circleColor: _hex(color),
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
        keep.add('$key-label');
        await _upsertSymbol(
          c,
          '$key-label',
          ml.SymbolOptions(
            geometry: _mlLatLng(memberOffset(m.uid, i)),
            textField: m.uid.isEmpty ? '?' : m.uid[0].toUpperCase(),
            textSize: 12,
            textColor: '#FFFFFF',
          ),
          {'kind': 'trip'},
        );
      }
      // Own chevron.
      if (me != null) {
        keep.add('me-bg');
        await _upsertCircle(
          c,
          'me-bg',
          ml.CircleOptions(
            geometry: _mlLatLng(me),
            circleRadius: 9,
            circleColor: '#4285F4',
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
        keep.add('me-arrow');
        await _upsertSymbol(
          c,
          'me-arrow',
          ml.SymbolOptions(
            geometry: _mlLatLng(me),
            iconImage: 'triangle',
            iconSize: 1.2,
            iconColor: '#FFFFFF',
            iconRotate: _smooth,
          ),
          const {},
        );
        // GPS accuracy halo, sized from meters-per-pixel.
        keep.add('me-acc');
        final accuracyM = ref.read(myAccuracyMProvider);
        double radius = 24;
        try {
          final mpp = await c.getMetersPerPixelAtLatitude(me.latitude);
          radius =
              ((accuracyM ?? 40) / mpp).clamp(8, 60).toDouble();
        } catch (_) {}
        await _upsertCircle(
          c,
          'me-acc',
          ml.CircleOptions(
            geometry: _mlLatLng(me),
            circleRadius: radius,
            circleColor: '#4285F4',
            circleOpacity: 0.25,
          ),
        );
      }
      // POI pins.
      for (var i = 0; i < pois.length; i++) {
        final key = 'poi-$i';
        keep.add(key);
        await _upsertSymbol(
          c,
          key,
          ml.SymbolOptions(
            geometry: ml.LatLng(pois[i].lat, pois[i].lng),
            iconImage: 'dot_11',
            textField: pois[i].name,
            textSize: 10,
            textColor: '#616161',
            textAnchor: 'top',
          ),
          {'kind': 'poi', 'name': pois[i].name, 'label': pois[i].kind},
        );
      }
      // Search pin.
      if (searchFocus != null) {
        keep.add('search');
        await _upsertSymbol(
          c,
          'search',
          ml.SymbolOptions(
            geometry: ml.LatLng(searchFocus.lat, searchFocus.lng),
            iconImage: 'marker',
            iconSize: 1.4,
            iconColor: '#1A73E8',
            textField: searchFocus.title,
            textSize: 12,
          ),
          const {},
        );
      }
      // Drop surplus.
      for (final key in _syms.keys.toList()) {
        if (!keep.contains(key)) {
          try {
            await c.removeSymbol(_syms.remove(key)!);
          } catch (_) {}
          _tapActions.remove(key);
        }
      }
      for (final key in _circles.keys.toList()) {
        if (!keep.contains(key)) {
          try {
            await c.removeCircle(_circles.remove(key)!);
          } catch (_) {}
        }
      }
      await _syncLines();
    } catch (_) {
      // Style torn down mid-sync (e.g. style switch): next sync repairs.
    }
  }

  /// Reconciles route polylines as MapLibre lines.
  ///
  /// Selected route in Google blue on top, alternates gray beneath —
  /// Maps-style. Rebuilds only when the route signature changes; the
  /// legacy `activeRouteProvider` stack draws the same blue line. No-op
  /// until the style loads.
  Future<void> _syncLines() async {
    final c = _ml;
    if (c == null || !_styleLoaded) return;
    final routes = ref.read(routesProvider).value ?? const <TripRoute>[];
    final selected = ref.read(selectedRouteIndexProvider);
    final sel = routes.isEmpty
        ? null
        : routes[selected.clamp(0, routes.length - 1)];
    final activeRoute = ref.read(activeRouteProvider);
    final key =
        '${routes.length}:$selected:${sel?.points.length ?? 0}:${activeRoute?.points.length ?? 0}';
    if (key == _linesKey) return;
    _linesKey = key;
    try {
      await c.clearLines();
      _altLines.clear();
      for (final r in routes) {
        if (r.points.length < 2 || r == sel) continue;
        _altLines.add(await c.addLine(
          ml.LineOptions(
            geometry: [for (final p in r.points) _mlLatLng(p)],
            lineColor: '#9AA0A6',
            lineWidth: 4,
            lineOpacity: 0.8,
          ),
        ));
      }
      final List<LatLng>? mainPoints = sel?.points ??
          ((activeRoute?.points.length ?? 0) >= 2
              ? activeRoute!.points
              : null);
      if (mainPoints != null && mainPoints.length >= 2) {
        final selLine = await c.addLine(
          ml.LineOptions(
            geometry: [for (final p in mainPoints) _mlLatLng(p)],
            lineColor: '#4285F4',
            lineWidth: 5,
          ),
        );
        _altLines.add(selLine);
      }
    } catch (_) {
      // Style torn down mid-sync: mark stale so the next style load
      // rebuilds (handles are reset there).
      _linesKey = '$key-stale';
    }
  }

  Future<void> _upsertSymbol(
    ml.MapLibreMapController c,
    String key,
    ml.SymbolOptions options,
    Map<String, String> action,
  ) async {
    final existing = _syms[key];
    if (existing == null) {
      _syms[key] = await c.addSymbol(options, action);
    } else {
      await c.updateSymbol(existing, options);
      if (action.isNotEmpty) {
        _tapActions[key] = action;
      }
    }
    if (action.isNotEmpty) {
      _tapActions[key] = action;
    }
  }

  Future<void> _upsertCircle(
    ml.MapLibreMapController c,
    String key,
    ml.CircleOptions options,
  ) async {
    final existing = _circles[key];
    if (existing == null) {
      _circles[key] = await c.addCircle(options);
    } else {
      await c.updateCircle(existing, options);
    }
  }

  void _onSymbolTapped(ml.Symbol symbol) {
    final action = _tapActions[symbol.id];
    if (action == null) return;
    if (action['kind'] == 'trip') {
      final trips = ref.read(watchTripsProvider).value ?? const <Trip>[];
      final active =
          _resolveActive(trips, ref.read(selectedTripIdProvider));
      ref.read(selectedTripIdProvider.notifier).state =
          active?.id ?? 'mock-trip';
    } else if (action['kind'] == 'poi' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${action['name']} · ${action['label']}')),
      );
    }
  }

  Trip? _resolveActive(List<Trip> trips, String? selectedId) {
    final resolvedId = activeTripId(trips, selectedId);
    if (resolvedId != null) {
      for (final t in trips) {
        if (t.id == resolvedId) return t;
      }
    }
    return trips.isNotEmpty ? trips.last : null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FollowMode>(mapFollowModeProvider, (_, next) {
      _applyFollow(next);
      unawaited(_syncSymbols());
    });
    // Entering navigation jumps straight to the current fix.
    ref.listen<bool>(navigatingProvider, (_, navigating) {
      if (!navigating) return;
      if (ref.read(mapFollowModeProvider) != FollowMode.me) return;
      _moveToMeNow();
    });
    // Position updates: ride the fix while guiding + following (throttled
    // by [shouldUpdateCamera]); outside navigation keep first-fix-only.
    ref.listen<LatLng?>(myPositionProvider, (prev, next) {
      if (next == null) return;
      if (ref.read(mapFollowModeProvider) != FollowMode.me) return;
      final headingDeg = ref.read(myHeadingDegProvider);
      if (headingDeg != null) {
        _smooth = smoothHeading(_smooth, headingDeg);
      }
      if (ref.read(navigatingProvider)) {
        final speed = ref.read(mySpeedMpsProvider);
        final zoom = speed == null ? 16.0 : zoomForSpeed(speed);
        final fwd = forwardMetersForZoom(zoom, next.latitude);
        final target = aheadPoint(next, _smooth, fwd);
        final lastTarget = _lastSentTarget;
        final send = lastTarget == null ||
            shouldUpdateCamera(
              prev: lastTarget,
              next: target,
              prevHeading: _lastSentHeading,
              nextHeading: _smooth,
            );
        if (!send) return;
        _lastSentTarget = target;
        _lastSentHeading = _smooth;
        unawaited(_driveTo(target, zoom, _smooth, _driveTilt));
        unawaited(_syncSymbols());
        return;
      }
      if (!shouldAutoCenter(
        mode: ref.read(mapFollowModeProvider),
        prev: prev,
        next: next,
      )) {
        return;
      }
      _lastSentTarget = next;
      unawaited(_driveTo(next, defaultMapZoom + 1, 0, 0));
      unawaited(_syncSymbols());
    });
    ref.listen<PlaceSearchResult?>(searchFocusProvider, (_, next) {
      if (next == null) return;
      unawaited(
          _driveTo(LatLng(next.lat, next.lng), 15, 0, 0));
      unawaited(_syncSymbols());
    });
    ref.listen<MapStyle>(mapStyleProvider, (_, next) {
      final c = _ml;
      if (c == null) return;
      // A style reset wipes native annotations: drop handles so the
      // post-load sync rebuilds everything (lines, pins, overlay).
      _syms.clear();
      _circles.clear();
      _tapActions.clear();
      _altLines.clear();
      _linesKey = '';
      _esriAdded = false;
      setState(() {
        _styleLoaded = false;
        _styleFailed = false;
      });
      unawaited(c.setStyle(mapStyleUrl(next)));
    });

    final native = ref.watch(mapNativeProvider);
    // Keep symbols fresh on provider changes that listeners miss.
    ref.watch(nearbyPoisProvider);
    ref.watch(myHeadingDegProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSymbols());

    final map = native
        ? ml.MapLibreMap(
            key: ValueKey<int>(_styleKey),
            styleString: mapStyleUrl(ref.watch(mapStyleProvider)),
            initialCameraPosition: ml.CameraPosition(
              target: _mlLatLng(convoyMapCenter),
              zoom: defaultMapZoom,
            ),
            myLocationEnabled: true,
            compassEnabled: false,
            onMapCreated: _onCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          )
        : _MapPlaceholder(
            onDestinationTap: () {
              final trips =
                  ref.read(watchTripsProvider).value ?? const <Trip>[];
              final active = _resolveActive(
                  trips, ref.read(selectedTripIdProvider));
              ref.read(selectedTripIdProvider.notifier).state =
                  active?.id ?? 'mock-trip';
            },
          );

    final tripsAsync = ref.watch(watchTripsProvider);
    if (!tripsAsync.hasError) {
      return Stack(
        children: [
          map,
          // Attribution is always ours (MapLibre's button is off-canvas
          // behind the sheet); keeps the OSM credit testable too.
          Positioned(
            right: 8,
            bottom: 8,
            child: Text(
              mapAttribution,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    backgroundColor:
                        Theme.of(context).colorScheme.surface.withAlpha(200),
                  ),
            ),
          ),
          if (_styleFailed && native)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Expanded(
                          child: Text(
                              'Failed to load map style — check connection')),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _retryStyle,
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

/// Test/fallback canvas: same destination semantics, no native view.
///
/// Used when [mapNativeProvider] is false (widget tests can't host
/// platform views). Keeps the destination-tap contract testable.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.onDestinationTap});

  final VoidCallback onDestinationTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDestinationTap,
      child: Semantics(
        label: 'Trip destination',
        button: true,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Text('Map preview', semanticsLabel: ''),
        ),
      ),
    );
  }
}
