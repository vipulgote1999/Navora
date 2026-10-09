import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/navigation/drive_camera.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';

/// Debug-only drive log. `adb logcat | grep Navora:drive`.
void _simLog(String msg) {
  if (kDebugMode) debugPrint('[Navora:drive] $msg');
}

/// On-device mock drive: synthetic GPS fixes along the loaded route.
///
/// Writes through the same providers as the real GPS stack
/// ([myPositionProvider], [myHeadingDegProvider], [mySpeedMpsProvider]),
/// so camera, banner, arrival, and reroute all behave for real — without
/// moving. For demos, desk testing, and validating arrow updates.
/// Each tick advances [speedMps]×interval along the polyline; stops at
/// the destination (arrival takes over), when navigation ends, or on
/// [stop]. Timer-driven: only one run at a time (`start` restarts).
class DriveSimulator {
  Timer? _timer;

  bool get isRunning => _timer != null;

  /// Drives [route] from its first point at [speedMps].
  void start(WidgetRef ref, TripRoute route,
      {double speedMps = 12,
      Duration tick = const Duration(milliseconds: 800)}) {
    stop();
    final points = route.points;
    if (points.length < 2) {
      _simLog('start ignored: only ${points.length} point(s)');
      return;
    }
    // Guarantee visible effect: without follow-me the camera and chevron
    // never ride the synthetic fixes (the classic "dead play button").
    ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
    final cum = _cumulative(points);
    final total = cum.last;
    _simLog('start: ${points.length} pts, ${total.toStringAsFixed(0)}m, '
        '${speedMps}m/s, follow=me');
    var traveled = 0.0;
    final stepM = speedMps * tick.inMilliseconds / 1000.0;
    var loggedTicks = 0;
    _timer = Timer.periodic(tick, (_) {
      try {
        if (!ref.read(navigatingProvider)) {
          _simLog('stop: navigation ended at ${traveled.toStringAsFixed(0)}m');
          ref.read(simulatingProvider.notifier).state = false;
          stop();
          return;
        }
        traveled += stepM;
        if (traveled >= total) {
          traveled = total;
        }
        final fix = _atDistance(points, cum, traveled);
        final ahead = _atDistance(
            points, cum, (traveled + stepM).clamp(0.0, total));
        ref.read(myPositionProvider.notifier).state = fix;
        ref.read(myHeadingDegProvider.notifier).state =
            bearingBetween(fix, ahead);
        ref.read(mySpeedMpsProvider.notifier).state = speedMps;
        ref.read(myAccuracyMProvider.notifier).state = 8;
        ref.read(simulatingProvider.notifier).state = true;
        loggedTicks++;
        // Per-tick evidence (also proves the timer is alive on device).
        if (loggedTicks <= 3 || loggedTicks % 10 == 0) {
          _simLog('tick $loggedTicks: ${traveled.toStringAsFixed(0)}/'
              '${total.toStringAsFixed(0)}m @ '
              '${fix.latitude.toStringAsFixed(5)},'
              '${fix.longitude.toStringAsFixed(5)}');
        }
        if (traveled >= total) {
          _simLog('stop: destination reached');
          stop();
        }
      } catch (e) {
        _simLog('stop: tick error $e');
        stop();
      }
    });
  }

  void stop() {
    if (_timer == null) return;
    _simLog('stop called');
    _timer?.cancel();
    _timer = null;
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
}
