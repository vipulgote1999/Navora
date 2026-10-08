import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/map_fabs.dart';
import 'package:navora/features/home/places/geocode_repository.dart';
import 'package:navora/features/navigation/route_icons.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/trips/data/demo_bhosari_route.dart';
import 'package:navora/features/trips/data/demo_convoy_repository.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';
import 'package:navora/shared/models/live_position.dart';
import 'package:navora/shared/models/trip.dart';
import 'package:navora/shared/widgets/trip_card.dart';

/// Bottom sheet for the maps-home view: trip vibe summary + recent trips.
///
/// Sizes mirror the maps-home spec: peek 0.22, collapsed 0.12, expanded 0.75.
/// Title is `Trip vibe` until a trip is selected ([selectedTripIdProvider]),
/// then it shows the trip name. The status chip reads `Last updated Xs ago`.
/// Age is `max(live updatedAt, else trip createdAt)` — honest only once
/// watchLive yields fixes (mock yields none; see the TODO below): until
/// P0-02 wires real GPS, `createdAt` is a liveness proxy, NOT a GPS fix age.
/// The chip greys out once the data is older than 90s. The trip list is
/// filtered by [searchQueryProvider] (name/origin/destination contains).
class TripVibeSheet extends ConsumerWidget {
  final DraggableScrollableController controller;

  const TripVibeSheet({super.key, required this.controller});

  /// Starts free in-app routing to [destination] over OSRM (no keys).
  ///
  /// Origin is the last GPS fix when known, else the default trip area
  /// (with a SnackBar saying so). Enables follow-me so the camera tracks
  /// the user. All navigation stays in-app — nothing here opens an
  /// external maps app.
  void _startRoute(WidgetRef ref, LatLng destination, BuildContext context) {
    final origin = ref.read(myPositionProvider) ??
        const LatLng(defaultMapCenterLat, defaultMapCenterLng);
    setRouteEndpoints(ref, origin, destination);
    ref.read(routeNoticeProvider.notifier).state = null;
    ref.read(navigatingProvider.notifier).state = true;
    ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
    if (ref.read(myPositionProvider) == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No GPS fix — routing from trip area'),
        ),
      );
    }
  }

  /// Starts the scripted demo convoy to Bhosari (Abhi + Bapu + Me).
  ///
  /// Destination prefers the pinned search result, else the canned
  /// Bhosari coords. Origin is the last GPS fix when known, else the
  /// trip area. Fetches the live route; on failure the canned route
  /// backs the pacers so the demo never dies on stage. Me navigates
  /// through the normal guidance stack.
  Future<void> _startDemo(WidgetRef ref, BuildContext context) async {
    const fallback =
        LatLng(defaultMapCenterLat, defaultMapCenterLng);
    final focus = ref.read(searchFocusProvider);
    final dest = focus != null
        ? LatLng(focus.lat, focus.lng)
        : demoBhosariDestination;
    final origin = ref.read(myPositionProvider) ?? fallback;
    setRouteEndpoints(ref, origin, dest);
    ref.read(routeNoticeProvider.notifier).state = null;
    List<LatLng> points = demoBhosariRoute.points;
    var offline = false;
    try {
      final routes = await ref.read(routesProvider.future);
      if (routes.isNotEmpty) {
        final selected = ref.read(selectedRouteIndexProvider);
        points = routes[selected.clamp(0, routes.length - 1)].points;
      } else {
        offline = true;
      }
    } catch (_) {
      offline = true;
    }
    ref.read(demoRepositoryProvider.notifier).state =
        DemoConvoyRepository(tripId: demoTripId, routePoints: points);
    ref.read(selectedTripIdProvider.notifier).state = demoTripId;
    ref.read(navigatingProvider.notifier).state = true;
    ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(offline
            ? 'Demo convoy — Abhi & Bapu riding (offline route)'
            : 'Demo convoy — Abhi & Bapu riding'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(watchTripsProvider);
    // Loading shows the same empty text as no-trips; error shows retry.
    final allTrips = tripsAsync.value ?? const <Trip>[];
    final memberCounts = ref.watch(tripMemberCountsProvider);
    final query = ref.watch(searchQueryProvider);
    final trips = filterTripsByQuery(allTrips, query);
    final selectedId = ref.watch(selectedTripIdProvider);
    final activeId = activeTripId(allTrips, selectedId);
    final Trip? focus = (activeId == null
        ? null
        : _findTrip(allTrips, activeId));
    final Trip? resolved = focus ?? (allTrips.isEmpty ? null : allTrips.last);

    // TODO(P0-02): createdAt below is NOT a GPS fix age — it only stands in
    // because mock watchLive yields [] and Member carries no timestamp.
    // Real liveness = max live updatedAt per member; do not present the
    // createdAt fallback as GPS age once live fixes exist.
    final live = resolved == null
        ? const <LivePosition>[]
        : (ref.watch(livePositionsProvider(resolved.id)).value ??
              const <LivePosition>[]);
    var anchor = resolved?.createdAt;
    for (final p in live) {
      if (anchor == null || p.updatedAt.isAfter(anchor)) {
        anchor = p.updatedAt;
      }
    }
    final ageSec = anchor == null
        ? 0
        : DateTime.now().difference(anchor).inSeconds.clamp(0, 1 << 31);
    final stale = ageSec > 90;
    final savedIds = ref.watch(savedTripIdsProvider);
    final isSaved = resolved != null && savedIds.contains(resolved.id);
    final searchPlace = ref.watch(searchFocusProvider);
    final routeRequested = ref.watch(routeOriginProvider) != null &&
        ref.watch(routeDestinationProvider) != null;
    // Google Maps: once guiding, the Navigate entries disappear — the
    // sheet becomes route-only (ETA + End + steps in _RouteSection).
    final navigating = ref.watch(navigatingProvider);

    return DraggableScrollableSheet(
      controller: controller,
      // Google Maps: nav peek is taller so the ETA (time + distance •
      // arrival + End) is fully visible without a drag — explore peek
      // stays compact.
      initialChildSize: navigating ? 0.32 : 0.22,
      minChildSize: navigating ? 0.22 : 0.12,
      maxChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          elevation: 4,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Trip details',
                  container: true,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (searchPlace != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.place, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              searchPlace.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              searchPlace.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // Google Maps: destination is locked while guiding —
                      // dismiss returns with End/Clear, not mid-navigation.
                      if (!navigating)
                        Semantics(
                          label: 'Dismiss search result',
                          button: true,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () => ref
                                .read(searchFocusProvider.notifier)
                                .state = null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Google Maps: while guiding the Navigate/Share entry is
                  // gone — _RouteSection below owns ETA + End + steps.
                  if (!navigating)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _startRoute(
                              ref,
                              LatLng(searchPlace.lat, searchPlace.lng),
                              context,
                            ),
                            icon: const Icon(Icons.navigation),
                            label: const Text('Navigate'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () async {
                              try {
                                await Share.share(
                                  '${searchPlace.title}\n'
                                  'https://www.openstreetmap.org/'
                                  '?mlat=${searchPlace.lat}'
                                  '&mlon=${searchPlace.lng}'
                                  '#map=15/${searchPlace.lat}/${searchPlace.lng}',
                                );
                              } catch (_) {
                                // No share target: stay on the map.
                              }
                            },
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 24),
                ],
                if (routeRequested) ...[
                  const _RouteSection(),
                  const Divider(height: 24),
                ],
                // Google Maps: guiding hides vibe summary + trip list — the
                // sheet is route-only until End/Clear restores explore UI.
                if (!navigating) ...[
                  Text(
                    focus?.name ?? 'Trip vibe',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  if (resolved != null)
                    Chip(
                      label: Text('Last updated ${ageSec}s ago'),
                      labelStyle: TextStyle(
                        color: stale
                            ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => _startRoute(
                          ref,
                          const LatLng(
                            defaultMapCenterLat,
                            defaultMapCenterLng,
                          ),
                          context,
                        ),
                        child: const Text('Navigate'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: resolved == null
                            ? null
                            : () async {
                                try {
                                  await Share.share(shareTextFor(resolved));
                                } catch (_) {
                                  // No share target: stay on the map, never crash.
                                }
                              },
                        child: const Text('Share'),
                      ),
                      Semantics(
                        button: true,
                        label: isSaved ? 'Unsave trip' : 'Save trip',
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: resolved == null
                              ? null
                              : () async {
                                  await toggleSavedTrip(ref, resolved.id);
                                },
                          child: Text(isSaved ? 'Saved ✓' : 'Save'),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Start demo convoy',
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _startDemo(ref, context),
                          icon: const Icon(Icons.groups_outlined),
                          label: const Text('Demo convoy'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (tripsAsync.hasError)
                    Row(
                      children: [
                        const Expanded(
                          child: Text("Couldn't load trips"),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () =>
                              ref.invalidate(watchTripsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (trips.isEmpty)
                    const Text('No trips yet — create one to get started.')
                  else
                    for (final trip in trips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TripCard(
                          trip: trip,
                          memberCount: memberCounts[trip.id] ?? 0,
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

Trip? _findTrip(List<Trip> trips, String id) {
  for (final trip in trips) {
    if (trip.id == id) return trip;
  }
  return null;
}

/// Origin label for the directions entry row: the GPS fix reads as
/// `Your location` (Maps wording), anything else as `Chosen start`.
String _originLabel(LatLng? origin, LatLng? me) {
  if (origin == null) return 'Choose start';
  if (me != null && origin == me) return 'Your location';
  return 'Chosen start';
}

/// Destination label: the pinned search result title when it matches,
/// else a plain `Destination`.
String _destinationLabel(LatLng? destination, PlaceSearchResult? focus) {
  if (destination == null) return 'Choose destination';
  if (focus != null &&
      focus.lat == destination.latitude &&
      focus.lng == destination.longitude) {
    return focus.title;
  }
  return 'Destination';
}

/// Route option card label: `19 min · 19.1 km via Nagar Road`.
String _optionLabel(TripRoute route) {
  final mins = (route.durationS / 60).round();
  final km = (route.distanceM / 1000).toStringAsFixed(1);
  final via = routeViaName(route);
  return via.isEmpty ? '$mins min · $km km' : '$mins min · $km km $via';
}

/// In-app route card: free OSRM route header + turn-by-turn steps.
///
/// Shown only while route endpoints are set ([routeOriginProvider] +
/// [routeDestinationProvider]). Loading shows a spinner, failures show a
/// no-route card with retry; the external-maps fallback lives on the
/// search card and [MapFabs]. While [navigatingProvider] is true, GPS
/// fixes drive follow-me (via [mapFollowModeProvider]), auto-reroute on
/// >50m deviation (max once per 10s), and arrival stop within 25m.
class _RouteSection extends ConsumerWidget {
  const _RouteSection();

  static const _rerouteThrottle = Duration(seconds: 10);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(routeProvider);
    final navigating = ref.watch(navigatingProvider);
    final me = ref.watch(myPositionProvider);
    final notice = ref.watch(routeNoticeProvider);
    final routes = ref.watch(routesProvider).value ?? const <TripRoute>[];
    final selected = ref.watch(selectedRouteIndexProvider);
    // Clamped: a reroute can return fewer alternates than the old index.
    final selectedIndex =
        routes.isEmpty ? 0 : selected.clamp(0, routes.length - 1);
    final origin = ref.watch(routeOriginProvider);
    final destination = ref.watch(routeDestinationProvider);
    final searchPlace = ref.watch(searchFocusProvider);

    // Deviation → reroute; arrival → stop. Provider writes only.
    ref.listen<LatLng?>(myPositionProvider, (prev, next) {
      if (next == null || !ref.read(navigatingProvider)) return;
      final route = ref.read(routeProvider).value;
      final dest = ref.read(routeDestinationProvider);
      if (route == null || dest == null) return;
      // Arrival always wins.
      if (const Distance().as(LengthUnit.Meter, next, dest) <= 25) {
        ref.read(navigatingProvider.notifier).state = false;
        ref.read(routeNoticeProvider.notifier).state =
            'Arrived at destination ✓';
        return;
      }
      // First real fix after a fallback start: the origin froze as the
      // trip area because no fix existed yet. Re-anchor to the fix when
      // it is near the route (a far fix is the reroute case below).
      // Returns early: deviation is re-evaluated against the refetched
      // route.
      const fallback =
          LatLng(defaultMapCenterLat, defaultMapCenterLng);
      final origin = ref.read(routeOriginProvider);
      if (origin != null &&
          origin == fallback &&
          const Distance().as(LengthUnit.Meter, origin, next) > 25 &&
          minDistanceToRouteM(route, next) <= 50) {
        ref.read(routeOriginProvider.notifier).state = next;
        return;
      }
      if (minDistanceToRouteM(route, next) > 50) {
        final last = ref.read(lastRerouteAtProvider);
        final now = DateTime.now();
        if (last != null && now.difference(last) < _rerouteThrottle) return;
        ref.read(lastRerouteAtProvider.notifier).state = now;
        ref.read(routeNoticeProvider.notifier).state = null;
        ref.read(routeOriginProvider.notifier).state = next;
        ref.invalidate(routeProvider);
      }
    });

    final route = routeAsync.value;
    final currentStep =
        (me != null && route != null) ? nearestStepIndex(route, me) : -1;

    return Semantics(
      label: 'Route details',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Directions entry row: origin → destination + swap (Maps mode).
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _originLabel(origin, me),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Container(
                        width: 2,
                        height: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _destinationLabel(destination, searchPlace),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Swap origin and destination',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.swap_vert),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => swapRouteEndpoints(ref),
                ),
              ),
              Semantics(
                label: 'Clear route',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () {
                    // Full exit (also drops a demo/sim) so the camera
                    // stops tracking and explore UI returns.
                    ref.read(routeNoticeProvider.notifier).state = null;
                    exitNavigation(ref);
                  },
                ),
              ),
            ],
          ),
          // Gray alternate routes as option cards (Maps route options).
          if (routes.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < routes.length; i++)
                  ChoiceChip(
                    label: Text(_optionLabel(routes[i])),
                    selected: i == selectedIndex,
                    onSelected: (_) => ref
                        .read(selectedRouteIndexProvider.notifier)
                        .state = i,
                  ),
              ],
            ),
          ],
          // Google Maps ETA footer: white card, 28px green time +
          // 16px grey distance • ETA. Reference: Nav SDK
          // CustomNavigationFooterExample (radius 12, padding 20/8).
          if (navigating && route != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatLongDuration(route.durationS),
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(route.distanceM / 1000).toStringAsFixed(1)} km · ${formatArrivalTime(route.durationS)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => exitNavigation(ref),
                    child: const Text('End'),
                  ),
                  Builder(
                    builder: (context) {
                      final simulating = ref.watch(simulatingProvider);
                      return Semantics(
                        label: simulating
                            ? 'Stop simulation'
                            : 'Simulate drive',
                        button: true,
                        child: IconButton(
                          icon: Icon(simulating
                              ? Icons.stop
                              : Icons.play_arrow),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: simulating
                              ? 'Stop mock drive'
                              : 'Simulate drive along route',
                          onPressed: () {
                            final sim =
                                ref.read(driveSimulatorProvider);
                            if (simulating) {
                              sim.stop();
                              ref
                                  .read(simulatingProvider.notifier)
                                  .state = false;
                            } else {
                              sim.start(ref, route);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else if (route != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 52),
                ),
                onPressed: () {
                  ref.read(routeNoticeProvider.notifier).state = null;
                  ref.read(navigatingProvider.notifier).state = true;
                  ref.read(mapFollowModeProvider.notifier).state =
                      FollowMode.me;
                },
                child: const Text('Start'),
              ),
            ),
          ],
          if (notice != null) ...[
            const SizedBox(height: 4),
            Text(
              notice,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (routeAsync.isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Finding free route…')),
              ],
            )
          else if (route == null)
            Row(
              children: [
                const Expanded(
                  child: Text('No route found — check connection'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  // Invalidate the list provider (cascades to the
                  // selected-route provider): invalidating only
                  // routeProvider re-reads the cached [] without a
                  // network fetch, so Retry would silently do nothing.
                  onPressed: () => ref.invalidate(routesProvider),
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            for (var i = 0; i < route.steps.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: navigating && i == currentStep
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(maneuverIcon(
                    route.steps[i].maneuverType,
                    route.steps[i].modifier,
                  )),
                  title: Text(route.steps[i].instruction),
                  subtitle: Text(
                    formatStepDistance(route.steps[i].distanceM),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
