import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:navora/features/home/places/photon_repository.dart';
import 'package:navora/features/home/places/geocode_repository.dart';

void main() {
  group('parsePhotonResults', () {
    test('parses GeoJSON features lng/lat order', () {
      final results = parsePhotonResults({
        'features': [
          {
            'geometry': {'coordinates': [73.8567, 18.5204]},
            'properties': {'name': 'Shaniwar Wada', 'city': 'Pune', 'country': 'India'},
          },
          {'geometry': {'coordinates': ['bad', 18.5]}, 'properties': {}},
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.title, 'Shaniwar Wada');
      expect(results.first.lat, closeTo(18.5204, 0.0001));
      expect(results.first.lng, closeTo(73.8567, 0.0001));
    });

    test('rejects non-map payloads', () {
      expect(parsePhotonResults([]), isEmpty);
      expect(parsePhotonResults(null), isEmpty);
    });
  });

  group('PhotonRepository', () {
    test('sends lat/lon bias and User-Agent, returns parsed', () async {
      String? ua;
      final repo = PhotonRepository();
      final results = await repo.autocomplete(
        query: 'wada',
        lat: 18.52,
        lng: 73.85,
        client: MockClient((req) async {
          ua = req.headers['User-Agent'];
          expect(req.url.queryParameters['lat'], '18.52');
          return http.Response(
              jsonEncode({'features': []}), 200);
        }),
      );
      expect(results, isEmpty);
      expect(ua, contains('Navora/1.0'));
    });

    test('short query short-circuits without HTTP', () async {
      var called = false;
      final repo = PhotonRepository();
      final results = await repo.autocomplete(
        query: 'ab',
        client: MockClient((_) async { called = true; return http.Response('{}', 200); }),
      );
      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('failure degrades to empty', () async {
      final repo = PhotonRepository();
      final results = await repo.autocomplete(
        query: 'pune',
        client: MockClient((_) async => http.Response('err', 500)),
      );
      expect(results, isEmpty);
    });
  });

  group('SearchCache', () {
    test('round-trips within TTL', () {
      const r = PlaceSearchResult(title: 'A', subtitle: 'B', lat: 1, lng: 2);
      final cache = SearchCache(ttl: const Duration(minutes: 10));
      cache.put('q|1,2', const [r]);
      expect(cache.get('q|1,2'), hasLength(1));
    });
  });
}
