import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/tracking/fix_throttle.dart';

/// Throttled live-GPS writer owned by [MapShell] lifecycle.
///
/// [start] is idempotent (second call returns true without re-subscribing)
/// and returns false — without throwing — when permission is unavailable
/// or the stream errors. Silent by default: only `checkPermission`, never
/// `requestPermission`, never a prompt without a user tap — the caller
/// ignores a silent `false`. Pass `interactive: true` from an explicit
/// user gesture (e.g. a location button) to allow `requestPermission`;
/// the caller then shows the `Location off` SnackBar on `false`.
/// [stop] cancels the stream; safe to call idle.
///
/// The first fix after [start] still drops `accuracy > 50m`; later fixes
/// pass through [acceptFix]. The OS-level `distanceFilter: 15` pre-filter
/// matches the 15m throttle constant. Heading follows the unchanged rule:
/// `speed > 1` else null.
class TrackingController {
  StreamSubscription<Position>? _sub;
  Position? _lastFix;
  DateTime? _lastTime;

  bool get isTracking => _sub != null;

  Future<bool> start(WidgetRef ref, {bool interactive = false}) async {
    if (_sub != null) return true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && interactive) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return false;
        }
      } else if (permission == LocationPermission.denied ||
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
    if (last == null || lastTime == null) {
      // No baseline: publish unless the fix itself is too poor.
      if (pos.accuracy > 50) return;
    } else {
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
