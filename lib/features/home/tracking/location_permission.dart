import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';

/// Prefs flag recording that the OS location prompt was shown once.
/// Reinstall clears app storage, so the prompt returns exactly once
/// per install. All failures degrade safe: reads fail-open (behave as
/// fresh install), writes are silent.
/// Shared once-per-install flag (migrated to Navora key so the two
/// startup paths never double-prompt).
const locationAskedKey = 'navora_location_prompted_v1';

/// Legacy TripMesh flag (pre-rename installs). Read as fallback so
/// upgraders are not re-prompted.
const legacyLocationAskedKey = 'tripmesh_location_asked';

/// Pure gate: prompt only when the OS status is a soft `denied` and we
/// have never asked before. `deniedForever` and granted states never
/// prompt (Settings/deep-link paths handle those).
bool shouldRequestPermission({
  required bool alreadyAsked,
  required LocationPermission status,
}) =>
    !alreadyAsked && status == LocationPermission.denied;

/// Reads the asked flag. False on fresh installs and on storage failure.
Future<bool> hasAskedLocationPermission() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(locationAskedKey) == true) return true;
    // Upgraders from TripMesh builds: honor legacy flag once, then migrate.
    if (prefs.getBool(legacyLocationAskedKey) == true) {
      try {
        await prefs.setBool(locationAskedKey, true);
      } catch (_) {}
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// Persists the asked flag. Silent on storage failure.
Future<void> markLocationPermissionAsked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(locationAskedKey, true);
  } catch (_) {
    // Stay functional without persistence; never throw.
  }
}

/// Single choke point for the OS prompt: at most one `requestPermission`
/// per install. The flag is written BEFORE prompting so even a kill
/// mid-prompt never re-prompts. Failures return `denied`, never throw.
Future<LocationPermission> requestPermissionOnce() async {
  late final LocationPermission status;
  try {
    status = await Geolocator.checkPermission();
  } catch (_) {
    return LocationPermission.denied;
  }
  if (!shouldRequestPermission(
    alreadyAsked: await hasAskedLocationPermission(),
    status: status,
  )) {
    return status;
  }
  await markLocationPermissionAsked();
  try {
    return await Geolocator.requestPermission();
  } catch (_) {
    return LocationPermission.denied;
  }
}

/// Pure auto-center decision: move the camera only for the FIRST fix
/// while following me. Later fixes must not fight the user's panning.
bool shouldAutoCenter({
  required FollowMode mode,
  required LatLng? prev,
  required LatLng? next,
}) =>
    mode == FollowMode.me && prev == null && next != null;
