import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Google Maps directions deep link for the default trip area.
final directionsUri = Uri.parse(
  'https://www.google.com/maps/dir/?api=1&destination=$defaultMapCenterLat,$defaultMapCenterLng',
);

/// Map floating actions: my-location + directions.
///
/// Location sets [mapFollowModeProvider] to [FollowMode.me]; when permission
/// is denied (or geolocator throws, e.g. offline/test env) a SnackBar
/// `Location off — showing trip area` is shown instead. Permanently denied
/// (`deniedForever`) adds a `Settings` action opening app settings.
/// Directions opens the Google Maps link via url_launcher and never throws.
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
      ref.read(mapFollowModeProvider.notifier).state = FollowMode.me;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location off — showing trip area')),
        );
      }
    }
  }

  Future<void> _directions() async {
    try {
      await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Offline / no handler: stay on the map, never crash.
    }
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
              onPressed: _directions,
              child: const Icon(Icons.directions),
            ),
          ),
        ),
      ],
    );
  }
}
