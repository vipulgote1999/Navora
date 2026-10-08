import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefs flag marking that the startup location prompt has been shown.
///
/// Persisted in [SharedPreferences], so it survives restarts but is cleared
/// on uninstall / clear-data — i.e. exactly "once per installation".
const startupLocationPromptKey = 'navora_location_prompted_v1';

/// Injectable permission hooks (default to [Geolocator]) so the
/// once-per-install gating is unit-testable without native channels.
typedef PermissionChecker = Future<LocationPermission> Function();
typedef PermissionRequester = Future<LocationPermission> Function();

/// Asks for location permission once per installation.
///
/// - Returns `true` when this call showed (or attempted) the system prompt
///   for the first time; `false` when it was already asked before (no prompt).
/// - The flag is written **before** prompting so a kill during the dialog
///   still counts as "asked" — the OS keeps its own grant state anyway.
/// - Only calls [request] when [check] reports `denied`. `deniedForever`,
///   `granted`, `limited`, etc. never re-prompt from here.
/// - Never throws: test envs (no geolocator plugin), missing prefs, or a
///   hung stack all resolve to `false` with no prompt on next launch only
///   if the flag write itself failed.
///
/// Call this once on app start (post-frame), then start tracking — the
/// silent `checkPermission`-only auto-start will pick up a grant.
Future<bool> ensureStartupLocationPermission({
  PermissionChecker? check,
  PermissionRequester? request,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(startupLocationPromptKey) == true) {
      return false; // Already asked on a previous launch: stay silent.
    }
    // Mark asked first so this path runs exactly once per installation.
    await prefs.setBool(startupLocationPromptKey, true);

    final checker = check ?? Geolocator.checkPermission;
    final requester = request ?? Geolocator.requestPermission;

    LocationPermission current;
    try {
      current = await checker();
    } catch (_) {
      return true; // Flag is set; treat as prompted, tracking stays off.
    }
    if (current == LocationPermission.denied) {
      try {
        await requester();
      } catch (_) {
        // System prompt unavailable (test env / offline): flag already set.
      }
    }
    return true;
  } catch (_) {
    return false;
  }
}
