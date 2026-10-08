import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:tripmesh/features/navigation/routing_repository.dart';

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
