import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/navigation/route_providers.dart';

/// Map floating actions: my-location + directions.
///
/// Location sets [mapFollowModeProvider] to [FollowMode.me]; when permission
/// is denied (or geolocator throws, e.g. offline/test env) a SnackBar
/// `Location off — showing trip area` is shown instead. Permanently denied
/// (`deniedForever`) adds a `Settings` action opening app settings.
/// Directions starts free in-app routing — nothing here ever opens an
/// external maps app.
class MapFabs extends ConsumerWidget {
  const MapFabs({super.key});

  /// Bounded by [locationTimeout]: a hung location stack (or test env with
  /// no geolocator plugin) falls through to the denied SnackBar, never a
  /// dead button or a crash.
  static const locationTimeout = Duration(seconds: 3);

  Future<LocationPermission> _permission() async {
    try {
      var permission = await Geolocator.checkPermission().timeout(
        locationTimeout,
        onTimeout: () => LocationPermission.denied,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          locationTimeout,
          onTimeout: () => LocationPermission.denied,
        );
      }
      return permission;
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<void> _locate(BuildContext context, WidgetRef ref) async {
    try {
      final permission = await _permission();
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location off — showing trip area'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  Geolocator.openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location off — showing trip area'),
            ),
          );
        }
        return;
      }
      // Permission granted: read the real GPS fix (bounded — a hung stack
      // falls through to the SnackBar, never a dead button or stale map).
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(
          locationTimeout,
          onTimeout: () => throw TimeoutException('location fix timed out'),
        );
        ref.read(myPositionProvider.notifier).state =
            LatLng(pos.latitude, pos.longitude);
        ref.read(myAccuracyMProvider.notifier).state =
            pos.accuracy > 0 ? pos.accuracy : null;
        // Heading is meaningful only while moving — stationary fixes report
        // stale/zero bearings, so the wedge hides (Google Maps behaviour).
        ref.read(myHeadingDegProvider.notifier).state =
            pos.speed > 1 ? pos.heading : null;
        ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location off — showing trip area'),
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location off — showing trip area')),
        );
      }
    }
  }

  /// Starts free in-app routing (OSRM, no keys, never leaves the app).
  ///
  /// Destination prefers the pinned search result, else the default trip
  /// area; origin is the last GPS fix when known, else the trip area.
  /// Enables follow-me; never throws.
  void _directions(WidgetRef ref) {
    const fallback =
        LatLng(defaultMapCenterLat, defaultMapCenterLng);
    final focus = ref.read(searchFocusProvider);
    setRouteEndpoints(
      ref,
      ref.read(myPositionProvider) ?? fallback,
      focus != null ? LatLng(focus.lat, focus.lng) : fallback,
    );
    ref.read(routeNoticeProvider.notifier).state = null;
    ref.read(navigatingProvider.notifier).state = true;
    ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget hitBox(Widget child) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(child: child),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hitBox(
          Semantics(
            label: 'My location',
            button: true,
            child: FloatingActionButton.small(
              onPressed: () => _locate(context, ref),
              child: const Icon(Icons.my_location),
            ),
          ),
        ),
        const SizedBox(height: 12),
        hitBox(
          Semantics(
            label: 'Get directions',
            button: true,
            child: FloatingActionButton(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onPressed: () => _directions(ref),
              child: const Icon(Icons.directions),
            ),
          ),
        ),
      ],
    );
  }
}
