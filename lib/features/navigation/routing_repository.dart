import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'route_models.dart';

/// Keyless route fetch over the public OSRM demo server.
///
/// Every failure — timeout, non-200, rate-limit, `code != Ok`, offline —
/// surfaces as null (single) or `[]` (alternates) so the map degrades to a
/// no-route state instead of erroring. `http.Client` is injectable.
class RoutingRepository {
  static const osrmHost = 'router.project-osrm.org';
  static const fetchTimeout = Duration(seconds: 10);

  /// Fetches a driving route from [origin] to [destination].
  ///
  /// Coordinates are encoded lng,lat per the OSRM API. Returns null when
  /// no route is available; never throws past this boundary.
  /// Convenience for the single-route case; see [fetchRoutes].
  Future<TripRoute?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    http.Client? client,
  }) async {
    final routes = await fetchRoutes(
      origin: origin,
      destination: destination,
      profile: profile,
      client: client,
    );
    return routes.isEmpty ? null : routes.first;
  }

  /// Fetches up to 3 routes (best-first) from [origin] to [destination].
  ///
  /// Requests OSRM `alternatives=true` so the map can draw gray alternates
  /// Maps-style. Empty when no route is available; never throws past this
  /// boundary. [client] is injectable for tests.
  Future<List<TripRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    http.Client? client,
  }) async {
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.https(
        osrmHost,
        '/route/v1/$profile/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}',
        const {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
          'alternatives': 'true',
        },
      );
      final res = await httpClient
          .get(uri, headers: const {'User-Agent': 'Navora/1.0 (routing)'})
          .timeout(fetchTimeout);
      if (res.statusCode != 200) return const [];
      return parseOsrmRoutes(jsonDecode(res.body));
    } catch (_) {
      return const [];
    } finally {
      if (owned) httpClient.close();
    }
  }
}
