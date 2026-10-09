import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/navigation/drive_camera.dart' as cam;

/// Scripted GPS drive for simulation tests.
///
/// Feeds synthetic fixes through the same providers the real GPS stack
/// writes ([myPositionProvider], [myHeadingDegProvider],
/// [mySpeedMpsProvider]), so overlay behavior (banner, steps, arrival,
/// speed pill) is validated exactly as production drives it. Native
/// MapLibre rendering is out of scope — the camera math it consumes is
/// unit-tested separately (see `drive_camera_test.dart`).
class DriveSim {
  /// Test shorthand for the production bearing helper.
  static double bearingBetween(LatLng a, LatLng b) => cam.bearingBetween(a, b);

  /// Drives [points] in order as GPS fixes at [speedMps].
  ///
  /// Heading per fix is the bearing to the next point (last point keeps
  /// the previous heading); speed follows the production rule
  /// (`>1 m/s` else null). Pumps after every fix so listeners run.
  static Future<void> driveAlong(
    WidgetTester t,
    ProviderContainer container,
    List<LatLng> points, {
    double speedMps = 12,
  }) async {
    var heading = container.read(myHeadingDegProvider) ?? 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i + 1 < points.length) {
        heading = bearingBetween(points[i], points[i + 1]);
      }
      container.read(myPositionProvider.notifier).state = points[i];
      container.read(myHeadingDegProvider.notifier).state =
          speedMps > 1 ? heading : null;
      container.read(mySpeedMpsProvider.notifier).state =
          speedMps > 1 ? speedMps : null;
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }
  }
}
