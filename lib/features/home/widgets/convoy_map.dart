import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';
import 'package:tripmesh/shared/models/live_position.dart';
import 'package:tripmesh/shared/models/trip.dart';

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

/// OSM convoy map canvas: tile layer + destination H pin + member pins.
///
/// Marker taps write [selectedTripIdProvider]. Tile errors never crash
/// ([TileLayer.errorTileCallback] is a no-op) and failed tiles render an
/// inline `Failed to load map tiles — check connection` retry widget —
/// tapping it bumps a local [ValueKey] to refetch, markers keep rendering.
/// Consumes [mapFollowModeProvider] (write path: [MapFabs]) via a
/// [MapController]: follow-me/convoy recenters on the convoy area (mock
/// positions cluster at [convoyMapCenter]; real GPS targeting lands P0-02).
class ConvoyMap extends ConsumerStatefulWidget {
  const ConvoyMap({super.key});

  @override
  ConsumerState<ConvoyMap> createState() => _ConvoyMapState();
}

class _ConvoyMapState extends ConsumerState<ConvoyMap> {
  final _mapController = MapController();

  /// Bumped on tile-error retry tap; [ValueKey] on [TileLayer] refetches.
  int _tileRetryKey = 0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _follow(FollowMode mode) {
    if (mode == FollowMode.none) return;
    // Post-frame: the controller may not be attached yet on first listen.
    // TODO(P0-02): target real GPS (me) / live bounds (convoy) once
    // watchLive yields positions; mock pins cluster at convoyMapCenter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(convoyMapCenter, defaultMapZoom);
      } catch (_) {
        // Controller not attached yet (e.g. test teardown): stay put.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FollowMode>(mapFollowModeProvider, (_, next) => _follow(next));

    final repo = ref.watch(tripRepositoryProvider);
    final selectedId = ref.watch(selectedTripIdProvider);
    // TODO(P0-02): replace MockTripDataSource downcast with a watchTrips
    // provider/stream; downcast is a P0-01 stopgap, do not expand its use.
    final trips = repo is MockTripDataSource
        ? repo.trips.values.toList()
        : const <Trip>[];
    final resolvedId = activeTripId(trips, selectedId);
    Trip? active;
    if (resolvedId != null) {
      for (final t in trips) {
        if (t.id == resolvedId) active = t;
      }
    }
    active ??= trips.isNotEmpty ? trips.last : null;
    final activeId = active?.id ?? 'mock-trip';
    final members = active != null && repo is MockTripDataSource
        ? repo.membersFor(active.id)
        : const [];

    // Live liveness: consumed where available via livePositionsProvider.
    // TODO(P0-02): Member carries no timestamp, so per-member staleness is
    // honest only when watchLive yields positions (mock yields [] — markers
    // keep the primary color, never grey). Do not grey on empty.
    final liveAsync = ref.watch(livePositionsProvider(activeId));
    final live = liveAsync.value ?? const <LivePosition>[];
    final now = DateTime.now();
    final byUid = <String, LivePosition>{for (final p in live) p.uid: p};

    void select() =>
        ref.read(selectedTripIdProvider.notifier).state = activeId;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: convoyMapCenter,
        initialZoom: defaultMapZoom,
      ),
      children: [
        TileLayer(
          key: ValueKey<int>(_tileRetryKey),
          urlTemplate: isDark ? darkTileUrl : lightTileUrl,
          userAgentPackageName: 'tripmesh',
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
                child: _MemberPin(
                  uid: members[i].uid,
                  live: byUid[members[i].uid],
                  now: now,
                  primary: colorScheme.primary,
                  onTap: select,
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
          popupInitialDisplayDuration: Duration(seconds: 5),
        ),
      ],
    );
  }
}
