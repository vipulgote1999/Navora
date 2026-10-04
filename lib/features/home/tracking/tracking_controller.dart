import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/tracking/fix_throttle.dart';

/// Throttled live-GPS writer owned by [MapShell] lifecycle.
///
/// [start] is idempotent (second call returns true without re-subscribing)
/// and returns false — without throwing — when permission is denied,
/// revoked, or the stream errors, so the caller can show the existing
/// `Location off` SnackBar. [stop] cancels the stream; safe to call idle.
///
/// The first fix after [start] is always published (no baseline to
/// throttle against); later fixes pass through [acceptFix]. The OS-level
/// `distanceFilter: 15` pre-filter matches the 15m throttle constant.
/// Heading follows the unchanged rule: `speed > 1` else null.
class TrackingController {
  StreamSubscription<Position>? _sub;
  Position? _lastFix;
  DateTime? _lastTime;

  bool get isTracking => _sub != null;

  Future<bool> start(WidgetRef ref) async {
    if (_sub != null) return true;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) => _onFix(ref, pos, DateTime.now()),
        onError: (_) => unawaited(stop()),
      );
      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  void _onFix(WidgetRef ref, Position pos, DateTime now) {
    final last = _lastFix;
    final lastTime = _lastTime;
    if (last != null && lastTime != null) {
      final distM = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
      final dtSec = now.difference(lastTime).inMilliseconds / 1000.0;
      if (!acceptFix(
        distM: distM,
        dtSec: dtSec,
        accuracyM: pos.accuracy,
        speedMps: pos.speed,
      )) {
        return;
      }
    }
    _lastFix = pos;
    _lastTime = now;
    ref.read(myPositionProvider.notifier).state =
        LatLng(pos.latitude, pos.longitude);
    ref.read(myAccuracyMProvider.notifier).state =
        pos.accuracy > 0 ? pos.accuracy : null;
    ref.read(myHeadingDegProvider.notifier).state =
        pos.speed > 1 ? pos.heading : null;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastFix = null;
    _lastTime = null;
  }
}
