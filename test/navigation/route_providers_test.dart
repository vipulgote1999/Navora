import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/navigation/routing_repository.dart';

class _OkRepo extends RoutingRepository {
  @override
  Future<RouteResult?> getRoute({
    required RoutePoint from,
    required RoutePoint to,
    http.Client? client,
  }) async {
    return RouteResult(
      points: <LatLng>[LatLng(from.lat, from.lng), LatLng(to.lat, to.lng)],
      distanceM: 2300,
      durationS: 600,
      maneuvers: const <RouteManeuver>[
        RouteManeuver(instruction: 'Head out', distanceM: 350, index: 0),
      ],
      engine: 'test',
    );
  }
}

class _FailRepo extends RoutingRepository {
  @override
  Future<RouteResult?> getRoute({
    required RoutePoint from,
    required RoutePoint to,
    http.Client? client,
  }) async {
    throw Exception('boom');
  }
}

class _NullRepo extends RoutingRepository {
  @override
  Future<RouteResult?> getRoute({
    required RoutePoint from,
    required RoutePoint to,
    http.Client? client,
  }) async {
    return null;
  }
}

void main() {
  test('fetchRoute populates activeRoute on success', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late Ref tref;
    final cap = Provider((ref) {
      tref = ref;
      return 0;
    });
    container.read(cap);
    await fetchRoute(
      tref,
      const RoutePoint(18.65, 73.94),
      const RoutePoint(18.52, 73.85),
      repo: _OkRepo(),
    );
    expect(container.read(activeRouteProvider), isNotNull);
    expect(container.read(routeLoadingProvider), isFalse);
  });

  test('fetchRoute sets error text on failure, never throws', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late Ref tref;
    final cap = Provider((ref) {
      tref = ref;
      return 0;
    });
    container.read(cap);
    await fetchRoute(
      tref,
      const RoutePoint(18.65, 73.94),
      const RoutePoint(18.52, 73.85),
      repo: _FailRepo(),
    );
    expect(container.read(activeRouteProvider), isNull);
    expect(container.read(routeErrorProvider), isNotNull);
  });

  test('fetchRoute sets error text when repo returns null', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late Ref tref;
    final cap = Provider((ref) {
      tref = ref;
      return 0;
    });
    container.read(cap);
    await fetchRoute(
      tref,
      const RoutePoint(18.65, 73.94),
      const RoutePoint(18.52, 73.85),
      repo: _NullRepo(),
    );
    expect(container.read(activeRouteProvider), isNull);
    expect(container.read(routeErrorProvider), isNotNull);
    expect(container.read(routeLoadingProvider), isFalse);
  });

  test('RouteFormat.distance formats meters and kilometers', () {
    expect(RouteFormat.distance(350), '350 m');
    expect(RouteFormat.distance(349.6), '350 m');
    expect(RouteFormat.distance(2300), '2.3 km');
    expect(RouteFormat.distance(1000), '1.0 km');
  });
}
