import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/core/utils/join_code.dart';
import 'package:tripmesh/shared/models/trip.dart';

void main() {
  group('generateJoinCode', () {
    test('matches TRIP-XXXX regex', () {
      final code = generateJoinCode(Random(7));
      expect(joinCodePattern.hasMatch(code), isTrue,
          reason: 'got $code');
      expect(code, startsWith('TRIP-'));
      expect(code.length, 9);
    });

    test('single-sourced with Trip', () {
      expect(identical(Trip.joinCodePattern, joinCodePattern), isTrue);
      expect(Trip.isValidJoinCode(generateJoinCode(Random(7))), isTrue);
    });

    test('unique over 100 calls (seeded, deterministic)', () {
      final rng = Random(42);
      final codes = List.generate(100, (_) => generateJoinCode(rng));
      expect(codes.toSet().length, 100);
      for (final c in codes) {
        expect(joinCodePattern.hasMatch(c), isTrue);
      }
    });
  });
}
