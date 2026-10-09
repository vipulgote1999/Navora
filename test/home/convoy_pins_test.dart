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

  group('my-location dot vs nav arrow', () {
    test('dot and halo show only when not guiding', () {
      expect(showMyLocationDot(navigating: false), isTrue);
      expect(showMyLocationDot(navigating: true), isFalse);
    });

    test('arrow is bigger while guiding', () {
      expect(
        navArrowSize(navigating: true),
        greaterThan(navArrowSize(navigating: false)),
      );
    });

    test('navArrowPng renders a valid PNG', () async {
      final bytes = await navArrowPng();
      expect(bytes.lengthInBytes, greaterThan(100));
      // PNG magic.
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
  group('route pill tap actions', () {
    test('route kind with valid index selects it', () {
      expect(
        routePillTapIndex({'kind': 'route', 'index': '1'}, 3),
        1,
      );
    });

    test('non-route, bad index, or out of range yields -1', () {
      expect(routePillTapIndex({'kind': 'trip'}, 3), -1);
      expect(routePillTapIndex({'kind': 'route', 'index': 'x'}, 3), -1);
      expect(routePillTapIndex({'kind': 'route', 'index': '5'}, 3), -1);
      expect(routePillTapIndex({'kind': 'route'}, 3), -1);
      expect(routePillTapIndex({'kind': 'route', 'index': '0'}, 0), -1);
    });
  });
}
