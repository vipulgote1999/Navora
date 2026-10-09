import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';

void main() {
  group('memberCaption', () {
    test('name plus remaining km', () {
      expect(memberCaption('Abhi', 520), 'Abhi\n0.5 km left');
    });

    test('name only without remaining', () {
      expect(memberCaption('Bapu', null), 'Bapu');
    });
  });

  group('memberColor', () {
    test('stable distinct colors per rider', () {
      expect(memberColor('abhi', stale: false), '#0F9D58');
      expect(memberColor('bapu', stale: false), '#F29900');
      expect(memberColor('abhi', stale: false),
          isNot(memberColor('bapu', stale: false)));
    });

    test('stale overrides rider color', () {
      expect(memberColor('abhi', stale: true), '#9AA0A6');
    });

    test('unknown uid falls back, never empty', () {
      final c = memberColor('stranger', stale: false);
      expect(c, isNotEmpty);
      expect(c, startsWith('#'));
    });
  });
}
