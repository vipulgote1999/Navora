import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';

import 'route_models.dart';
import 'drive_simulator.dart';
import 'routing_repository.dart';

/// On-device mock drive (see `drive_simulator.dart`). Same instance per
/// container so UI toggles and tests share run state.
final driveSimulatorProvider = Provider<DriveSimulator>((ref) {
  return DriveSimulator();
});

/// True while the mock drive is writing synthetic fixes.
final simulatingProvider = StateProvider<bool>((ref) => false);

/// HTTP routing engine. Override in tests with a fake client-backed repo.
final routingRepositoryProvider = Provider<RoutingRepository>((ref) {
  return RoutingRepository();
});

/// Route origin (usually the last GPS fix). Null = no route requested.
final routeOriginProvider = StateProvider<LatLng?>((ref) => null);

/// Route destination (search pin or trip area). Null = no route requested.
final routeDestinationProvider = StateProvider<LatLng?>((ref) => null);

/// True while the user is in guided navigation (follow-me + reroute).
final navigatingProvider = StateProvider<bool>((ref) => false);

/// Index into [routesProvider] selected by the user (Maps gray-line pick
/// via route-option cards). Clamped by readers; reset on new endpoints.
final selectedRouteIndexProvider = StateProvider<int>((ref) => 0);

/// Last auto-reroute time. Guards the deviation listener so a drifting
/// GPS fix triggers at most one refetch per 10s, never a fetch loop.
final lastRerouteAtProvider = StateProvider<DateTime?>((ref) => null);

/// Transient banner for the route card (`Arrived at destination ✓`).
/// Set by the position listener, cleared on Start/Clear/new endpoints.
final routeNoticeProvider = StateProvider<String?>((ref) => null);

/// All routes for [routeOriginProvider] → [routeDestinationProvider],
/// best-first (OSRM `alternatives=true`).
///
/// Empty while either endpoint is unset or the fetch fails (offline,
/// rate-limited, no route) — consumers render the no-route state.
final routesProvider = FutureProvider<List<TripRoute>>((ref) async {
  final origin = ref.watch(routeOriginProvider);
  final destination = ref.watch(routeDestinationProvider);
  if (origin == null || destination == null) return const [];
  return ref.watch(routingRepositoryProvider).fetchRoutes(
        origin: origin,
        destination: destination,
      );
});

/// Currently selected route (see [selectedRouteIndexProvider]).
///
/// Null while no routes are loaded — consumers render the no-route state.
/// Kept (rather than reading [routesProvider] everywhere) so the map and
/// sheet share one selection.
final routeProvider = FutureProvider<TripRoute?>((ref) async {
  final routes = await ref.watch(routesProvider.future);
  if (routes.isEmpty) return null;
  final selected = ref.watch(selectedRouteIndexProvider);
  return routes[selected.clamp(0, routes.length - 1)];
});

/// Sets both route endpoints in one call (avoids a double-fetch flash).
/// Resets the selected alternate and any transient notice.
void setRouteEndpoints(WidgetRef ref, LatLng? origin, LatLng? destination) {
  ref.read(routeOriginProvider.notifier).state = origin;
  ref.read(routeDestinationProvider.notifier).state = destination;
  ref.read(selectedRouteIndexProvider.notifier).state = 0;
}

/// Swaps origin and destination (Maps swap control) and refetches.
void swapRouteEndpoints(WidgetRef ref) {
  final origin = ref.read(routeOriginProvider);
  final destination = ref.read(routeDestinationProvider);
  setRouteEndpoints(ref, destination, origin);
  ref.read(routeNoticeProvider.notifier).state = null;
}

/// Clears the route and exits navigation mode.
void clearRoute(WidgetRef ref) {
  ref.read(navigatingProvider.notifier).state = false;
  ref.read(routeOriginProvider.notifier).state = null;
  ref.read(routeDestinationProvider.notifier).state = null;
}

/// Full navigation exit: stops the mock drive, drops a running demo
/// convoy (override + selection), then clears the route and follow mode.
///
/// Every End/X control must route through here so no demo residue or
/// stray timers survive guidance.
void exitNavigation(WidgetRef ref) {
  ref.read(driveSimulatorProvider).stop();
  ref.read(simulatingProvider.notifier).state = false;
  ref.read(demoRepositoryProvider.notifier).state = null;
  ref.read(selectedTripIdProvider.notifier).state = null;
  clearRoute(ref);
  ref.read(mapFollowModeProvider.notifier).state = FollowMode.none;
}


/// Currently displayed route. Null when no route is active.
final activeRouteProvider = StateProvider<RouteResult?>((ref) => null);

/// True while [fetchRoute] is in flight.
final routeLoadingProvider = StateProvider<bool>((ref) => false);

/// Last route failure message. Null when no failure is pending.
final routeErrorProvider = StateProvider<String?>((ref) => null);

/// Fetches a route from [from] to [to] and publishes it to the route state.
///
/// Sets loading true / error null, calls [repo] (a [RoutingRepository] when
/// omitted), then sets [activeRouteProvider] on success or a failure message
/// on null/exception. Never throws.
Future<void> fetchRoute(
  Ref ref,
  RoutePoint from,
  RoutePoint to, {
  RoutingRepository? repo,
}) async {
  ref.read(routeLoadingProvider.notifier).state = true;
  ref.read(routeErrorProvider.notifier).state = null;
  try {
    final RoutingRepository repository = repo ?? RoutingRepository();
    final RouteResult? result =
        await repository.getRoute(from: from, to: to);
    if (result == null) {
      ref.read(routeErrorProvider.notifier).state =
          "Couldn't load route — check connection";
    } else {
      ref.read(activeRouteProvider.notifier).state = result;
    }
  } catch (_) {
    ref.read(routeErrorProvider.notifier).state =
        "Couldn't load route — check connection";
  } finally {
    ref.read(routeLoadingProvider.notifier).state = false;
  }
}

/// Human-readable route formatting helpers.
abstract class RouteFormat {
  /// Formats [meters]: below 1 km as rounded metres (`350 m`), else
  /// kilometres with one decimal (`2.3 km`).
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
