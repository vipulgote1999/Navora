import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/core/utils/join_code.dart';

void main() {
  group('generateJoinCode', () {
    test('matches TRIP-XXXX regex', () {
      final code = generateJoinCode();
      expect(joinCodePattern.hasMatch(code), isTrue,
          reason: 'got $code');
      expect(code, startsWith('TRIP-'));
      expect(code.length, 9);
    });

    test('unique over 100 calls', () {
      final codes = List.generate(100, (_) => generateJoinCode());
      expect(codes.toSet().length, 100);
      for (final c in codes) {
        expect(joinCodePattern.hasMatch(c), isTrue);
      }
    });
  });
}
