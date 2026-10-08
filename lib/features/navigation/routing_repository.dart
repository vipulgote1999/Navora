import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'route_models.dart' as tripmodels;

class RoutePoint {
  final double lat;
  final double lng;
  const RoutePoint(this.lat, this.lng);
}

class RouteManeuver {
  final String instruction;
  final double distanceM;
  final int index;
  const RouteManeuver({
    required this.instruction,
    required this.distanceM,
    required this.index,
  });
}

class RouteResult {
  final List<LatLng> points;
  final double distanceM;
  final double durationS;
  final List<RouteManeuver> maneuvers;
  final String engine;
  const RouteResult({
    required this.points,
    required this.distanceM,
    required this.durationS,
    required this.maneuvers,
    required this.engine,
  });
}

/// Pure Google-encoded-polyline decoder.
///
/// [precision] is the decimal precision of the encoding: 6 for Valhalla
/// `shape`, 5 for OSRM `geometry` (polyline).
List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
  if (encoded.isEmpty) return <LatLng>[];
  final double factor = pow(10, precision).toDouble();
  final List<LatLng> points = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;
  while (index < encoded.length) {
    int shift = 0;
    int result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final int deltaLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lat += deltaLat;

    shift = 0;
    result = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final int deltaLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lng += deltaLng;

    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}

/// Builds a human-readable instruction from OSRM step fields.
String osrmInstruction(String type, String? modifier, String name, String? ref,
    [int? exit]) {
  // ref is accepted for API completeness; the road [name] carries the label.
  if (type == 'depart') {
    return 'Head out${name.isNotEmpty ? ' on $name' : ''}';
  }
  if (type == 'arrive') {
    return 'Arrive at destination';
  }
  if (type == 'roundabout' || type == 'rotary') {
    return 'At the roundabout, take exit ${exit ?? 1}';
  }
  final String mod =
      (modifier == null || modifier.isEmpty) ? type : modifier;
  return 'Turn $mod${name.isNotEmpty ? ' onto $name' : ''}';
}

/// Parses a Valhalla `/route` response. Returns null on missing shape.
/// Summary `length` and maneuver `length` are kilometres → converted to
/// metres; `time` is seconds. Shape uses precision 6.
RouteResult? parseValhallaRoute(Map<String, dynamic> json) {
  try {
    final Map<String, dynamic>? trip = json['trip'] as Map<String, dynamic>?;
    if (trip == null) return null;
    final List<dynamic>? legs = trip['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;
    final Map<String, dynamic> leg = legs[0] as Map<String, dynamic>;
    final String? shape = leg['shape'] as String?;
    if (shape == null || shape.isEmpty) return null;
    final List<LatLng> points = decodePolyline(shape, precision: 6);

    final Map<String, dynamic>? summary =
        trip['summary'] as Map<String, dynamic>?;
    final double lengthKm =
        ((summary?['length'] as num?)?.toDouble()) ?? 0.0;
    final double timeS = ((summary?['time'] as num?)?.toDouble()) ?? 0.0;

    final List<dynamic> rawManeuvers =
        (leg['maneuvers'] as List<dynamic>?) ?? <dynamic>[];
    final List<RouteManeuver> maneuvers = <RouteManeuver>[];
    for (int i = 0; i < rawManeuvers.length; i++) {
      final Map<String, dynamic> m =
          rawManeuvers[i] as Map<String, dynamic>;
      maneuvers.add(RouteManeuver(
        instruction: (m['instruction'] as String?) ?? '',
        distanceM: (((m['length'] as num?)?.toDouble()) ?? 0.0) * 1000.0,
        index: i,
      ));
    }

    return RouteResult(
      points: points,
      distanceM: lengthKm * 1000.0,
      durationS: timeS,
      maneuvers: maneuvers,
      engine: 'valhalla',
    );
  } catch (_) {
    return null;
  }
}

/// Parses an OSRM `/route/v1` response. Returns null when `code != 'Ok'`
/// or there are no routes. Geometry uses precision 5; distance is metres,
/// duration is seconds.
RouteResult? parseOsrmRouteResult(Map<String, dynamic> json) {
  try {
    if ((json['code'] as String?) != 'Ok') return null;
    final List<dynamic>? routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final Map<String, dynamic> route = routes[0] as Map<String, dynamic>;
    final String? geometry = route['geometry'] as String?;
    if (geometry == null || geometry.isEmpty) return null;
    final List<LatLng> points = decodePolyline(geometry, precision: 5);

    final double distanceM =
        ((route['distance'] as num?)?.toDouble()) ?? 0.0;
    final double durationS =
        ((route['duration'] as num?)?.toDouble()) ?? 0.0;

    final List<dynamic> legs =
        (route['legs'] as List<dynamic>?) ?? <dynamic>[];
    final List<RouteManeuver> maneuvers = <RouteManeuver>[];
    int index = 0;
    for (final dynamic leg in legs) {
      final List<dynamic> steps =
          ((leg as Map<String, dynamic>)['steps'] as List<dynamic>?) ??
              <dynamic>[];
      for (final dynamic step in steps) {
        final Map<String, dynamic> s = step as Map<String, dynamic>;
        final Map<String, dynamic> maneuver =
            (s['maneuver'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        maneuvers.add(RouteManeuver(
          instruction: osrmInstruction(
            (maneuver['type'] as String?) ?? '',
            maneuver['modifier'] as String?,
            (s['name'] as String?) ?? '',
            s['ref'] as String?,
          ),
          distanceM: ((s['distance'] as num?)?.toDouble()) ?? 0.0,
          index: index++,
        ));
      }
    }

    return RouteResult(
      points: points,
      distanceM: distanceM,
      durationS: durationS,
      maneuvers: maneuvers,
      engine: 'osrm',
    );
  } catch (_) {
    return null;
  }
}

/// Hybrid routing: Valhalla primary, OSRM fallback.
///
/// Intentionally a plain subclassable class with an overridable [getRoute].
class RoutingRepository {
  static const String _valhallaUrl = 'https://valhalla1.openstreetmap.de/route';
  static const String _userAgent = 'Navora/1.0 (routing)';
  static const Duration _timeout = Duration(seconds: 12);

  Future<RouteResult?> getRoute({
    required RoutePoint from,
    required RoutePoint to,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final bool shouldClose = client == null;
    try {
      final RouteResult? valhalla =
          await _fetchValhalla(from, to, httpClient);
      if (valhalla != null) return valhalla;
      return await _fetchOsrm(from, to, httpClient);
    } finally {
      if (shouldClose) httpClient.close();
    }
  }

  Future<RouteResult?> _fetchValhalla(
    RoutePoint from,
    RoutePoint to,
    http.Client httpClient,
  ) async {
    try {
      final String body = jsonEncode({
        'locations': [
          {'lat': from.lat, 'lon': from.lng},
          {'lat': to.lat, 'lon': to.lng},
        ],
        'costing': 'auto',
        'directions_type': 'instructions',
        'language': 'en-US',
      });
      final http.Response resp = await httpClient
          .post(
            Uri.parse(_valhallaUrl),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'User-Agent': _userAgent,
            },
            body: body,
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data =
          jsonDecode(resp.body) as Map<String, dynamic>;
      return parseValhallaRoute(data);
    } catch (_) {
      return null;
    }
  }

  Future<RouteResult?> _fetchOsrm(
    RoutePoint from,
    RoutePoint to,
    http.Client httpClient,
  ) async {
    try {
      final Uri uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.lng},${from.lat};${to.lng},${to.lat}'
        '?overview=full&geometries=polyline&steps=true',
      );
      final http.Response resp = await httpClient
          .get(uri, headers: <String, String>{'User-Agent': _userAgent})
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data =
          jsonDecode(resp.body) as Map<String, dynamic>;
      return parseOsrmRouteResult(data);
    } catch (_) {
      return null;
    }
  }

  /// Keyless alternates fetch over OSRM (best-first, up to 3).
  ///
  /// Preserved from Navora in-app routing: requests OSRM
  /// `alternatives=true` so the map draws gray alternates. Empty on
  /// failure; never throws. [client] injectable for tests.
  Future<tripmodels.TripRoute?> fetchRoute({
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

  Future<List<tripmodels.TripRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    http.Client? client,
  }) async {
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
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
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      return tripmodels.parseOsrmRoutes(
          jsonDecode(res.body));
    } catch (_) {
      return const [];
    } finally {
      if (owned) httpClient.close();
    }
  }
}
