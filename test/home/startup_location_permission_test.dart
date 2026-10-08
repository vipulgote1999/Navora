import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navora/features/home/tracking/startup_location_permission.dart';

void main() {
  test('startup prompt shows once per installation, then stays silent',
      () async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    Future<LocationPermission> check() async => LocationPermission.denied;
    Future<LocationPermission> request() async {
      requests++;
      return LocationPermission.whileInUse;
    }

    // First launch: prompts.
    expect(
      await ensureStartupLocationPermission(check: check, request: request),
      isTrue,
    );
    expect(requests, 1);

    // Second launch: flag persisted, no prompt, checker not even hit.
    var checks = 0;
    Future<LocationPermission> countingCheck() async {
      checks++;
      return LocationPermission.denied;
    }
    expect(
      await ensureStartupLocationPermission(
        check: countingCheck,
        request: request,
      ),
      isFalse,
    );
    expect(requests, 1);
    expect(checks, 0);
  });

  test('never re-prompts deniedForever / already-granted states', () async {
    for (final state in [
      LocationPermission.deniedForever,
      LocationPermission.whileInUse,
      LocationPermission.always,
      LocationPermission.unableToDetermine,
    ]) {
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      Future<LocationPermission> check() async => state;
      Future<LocationPermission> request() async {
        requests++;
        return state;
      }
      expect(
        await ensureStartupLocationPermission(check: check, request: request),
        isTrue,
      );
      expect(requests, 0, reason: 'state $state must not request');
    }
  });
}
