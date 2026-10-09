import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/navigation/route_models.dart';

Map<String, dynamic> _osrmFixture() => {
      'code': 'Ok',
      'routes': [
        {
          'distance': 2300.0,
          'duration': 320.0,
          'geometry': {
            'coordinates': [
              [73.9412, 18.6545],
              [73.9450, 18.6580],
              [73.9512, 18.6645],
            ],
          },
          'legs': [
            {
              'steps': [
                {
                  'distance': 400.0,
                  'duration': 60.0,
                  'name': 'MG Road',
                  'maneuver': {
                    'type': 'depart',
                    'modifier': '',
                    'location': [73.9412, 18.6545],
                  },
                  'intersections': [
                    {
                      'location': [73.9412, 18.6545],
                      'bearings': [0],
                      'entry': [true],
                      'in': 0,
                      'out': 0,
                    },
                  ],
                },
                {
                  'distance': 1500.0,
                  'duration': 200.0,
                  'name': 'Nagar Road',
                  'ref': 'A2',
                  'maneuver': {
                    'type': 'turn',
                    'modifier': 'right',
                    'location': [73.9450, 18.6580],
                  },
                  'intersections': [
                    {
                      'location': [73.9450, 18.6580],
                      'bearings': [60, 240],
                      'entry': [true, true],
                      'in': 1,
                      'out': 0,
                      'lanes': [
                        {
                          'indications': ['left', 'straight'],
                          'valid': true,
                        },
                        {
                          'indications': ['right'],
                          'valid': false,
                        },
                      ],
                    },
                  ],
                },
                {
                  'distance': 0.0,
                  'duration': 0.0,
                  'name': '',
                  'maneuver': {
                    'type': 'arrive',
                    'modifier': '',
                    'location': [73.9512, 18.6645],
                  },
                },
              ],
            },
          ],
        },
      ],
    };

void main() {
  group('OSRM ref and lanes', () {
    test('parses road ref for shields', () {
      final routes = parseOsrmRoutes(_osrmFixture());
      expect(routes, hasLength(1));
      expect(routes.first.steps[1].ref, 'A2');
    });

    test('parses intersection lanes with validity', () {
      final routes = parseOsrmRoutes(_osrmFixture());
      final lanes = routes.first.steps[1].lanes;
      expect(lanes, hasLength(2));
      expect(lanes[0].indications, ['left', 'straight']);
      expect(lanes[0].valid, isTrue);
      expect(lanes[1].indications, ['right']);
      expect(lanes[1].valid, isFalse);
    });

    test('defaults to empty ref and lanes when absent', () {
      final routes = parseOsrmRoutes(_osrmFixture());
      final first = routes.first.steps[0];
      expect(first.ref, '');
      expect(first.lanes, isEmpty);
      final last = routes.first.steps[2];
      expect(last.ref, '');
      expect(last.lanes, isEmpty);
    });
  });
}
