import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_icons.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/navigation/routing_repository.dart';

Map<String, dynamic> sampleOsrm() => {
      'code': 'Ok',
      'routes': [
        {
          'distance': 2300.5,
          'duration': 320.0,
          'geometry': {
            'type': 'LineString',
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
                  'name': '',
                  'maneuver': {
                    'type': 'depart',
                    'modifier': 'north',
                    'location': [73.9412, 18.6545],
                  },
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [73.9412, 18.6545],
                      [73.9450, 18.6580],
                    ],
                  },
                },
                {
                  'distance': 1500.0,
                  'duration': 200.0,
                  'name': 'MG Road',
                  'maneuver': {
                    'type': 'turn',
                    'modifier': 'right',
                    'location': [73.9450, 18.6580],
                  },
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [73.9450, 18.6580],
                      [73.9512, 18.6645],
                    ],
                  },
                },
                {
                  'distance': 0.0,
                  'duration': 0.0,
                  'name': '',
                  'maneuver': {
                    'type': 'arrive',
                    'location': [73.9512, 18.6645],
                  },
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [73.9512, 18.6645],
                      [73.9512, 18.6645],
                    ],
                  },
                },
              ],
            },
          ],
        },
      ],
    };

void main() {
  group('instructionFor', () {
    test('turn/arrive/depart phrasing', () {
      expect(instructionFor('turn', 'right', 'MG Road'), 'Turn right onto MG Road');
      expect(instructionFor('arrive', '', ''), 'Arrive at destination');
      expect(instructionFor('depart', 'north', ''), 'Head north');
      expect(instructionFor('depart', '', 'FC Road'), 'Head out onto FC Road');
    });

    test('roundabout/ramp/continue fallbacks', () {
      expect(
        instructionFor('roundabout', 'straight', 'Ring Road'),
        'At the roundabout, take the exit onto Ring Road',
      );
      expect(instructionFor('off ramp', '', 'Highway'), 'Take the ramp onto Highway');
      expect(instructionFor('new name', '', 'Link Road'), 'Continue onto Link Road');
      expect(instructionFor('continue', '', ''), 'Continue straight');
    });
  });

  group('parseOsrmRoute', () {
    test('parses geometry, totals, and steps', () {
      final route = parseOsrmRoute(sampleOsrm())!;
      expect(route.points, hasLength(3));
      expect(route.points.first, const LatLng(18.6545, 73.9412));
      expect(route.distanceM, closeTo(2300.5, 0.01));
      expect(route.durationS, closeTo(320.0, 0.01));
      expect(route.steps, hasLength(3));
      expect(route.steps[1].instruction, 'Turn right onto MG Road');
      expect(route.steps.last.instruction, 'Arrive at destination');
      expect(formatRouteLabel(route), '2.3 km · ~5 min');
    });

    test('rejects non-Ok and malformed payloads', () {
      expect(parseOsrmRoute({'code': 'NoRoute', 'routes': []}), isNull);
      expect(parseOsrmRoute({'code': 'Ok', 'routes': []}), isNull);
      expect(parseOsrmRoute({'code': 'Ok'}), isNull);
      expect(parseOsrmRoute([]), isNull);
      expect(parseOsrmRoute(null), isNull);
    });

    test('step distances format', () {
      expect(formatStepDistance(350), '350 m');
      expect(formatStepDistance(1500), '1.5 km');
    });
  });

  group('RoutingRepository.fetchRoute', () {
    const origin = LatLng(18.6545, 73.9412);
    const dest = LatLng(18.6645, 73.9512);

    test('returns route on 200 Ok', () async {
      final repo = RoutingRepository();
      final client = MockClient((_) async => http.Response(jsonEncode(sampleOsrm()), 200));
      final route = await repo.fetchRoute(origin: origin, destination: dest, client: client);
      expect(route, isNotNull);
      expect(route!.steps, hasLength(3));
    });

    test('requests lng,lat order', () async {
      final repo = RoutingRepository();
      Uri? seen;
      final client = MockClient((req) async {
        seen = req.url;
        return http.Response(jsonEncode(sampleOsrm()), 200);
      });
      await repo.fetchRoute(origin: origin, destination: dest, client: client);
      expect(seen.toString(), contains('73.9412,18.6545;73.9512,18.6645'));
      expect(seen.toString(), contains('geometries=geojson'));
      expect(seen.toString(), contains('steps=true'));
    });

    test('null on non-200, bad code, and throw', () async {
      final repo = RoutingRepository();
      final bad = MockClient((_) async => http.Response('err', 500));
      expect(await repo.fetchRoute(origin: origin, destination: dest, client: bad), isNull);
      final noRoute = MockClient((_) async => http.Response('{"code":"NoRoute","routes":[]}', 200));
      expect(await repo.fetchRoute(origin: origin, destination: dest, client: noRoute), isNull);
      final throwing = MockClient((_) async => throw Exception('offline'));
      expect(await repo.fetchRoute(origin: origin, destination: dest, client: throwing), isNull);
    });
  });

  testWidgets('setRouteEndpoints and clearRoute', (t) async {
    late WidgetRef captured;
    await t.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    const o = LatLng(18.65, 73.94);
    const d = LatLng(18.66, 73.95);
    setRouteEndpoints(captured, o, d);
    await t.pump();
    expect(captured.read(routeOriginProvider), o);
    expect(captured.read(routeDestinationProvider), d);
    clearRoute(captured);
    await t.pump();
    expect(captured.read(routeOriginProvider), isNull);
    expect(captured.read(routeDestinationProvider), isNull);
    expect(captured.read(navigatingProvider), isFalse);
  });

  testWidgets('ConvoyMap placeholder survives route load (native lines only)',
      (t) async {
    final route = parseOsrmRoute(sampleOsrm())!;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          routesProvider.overrideWith((ref) => Future.value([route])),
          mapNativeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    // Route polylines are MapLibre lines (native-only); the test seam
    // renders the placeholder and must not crash on route state.
    expect(find.bySemanticsLabel('Trip destination'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('ConvoyMap placeholder survives empty route', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          // Explicit empty: never hit the real network in widget tests.
          routesProvider.overrideWith((ref) => Future.value(<TripRoute>[])),
          mapNativeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    expect(find.bySemanticsLabel('Trip destination'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  group('alternates + Maps helpers', () {
    Map<String, dynamic> twoRouteOsrm() {
      final base = sampleOsrm();
      final first = (base['routes'] as List).first as Map<String, dynamic>;
      final second = Map<String, dynamic>.from(first)
        ..['distance'] = 3100.0
        ..['duration'] = 480.0;
      return {
        'code': 'Ok',
        'routes': [first, second],
      };
    }

    test('parseOsrmRoutes returns best-first list, caps at 3', () {
      final routes = parseOsrmRoutes(twoRouteOsrm());
      expect(routes, hasLength(2));
      expect(routes.first.distanceM, closeTo(2300.5, 0.01));
      expect(routes.last.durationS, closeTo(480.0, 0.01));
      final first = (twoRouteOsrm()['routes'] as List).first;
      final four = {
        'code': 'Ok',
        'routes': [first, first, first, first],
      };
      expect(parseOsrmRoutes(four), hasLength(3));
      expect(
        parseOsrmRoutes({
          'code': 'Ok',
          'routes': [
            {'bad': true},
          ],
        }),
        isEmpty,
      );
    });

    test('fetchRoutes requests alternatives, [] on failure', () async {
      const origin = LatLng(18.6545, 73.9412);
      const dest = LatLng(18.6645, 73.9512);
      final repo = RoutingRepository();
      Uri? seen;
      final client = MockClient((req) async {
        seen = req.url;
        return http.Response(jsonEncode(twoRouteOsrm()), 200);
      });
      final routes = await repo.fetchRoutes(
        origin: origin,
        destination: dest,
        client: client,
      );
      expect(routes, hasLength(2));
      expect(seen.toString(), contains('alternatives=true'));
      final bad = MockClient((_) async => http.Response('err', 500));
      expect(
        await repo.fetchRoutes(origin: origin, destination: dest, client: bad),
        isEmpty,
      );
    });

    test('formatLongDuration Maps wording', () {
      expect(formatLongDuration(45 * 60), '45 min');
      expect(formatLongDuration(320), '5 min');
      expect(formatLongDuration(78 * 60), '1 hr 18 min');
      expect(formatLongDuration(120 * 60), '2 hr');
    });

    test('formatArrivalTime clock formatting', () {
      expect(
        formatArrivalTime(3600, now: DateTime(2026, 1, 1, 12, 0)),
        '1:00 PM',
      );
      expect(
        formatArrivalTime(3600, now: DateTime(2026, 1, 1, 23, 30)),
        '12:30 AM',
      );
      expect(
        formatArrivalTime(0, now: DateTime(2026, 1, 1, 9, 5)),
        '9:05 AM',
      );
    });

    test('routeViaName picks first named road', () {
      expect(routeViaName(parseOsrmRoute(sampleOsrm())!), 'via MG Road');
      const unnamed = TripRoute(
        points: [LatLng(0, 0), LatLng(1, 1)],
        distanceM: 1,
        durationS: 1,
        steps: [
          RouteStep(
            instruction: 'Continue straight',
            maneuverType: 'continue',
            modifier: '',
            distanceM: 1,
            durationS: 1,
            location: LatLng(0, 0),
          ),
        ],
      );
      expect(routeViaName(unnamed), isEmpty);
    });

    test('maneuverIcon mapping', () {
      expect(maneuverIcon('turn', 'right'), Icons.turn_right);
      expect(maneuverIcon('turn', 'slight left'), Icons.turn_slight_left);
      expect(maneuverIcon('turn', 'uturn'), Icons.u_turn_left);
      expect(maneuverIcon('arrive', ''), Icons.flag);
      expect(maneuverIcon('roundabout', 'straight'), Icons.loop);
      expect(maneuverIcon('depart', 'north'), Icons.navigation);
      expect(maneuverIcon('off ramp', ''), Icons.call_merge);
      expect(maneuverIcon('something-else', ''), Icons.straight);
    });
  });

  // --- Merged from feat/navora-gmaps-parity (Valhalla + fallback) ---
  group('decodePolyline', () {
    test('decodes precision-5 reference vector', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
      expect(pts, hasLength(3));
      expect(pts.first.latitude, closeTo(38.5, 0.0001));
      expect(pts.first.longitude, closeTo(-120.2, 0.0001));
    });

    test('empty string yields empty', () {
      expect(decodePolyline('', precision: 5), isEmpty);
    });
  });

  group('parseValhallaRoute', () {
    test('reads shape/summary/maneuvers', () {
      final r = parseValhallaRoute({
        'trip': {
          'summary': {'length': 1.0, 'time': 120},
          'legs': [
            {
              'shape': '_p~iF~ps|U',
              'maneuvers': [
                {'instruction': 'Head east', 'length': 0.5},
              ],
            }
          ],
        }
      });
      expect(r, isNotNull);
      expect(r!.engine, 'valhalla');
      expect(r.maneuvers.first.instruction, 'Head east');
    });

    test('null on missing shape', () {
      expect(parseValhallaRoute({'trip': {}}), isNull);
    });
  });

  group('RoutingRepository', () {
    test('uses OSRM fallback when Valhalla fails', () async {
      final repo = RoutingRepository();
      final result = await repo.getRoute(
        from: const RoutePoint(18.65, 73.94),
        to: const RoutePoint(18.52, 73.85),
        client: MockClient((req) async {
          if (req.url.host.contains('valhalla')) {
            return http.Response('boom', 500);
          }
          return http.Response(
              jsonEncode({
                'code': 'Ok',
                'routes': [
                  {
                    'geometry': '_p~iF~ps|U',
                    'distance': 1000,
                    'duration': 300,
                    'legs': [
                      {
                        'steps': [
                          {
                            'maneuver': {'type': 'depart'},
                            'name': 'MG Road',
                          }
                        ]
                      }
                    ],
                  }
                ]
              }),
              200);
        }),
      );
      expect(result, isNotNull);
      expect(result!.engine, 'osrm');
    });

    test('null when both engines fail', () async {
      final repo = RoutingRepository();
      final result = await repo.getRoute(
        from: const RoutePoint(18.65, 73.94),
        to: const RoutePoint(18.52, 73.85),
        client: MockClient((_) async => http.Response('x', 500)),
      );
      expect(result, isNull);
    });
  });
}
