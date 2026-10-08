import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/navigation/drive_camera.dart';

void main() {
  group('smoothHeading', () {
    test('takes the shortest arc across north', () {
      // 350 → 10 with α=0.3 advances +6° (through 0), not back through 300s.
      expect(smoothHeading(350, 10), closeTo(356, 0.001));
    });

    test('alpha 1 jumps to next, alpha 0 holds prev', () {
      expect(smoothHeading(90, 180, alpha: 1), closeTo(180, 0.001));
      expect(smoothHeading(90, 180, alpha: 0), closeTo(90, 0.001));
    });
  });

  group('zoomForSpeed', () {
    test('fast zooms out, slow zooms in, monotonic between', () {
      expect(zoomForSpeed(25), 15.0);
      expect(zoomForSpeed(0), 17.5);
      final mid = zoomForSpeed(10);
      expect(mid, greaterThan(15.0));
      expect(mid, lessThan(17.5));
      expect(zoomForSpeed(5), greaterThan(zoomForSpeed(15)));
    });
  });

  group('forwardMetersForZoom', () {
    test('zoom 16 near Pune is a few hundred metres', () {
      final m = forwardMetersForZoom(16, 18.65);
      expect(m, greaterThan(200));
      expect(m, lessThan(350));
    });
  });

  group('shouldUpdateCamera', () {
    const base = LatLng(18.6545, 73.9412);

    test('ignores 1 m drift with 1° turn', () {
      const near = LatLng(18.654509, 73.9412); // ~1 m north
      expect(
        shouldUpdateCamera(
            prev: base, next: near, prevHeading: 0, nextHeading: 1),
        isFalse,
      );
    });

    test('fires on 5 m move', () {
      const away = LatLng(18.654545, 73.9412); // ~5 m north
      expect(
        shouldUpdateCamera(
            prev: base, next: away, prevHeading: 0, nextHeading: 0),
        isTrue,
      );
    });

    test('fires on 10° turn at the same spot', () {
      expect(
        shouldUpdateCamera(
            prev: base, next: base, prevHeading: 0, nextHeading: 10),
        isTrue,
      );
    });
  });
}
