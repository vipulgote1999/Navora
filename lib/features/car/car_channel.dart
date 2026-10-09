import 'package:flutter/services.dart';
import 'car_navigation_snapshot.dart';

/// Thin wrapper over MethodChannel('navora/car').
///
/// Dart remains the source of truth (route_providers / tracking_controller);
/// this only mirrors the snapshot into CarNavState for the head unit.
/// No-ops with false when the host is unavailable (iOS, desktop, tests).
class CarChannel {
  static const methodChannelName = CarNavigationSnapshot.channelName;
  static const methodUpdate = 'updateNavigation';
  static const methodClear = 'clearNavigation';
  static const methodTrips = 'updateTrips';
  static const methodGetState = 'getState';

  final MethodChannel channel;

  CarChannel({MethodChannel? channel})
      : channel = channel ?? const MethodChannel(methodChannelName);

  /// Pushes the active guidance snapshot to the car. Returns false when
  /// invalid or when no native host handles the call.
  Future<bool> updateNavigation(CarNavigationSnapshot snapshot) async {
    if (!snapshot.isValid) return false;
    try {
      final ok = await channel.invokeMethod<bool>(methodUpdate, snapshot.toMap());
      return ok ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> clearNavigation() async {
    try {
      final ok = await channel.invokeMethod<bool>(methodClear, null);
      return ok ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> updateTrips(List<String> titles) async {
    try {
      final ok = await channel.invokeMethod<bool>(
        methodTrips,
        {CarNavigationSnapshot.keyTitles: CarNavigationSnapshot.sanitizeTitles(titles)},
      );
      return ok ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
