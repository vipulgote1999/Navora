/// Car-safe navigation snapshot shared with Android Auto.
///
/// Mirrors the native contract in
/// android/app/src/main/kotlin/com/navora/navora/car/CarBridge.kt.
/// Keep the channel name, method names, keys and limits in sync.
class CarNavigationSnapshot {
  /// Must match CarBridge.METHOD_CHANNEL.
  static const channelName = 'navora/car';

  /// Must match CarBridge keys.
  static const keyDestination = 'destination';
  static const keyManeuverText = 'maneuverText';
  static const keyRoad = 'road';
  static const keyDistanceM = 'distanceM';
  static const keyDurationS = 'durationS';
  static const keyStepM = 'stepM';
  static const keyTitles = 'titles';

  /// Must match CarNavState limits.
  static const maxTrips = 6;
  static const maxTitleChars = 40;
  static const maxTextChars = 120;

  final String destination;
  final String maneuverText;
  final String road;
  final double distanceM;
  final int durationS;
  final double stepM;

  const CarNavigationSnapshot({
    required this.destination,
    this.maneuverText = '',
    this.road = '',
    required this.distanceM,
    required this.durationS,
    this.stepM = 0,
  });

  /// Car distraction + template constraints. Mirrors CarBridge validation.
  bool get isValid {
    final String dest = destination.trim();
    if (dest.isEmpty) return false;
    if (distanceM < 0 || durationS < 0 || stepM < 0) return false;
    return true;
  }

  Map<String, Object?> toMap() => {
        keyDestination: destination.trim().takeChars(maxTitleChars),
        keyManeuverText: maneuverText.trim().takeChars(maxTextChars),
        keyRoad: road.trim().takeChars(maxTitleChars),
        keyDistanceM: distanceM.clamp(0, 9999999),
        keyDurationS: durationS.clamp(0, 99999),
        keyStepM: stepM.clamp(0, 9999999),
      };

  /// Sanitizes trip titles exactly like native (trim, drop empty, dedupe, cap 6).
  static List<String> sanitizeTitles(Iterable<String?>? raw) {
    if (raw == null) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final t = (item ?? '').trim().takeChars(maxTitleChars);
      if (t.isEmpty || !seen.add(t)) continue;
      out.add(t);
      if (out.length >= maxTrips) break;
    }
    return out;
  }
}

extension StringTakeChars on String {
  String takeChars(int max) => length <= max ? this : substring(0, max);
}
