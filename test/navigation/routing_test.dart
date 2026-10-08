import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:tripmesh/features/navigation/routing_repository.dart';

void main() {
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
