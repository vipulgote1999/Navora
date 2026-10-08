import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/places/geocode_repository.dart';

void main() {
  group('parseSearchResults', () {
    test('titles from first segment, caps at 5', () {
      final results = parseSearchResults([
        {
          'display_name': 'Alandi, Khed, Pune, Maharashtra, India',
          'lat': '18.6777',
          'lon': '73.8989',
        },
        {'display_name': 'Nowhere', 'lat': 'bad', 'lon': '73.9'},
        {'display_name': '', 'lat': '18.6', 'lon': '73.9'},
      ]);
      expect(results, hasLength(1));
      expect(results.first.title, 'Alandi');
      expect(results.first.subtitle, contains('Pune'));
      expect(results.first.lat, closeTo(18.6777, 0.0001));
    });

    test('rejects non-list payloads', () {
      expect(parseSearchResults({}), isEmpty);
      expect(parseSearchResults(null), isEmpty);
    });
  });
}
