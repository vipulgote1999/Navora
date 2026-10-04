import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/features/home/tracking/fix_throttle.dart';

/// Boundary table from the P1 spec (Global Constraints):
/// accept iff (dist > 15m AND dt > 5s) OR dt > 60s;
/// drop accuracy > 50m; ignore <10m jumps when speed < 2m/s.
/// Vetoes (accuracy, jitter) win over the 60s heartbeat.
void main() {
  group('acceptFix boundaries', () {
    test('normal accept: dist > 15 AND dt > 5', () {
      expect(
        acceptFix(distM: 16, dtSec: 6, accuracyM: 10, speedMps: 3),
        isTrue,
      );
    });

    test('edge dist == 15 rejected (strict >)', () {
      expect(
        acceptFix(distM: 15, dtSec: 6, accuracyM: 10, speedMps: 3),
        isFalse,
      );
    });

    test('edge dt == 5 rejected (strict >)', () {
      expect(
        acceptFix(distM: 16, dtSec: 5, accuracyM: 10, speedMps: 3),
        isFalse,
      );
    });

    test('far but too soon rejected', () {
      expect(
        acceptFix(distM: 100, dtSec: 4, accuracyM: 10, speedMps: 10),
        isFalse,
      );
    });

    test('old but stationary rejected', () {
      expect(
        acceptFix(distM: 14, dtSec: 6, accuracyM: 10, speedMps: 3),
        isFalse,
      );
    });

    test('60s heartbeat forces accept despite short distance', () {
      expect(
        acceptFix(distM: 2, dtSec: 61, accuracyM: 10, speedMps: 5),
        isTrue,
      );
    });

    test('edge dt == 60 is not a heartbeat', () {
      expect(
        acceptFix(distM: 2, dtSec: 60, accuracyM: 10, speedMps: 5),
        isFalse,
      );
    });

    test('accuracy == 50 boundary accepted', () {
      expect(
        acceptFix(distM: 16, dtSec: 6, accuracyM: 50, speedMps: 3),
        isTrue,
      );
    });

    test('accuracy > 50 dropped even when far/fast', () {
      expect(
        acceptFix(distM: 100, dtSec: 10, accuracyM: 50.1, speedMps: 10),
        isFalse,
      );
    });

    test('accuracy veto beats heartbeat', () {
      expect(
        acceptFix(distM: 2, dtSec: 61, accuracyM: 80, speedMps: 5),
        isFalse,
      );
    });

    test('jitter: <10m jump at walking speed ignored', () {
      expect(
        acceptFix(distM: 9.9, dtSec: 10, accuracyM: 10, speedMps: 1.9),
        isFalse,
      );
    });

    test('jitter veto beats heartbeat when stationary', () {
      expect(
        acceptFix(distM: 5, dtSec: 61, accuracyM: 10, speedMps: 0.5),
        isFalse,
      );
    });

    test('dist == 10 boundary is not jitter', () {
      expect(
        acceptFix(distM: 10, dtSec: 61, accuracyM: 10, speedMps: 0.5),
        isTrue,
      );
    });

    test('speed == 2 boundary is not jitter', () {
      expect(
        acceptFix(distM: 9.9, dtSec: 61, accuracyM: 10, speedMps: 2),
        isTrue,
      );
    });

    test('fast small jump still throttled by distance rule', () {
      expect(
        acceptFix(distM: 9.9, dtSec: 10, accuracyM: 10, speedMps: 8),
        isFalse,
      );
    });
  });
}
