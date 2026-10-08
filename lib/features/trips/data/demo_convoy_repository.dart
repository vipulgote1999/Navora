import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:navora/features/navigation/drive_camera.dart';
import 'package:navora/shared/models/live_position.dart';
import 'package:navora/shared/models/member.dart';

import 'mock_trip_datasource.dart';

/// Demo convoy trip id (Abhi + Bapu + Me to Bhosari).
const demoTripId = 'demo-trip';

/// Scripted convoy for the demo ride: Abhi and Bapu glide along the
/// route polyline with human-like pace while Me navigates for real.
///
/// Extends [MockTripDataSource] (providers downcast for [membersFor]) and
/// overrides only the demo trip ([tripId]); every other trip id delegates
/// to super, so the override never leaks into non-demo trips.
/// [watchLive] yields `[]` first, then periodic fixes; the stream ends
/// when the listener cancels (no manual dispose needed).
class DemoConvoyRepository extends MockTripDataSource {
  final String demoTripId;
  final List<LatLng> routePoints;
  final Duration tick;

  static const _abhi = _Pacer(
      uid: 'abhi', startFraction: 0.35, baseSpeedMps: 14, phase: 0.0);
  static const _bapu =
      _Pacer(uid: 'bapu', startFraction: 0.15, baseSpeedMps: 9, phase: 2.1);

  DemoConvoyRepository({
    required String tripId,
    required this.routePoints,
    this.tick = const Duration(seconds: 1),
  }) : demoTripId = tripId;

  static const _demoMembers = [
    Member(
        uid: 'abhi',
        displayName: 'Abhi',
        role: MemberRole.member,
        vehicleType: 'Bike',
        vehicleLabel: ''),
    Member(
        uid: 'bapu',
        displayName: 'Bapu',
        role: MemberRole.member,
        vehicleType: 'Car',
        vehicleLabel: ''),
    Member(
        uid: 'me',
        displayName: 'Me',
        role: MemberRole.host,
        vehicleType: 'Car',
        vehicleLabel: ''),
  ];

  @override
  List<Member> membersFor(String tripId) {
    if (tripId != demoTripId) return super.membersFor(tripId);
    return _demoMembers;
  }

  /// Pacer fixes at [elapsedSec] seconds into the demo. Pure (no timers)
  /// so tests drive time directly.
  List<LivePosition> positionsAt(double elapsedSec) {
    final cum = _cumulative(routePoints);
    final total = cum.isEmpty ? 0.0 : cum.last;
    final now = DateTime.now();
    return [_abhi, _bapu].map((pacer) {
      final d = _distanceAt(pacer, total, elapsedSec).clamp(0.0, total);
      final at = _atDistance(routePoints, cum, d);
      final ahead = _atDistance(
          routePoints, cum, (d + 5).clamp(0.0, total));
      final arrived = total > 0 && d >= total;
      final speed = arrived
          ? 0.0
          : pacer.baseSpeedMps *
              (0.8 + 0.2 * math.sin(elapsedSec / 9 + pacer.phase));
      return LivePosition(
        uid: pacer.uid,
        lat: at.latitude,
        lng: at.longitude,
        heading: bearingBetween(at, ahead),
        speed: speed,
        accuracy: 8,
        status: arrived ? 'arrived' : 'riding',
        updatedAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
      );
    }).toList(growable: false);
  }

  /// Monotonic distance with slow/fast phases (never negative pace).
  static double _distanceAt(_Pacer pacer, double total, double t) {
    if (total <= 0) return 0;
    return (total * pacer.startFraction +
            pacer.baseSpeedMps *
                (0.8 * t + 1.8 * (1 - math.cos(t / 9 + pacer.phase))))
        .clamp(0.0, total);
  }

  static List<double> _cumulative(List<LatLng> points) {
    const distance = Distance();
    final cum = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cum.add(cum.last +
          distance.as(LengthUnit.Meter, points[i - 1], points[i]));
    }
    return cum;
  }

  static LatLng _atDistance(
      List<LatLng> points, List<double> cum, double d) {
    for (var i = 1; i < cum.length; i++) {
      if (d <= cum[i]) {
        final span = cum[i] - cum[i - 1];
        final t = span <= 0 ? 0.0 : (d - cum[i - 1]) / span;
        final a = points[i - 1];
        final b = points[i];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
    }
    return points.last;
  }

  @override
  Stream<List<LivePosition>> watchLive(String tripId) async* {
    if (tripId != demoTripId || routePoints.length < 2) {
      yield* super.watchLive(tripId);
      return;
    }
    yield const <LivePosition>[];
    var elapsed = 0.0;
    await for (final _ in Stream.periodic(tick)) {
      elapsed += tick.inMilliseconds / 1000.0;
      yield positionsAt(elapsed);
    }
  }
}

class _Pacer {
  final String uid;
  final double startFraction;
  final double baseSpeedMps;
  final double phase;

  const _Pacer({
    required this.uid,
    required this.startFraction,
    required this.baseSpeedMps,
    required this.phase,
  });
}
