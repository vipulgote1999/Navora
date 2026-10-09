import 'package:latlong2/latlong.dart';

/// One turn-by-turn instruction from OSRM (`steps=true`).
class RouteStep {
  /// Human instruction, e.g. `Turn right onto MG Road`.
  final String instruction;

  /// Raw OSRM maneuver type (`turn`, `arrive`, `roundabout`, …).
  final String maneuverType;

  /// Raw OSRM modifier (`right`, `slight left`, …) — empty when absent.
  final String modifier;
  final double distanceM;
  final double durationS;
  final LatLng location;

  /// Road reference code for shields (e.g. `A2`, `E35`) — empty when absent.
  final String ref;

  /// Turn lanes at the maneuver intersection — empty when the dataset
  /// carries no lane data (common outside well-tagged areas).
  final List<RouteLane> lanes;

  const RouteStep({
    required this.instruction,
    required this.maneuverType,
    required this.modifier,
    required this.distanceM,
    required this.durationS,
    required this.location,
    this.ref = '',
    this.lanes = const [],
  });
}

/// One turn lane at an intersection: painted indications + whether the
/// lane is valid for the current maneuver.
class RouteLane {
  final List<String> indications;
  final bool valid;

  const RouteLane({required this.indications, required this.valid});
}

/// A routed trip: full polyline + totals + per-step instructions.
class TripRoute {
  final List<LatLng> points;
  final double distanceM;
  final double durationS;
  final List<RouteStep> steps;

  const TripRoute({
    required this.points,
    required this.distanceM,
    required this.durationS,
    required this.steps,
  });
}

/// Builds a human instruction from OSRM maneuver parts.
///
/// [type] is the raw maneuver type, [modifier] the raw modifier (may be
/// empty), [name] the road name (may be empty).
String instructionFor(String type, String modifier, String name) {
  final onto = name.isEmpty ? '' : ' onto $name';
  final t = type.trim().toLowerCase();
  final m = modifier.trim().toLowerCase();
  if (t == 'arrive') return 'Arrive at destination';
  if (t == 'depart') {
    if (name.isEmpty) return m.isEmpty ? 'Head out' : 'Head $m';
    return m.isEmpty ? 'Head out onto $name' : 'Head $m onto $name';
  }
  if (t.contains('roundabout') || t.contains('rotary')) {
    return 'At the roundabout, take the exit$onto';
  }
  if (t.contains('ramp')) return 'Take the ramp$onto';
  if (t == 'merge' || t == 'fork') {
    return m.isEmpty ? 'Merge$onto' : 'Merge $m$onto';
  }
  if (t == 'end of road') {
    return m.isEmpty ? 'At the end of the road$onto' : 'At the end of the road, turn $m$onto';
  }
  if (t == 'notification' || t == 'new name' || t == 'continue') {
    return name.isEmpty ? 'Continue straight' : 'Continue onto $name';
  }
  if (t == 'turn' || t == 'turnover') {
    return m.isEmpty ? 'Turn$onto' : 'Turn $m$onto';
  }
  // Fallback: prettify `off ramp`/`on ramp`/unknown types.
  final pretty = t.isEmpty ? 'Continue' : '${t[0].toUpperCase()}${t.substring(1)}';
  if (m.isEmpty) return '$pretty$onto';
  return '$pretty $m$onto';
}

LatLng? _parseLngLat(dynamic e) {
  if (e is! List || e.length < 2) return null;
  final lng = (e[0] as num?)?.toDouble();
  final lat = (e[1] as num?)?.toDouble();
  if (lng == null || lat == null) return null;
  return LatLng(lat, lng);
}

/// Parses an OSRM `/route/v1` response into a [TripRoute].
///
/// Pure (no I/O): returns null for non-Ok codes, empty routes, or
/// malformed payloads so callers degrade to a no-route state.
/// Convenience for the single-route case; see [parseOsrmRoutes].
TripRoute? parseOsrmRoute(dynamic json) {
  final routes = parseOsrmRoutes(json, maxRoutes: 1);
  return routes.isEmpty ? null : routes.first;
}

/// Parses all routes (up to [maxRoutes]) from an OSRM response.
///
/// Pure (no I/O): OSRM returns alternates ordered best-first when the
/// request sets `alternatives=true`. Malformed entries are skipped, so an
/// empty list means no-route — never throws.
List<TripRoute> parseOsrmRoutes(dynamic json, {int maxRoutes = 3}) {
  if (json is! Map<String, dynamic>) return const [];
  if ((json['code'] as String?) != 'Ok') return const [];
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty) return const [];
  final out = <TripRoute>[];
  for (final entry in routes) {
    if (out.length >= maxRoutes) break;
    if (entry is! Map<String, dynamic>) continue;
    final parsed = _parseOneRoute(entry);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

/// Parses one OSRM route entry; null when it carries no usable
/// geometry or steps.
TripRoute? _parseOneRoute(Map<String, dynamic> first) {
  // Full geometry first (requested `geometries=geojson`); fall back to
  // concatenated step geometries when the overview is missing.
  final points = <LatLng>[];
  final geometry = first['geometry'];
  if (geometry is Map<String, dynamic>) {
    final coords = geometry['coordinates'];
    if (coords is List) {
      for (final c in coords) {
        final p = _parseLngLat(c);
        if (p != null) points.add(p);
      }
    }
  }

  final steps = <RouteStep>[];
  final legs = first['legs'];
  if (legs is List) {
    for (final leg in legs) {
      if (leg is! Map<String, dynamic>) continue;
      final legSteps = leg['steps'];
      if (legSteps is! List) continue;
      for (final s in legSteps) {
        if (s is! Map<String, dynamic>) continue;
        final maneuver = s['maneuver'];
        if (maneuver is! Map<String, dynamic>) continue;
        final type = (maneuver['type'] as String?) ?? '';
        final modifier = (maneuver['modifier'] as String?) ?? '';
        final location = _parseLngLat(maneuver['location']);
        if (type.isEmpty || location == null) continue;
        final name = (s['name'] as String?) ?? '';
        steps.add(RouteStep(
          instruction: instructionFor(type, modifier, name.trim()),
          maneuverType: type,
          modifier: modifier,
          distanceM: ((s['distance'] as num?) ?? 0).toDouble(),
          durationS: ((s['duration'] as num?) ?? 0).toDouble(),
          location: location,
          ref: (s['ref'] as String?) ?? '',
          lanes: _parseLanes(s['intersections']),
        ));
        // Fallback geometry from step LineStrings when no overview.
        if (points.isEmpty) {
          final g = s['geometry'];
          if (g is Map<String, dynamic>) {
            final coords = g['coordinates'];
            if (coords is List) {
              for (final c in coords) {
                final p = _parseLngLat(c);
                if (p != null) points.add(p);
              }
            }
          }
        }
      }
    }
  }

  if (points.length < 2 || steps.isEmpty) return null;
  return TripRoute(
    points: List.unmodifiable(points),
    distanceM: ((first['distance'] as num?) ?? 0).toDouble(),
    durationS: ((first['duration'] as num?) ?? 0).toDouble(),
    steps: List.unmodifiable(steps),
  );
}

/// Header label for a route: `2.3 km · ~5 min`.
String formatRouteLabel(TripRoute route) {
  final km = route.distanceM / 1000;
  final mins = (route.durationS / 60).round();
  return '${km.toStringAsFixed(1)} km · ~$mins min';
}

/// Short distance label for one step: `350 m` under 1 km, else `1.2 km`.
String formatStepDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Long duration label, Maps-style: `45 min`, `1 hr 18 min`.
String formatLongDuration(double seconds) {
  final totalMin = (seconds / 60).round();
  if (totalMin < 60) return '$totalMin min';
  final hours = totalMin ~/ 60;
  final mins = totalMin % 60;
  return mins == 0 ? '$hours hr' : '$hours hr $mins min';
}

/// Clock time of arrival for a route of [durationS], Maps-style (`6:42 PM`).
///
/// Pure: [now] is injectable for tests, defaults to `DateTime.now()`.
String formatArrivalTime(double durationS, {DateTime? now}) {
  final arrival = (now ?? DateTime.now()).add(
    Duration(seconds: durationS.round()),
  );
  final hour12 = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
  final minute = arrival.minute.toString().padLeft(2, '0');
  final period = arrival.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Road summary for a route option card: first named road on the route,
/// e.g. `via Nagar Road`. Empty when every step is unnamed.
String routeViaName(TripRoute route) {
  for (final step in route.steps) {
    final name = _stepRoadName(step);
    if (name.isNotEmpty) return 'via $name';
  }
  return '';
}

/// Best-effort road name behind a step instruction (`Turn right onto X`
/// → `X`; `Continue straight` → ``).
String _stepRoadName(RouteStep step) {
  const onto = ' onto ';
  final ix = step.instruction.indexOf(onto);
  if (ix >= 0) return step.instruction.substring(ix + onto.length).trim();
  return '';
}

/// Parses turn lanes from an OSRM step's `intersections` list.
///
/// Only the first intersection (the maneuver location) carries lanes for
/// the current step. Returns empty when intersections are absent or carry
/// no lane data — never throws on malformed entries.
List<RouteLane> _parseLanes(dynamic intersections) {
  if (intersections is! List || intersections.isEmpty) return const [];
  final first = intersections.first;
  if (first is! Map<String, dynamic>) return const [];
  final lanes = first['lanes'];
  if (lanes is! List) return const [];
  final out = <RouteLane>[];
  for (final lane in lanes) {
    if (lane is! Map<String, dynamic>) continue;
    final indications = lane['indications'];
    out.add(RouteLane(
      indications: indications is List
          ? [for (final i in indications) if (i is String) i]
          : const <String>[],
      valid: (lane['valid'] as bool?) ?? false,
    ));
  }
  return List.unmodifiable(out);
}

/// Index of the step whose maneuver location is closest to [pos].
///
/// Pure (no I/O): -1 when [route] has no steps. Used to highlight the
/// current instruction while navigating.
int nearestStepIndex(TripRoute route, LatLng pos) {
  if (route.steps.isEmpty) return -1;
  const distance = Distance();
  var best = 0;
  var bestM = distance.as(LengthUnit.Meter, pos, route.steps[0].location);
  for (var i = 1; i < route.steps.length; i++) {
    final m = distance.as(LengthUnit.Meter, pos, route.steps[i].location);
    if (m < bestM) {
      bestM = m;
      best = i;
    }
  }
  return best;
}

/// Shortest distance in meters from [pos] to the route polyline,
/// approximated by the nearest vertex (cheap enough per GPS fix).
///
/// Pure (no I/O): double.infinity when the route has no points.
double minDistanceToRouteM(TripRoute route, LatLng pos) {
  if (route.points.isEmpty) return double.infinity;
  const distance = Distance();
  var bestM = double.infinity;
  for (final p in route.points) {
    final m = distance.as(LengthUnit.Meter, pos, p);
    if (m < bestM) bestM = m;
  }
  return bestM;
}

/// On-map pill label for a route option: `5 min · 2.3 km via MG Road`.
///
/// Pure: same wording as the sheet option cards, shared so map pills and
/// the sheet never drift. No toll segment — OSRM exposes no toll data.
String routePillLabel(TripRoute route) {
  final mins = (route.durationS / 60).round();
  final km = (route.distanceM / 1000).toStringAsFixed(1);
  final via = routeViaName(route);
  return via.isEmpty ? '$mins min · $km km' : '$mins min · $km km $via';
}

/// Anchor for a route's on-map pill: the middle vertex.
///
/// Pure: LatLng(0, 0) when the route has no points (never in practice —
/// parsed routes require >= 2 points).
LatLng routeMidpoint(TripRoute route) {
  if (route.points.isEmpty) return const LatLng(0, 0);
  return route.points[route.points.length ~/ 2];
}

/// Whether [me] counts as arrived: within [radiusM] of the destination
/// pin OR of the route's end.
///
/// Pure: snapped routes often end well off the destination pin (building
/// centroid vs nearest road), so the route end alone must trigger
/// arrival — otherwise navigation never stops at the destination.
bool hasArrived({
  required LatLng me,
  LatLng? destination,
  LatLng? routeEnd,
  double radiusM = 25,
}) {
  const distance = Distance();
  if (destination != null &&
      distance.as(LengthUnit.Meter, me, destination) <= radiusM) {
    return true;
  }
  if (routeEnd != null &&
      distance.as(LengthUnit.Meter, me, routeEnd) <= radiusM) {
    return true;
  }
  return false;
}
