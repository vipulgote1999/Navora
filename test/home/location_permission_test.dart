import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/tracking/location_permission.dart';

void main() {
  group('shouldRequestPermission', () {
    test('asks when denied and never asked before', () {
      expect(
        shouldRequestPermission(
          alreadyAsked: false,
          status: LocationPermission.denied,
        ),
        isTrue,
      );
    });

    test('never asks twice', () {
      expect(
        shouldRequestPermission(
          alreadyAsked: true,
          status: LocationPermission.denied,
        ),
        isFalse,
      );
    });

    test('never asks when permanently denied', () {
      for (final asked in [false, true]) {
        expect(
          shouldRequestPermission(
            alreadyAsked: asked,
            status: LocationPermission.deniedForever,
          ),
          isFalse,
        );
      }
    });

    test('never asks when already granted', () {
      for (final status in [
        LocationPermission.always,
        LocationPermission.whileInUse,
      ]) {
        expect(
          shouldRequestPermission(alreadyAsked: false, status: status),
          isFalse,
        );
      }
    });
  });

  group('asked-flag persistence', () {
    test('fresh install has not asked', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await hasAskedLocationPermission(), isFalse);
    });

    test('mark round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      await markLocationPermissionAsked();
      expect(await hasAskedLocationPermission(), isTrue);
    });
  });

  group('shouldAutoCenter', () {
    const fix = LatLng(18.52, 73.85);

    test('first fix while following me centers', () {
      expect(
        shouldAutoCenter(
          mode: FollowMode.me,
          prev: null,
          next: fix,
        ),
        isTrue,
      );
    });

    test('later fixes do not recenter', () {
      expect(
        shouldAutoCenter(
          mode: FollowMode.me,
          prev: const LatLng(18.51, 73.84),
          next: fix,
        ),
        isFalse,
      );
    });

    test('other modes never auto-center', () {
      for (final mode in [FollowMode.none, FollowMode.convoy]) {
        expect(
          shouldAutoCenter(mode: mode, prev: null, next: fix),
          isFalse,
        );
      }
    });

    test('null fix never centers', () {
      expect(
        shouldAutoCenter(mode: FollowMode.me, prev: null, next: null),
        isFalse,
      );
    });
  });
}
