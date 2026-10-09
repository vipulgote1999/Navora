import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure drive-camera math for MapLibre guidance mode.
///
/// No MapLibre import: [ConvoyMap] calls these per GPS fix and translates
/// the results into `CameraUpdate`s. Fully unit-testable.

/// Shortest-arc heading interpolation: `prev + α * wrappedDelta`.
///
/// Wrap-around (e.g. 350° → 10°) advances through north instead of
/// swinging back through the 300s.
double smoothHeading(double prevDeg, double nextDeg, {double alpha = 0.3}) {
  final delta = ((nextDeg - prevDeg + 540) % 360) - 180;
  return (prevDeg + alpha * delta + 360) % 360;
}

/// Zoom-by-speed curve: fast driving sees more road ahead.
///
/// `≤3 m/s → 17.5`, `≥22 m/s → 15.0`, linear between, clamped.
double zoomForSpeed(double speedMps) {
  if (speedMps <= 3) return 17.5;
  if (speedMps >= 22) return 15.0;
  return 17.5 - (speedMps - 3) * (2.5 / 19);
}

/// Forward distance in metres for the lower-third ahead-point.
///
/// `fraction` of the viewport height at [zoom]/[latitude], assuming
/// [viewportHeightPx] tall map (default 800).
double forwardMetersForZoom(
  double zoom,
  double latitude, {
  double viewportHeightPx = 800,
  double fraction = 0.15,
}) {
  const earthCircumferenceM = 40075016.0;
  final latRad = latitude * math.pi / 180;
  return fraction *
      earthCircumferenceM *
      math.cos(latRad) /
      math.pow(2, zoom) *
      (viewportHeightPx / 256);
}

/// Point [forwardMeters] ahead of [fix] along [headingDeg].
LatLng aheadPoint(LatLng fix, double headingDeg, double forwardMeters) {
  return const Distance().offset(fix, forwardMeters, headingDeg);
}

/// Update throttle: animate only on real motion.
///
/// Fires when the fix moved more than 2 m or the heading turned more than
/// 3° — per-fix GPS jitter below that must not jank the camera.
bool shouldUpdateCamera({
  required LatLng prev,
  required LatLng next,
  required double prevHeading,
  required double nextHeading,
}) {
  const distance = Distance();
  if (distance.as(LengthUnit.Meter, prev, next) > 2) return true;
  final turn = ((nextHeading - prevHeading + 540) % 360) - 180;
  return turn.abs() > 3;
}

/// Course-made-good bearing from [last] to [next], or null.
///
/// Null without a baseline or below [minDistM] (GPS jitter guard).
/// Used when the device reports no heading (slow/stationary fixes) but
/// displacement shows real motion.
double? courseMadeGood(LatLng? last, LatLng next, {double minDistM = 10}) {
  if (last == null) return null;
  if (const Distance().as(LengthUnit.Meter, last, next) < minDistM) {
    return null;
  }
  return bearingBetween(last, next);
}

/// Initial bearing in degrees from [a] to [b] (0 = north).
double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Meters of [points] remaining from the vertex nearest [pos].
///
/// Powers per-member remaining chips. Zero for degenerate routes;
/// nearest-vertex approximation (cheap enough per tick).
double remainingRouteM(List<LatLng> points, LatLng pos) {
  if (points.length < 2) return 0;
  const distance = Distance();
  var best = 0;
  var bestM = distance.as(LengthUnit.Meter, pos, points[0]);
  for (var i = 1; i < points.length; i++) {
    final m = distance.as(LengthUnit.Meter, pos, points[i]);
    if (m < bestM) {
      bestM = m;
      best = i;
    }
  }
  var done = 0.0;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    final seg = distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    total += seg;
    if (i <= best) done += seg;
  }
  return (total - done).clamp(0.0, total);
}
