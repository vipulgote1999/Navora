import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/places/place_poi.dart';

void main() {
  group('poiKindFromTags', () {
    test('maps known amenities', () {
      expect(poiKindFromTags({'amenity': 'restaurant'}), 'Restaurant');
      expect(poiKindFromTags({'amenity': 'cafe'}), 'Cafe');
      expect(poiKindFromTags({'amenity': 'fuel'}), 'Fuel');
      expect(poiKindFromTags({'amenity': 'atm'}), 'ATM');
      expect(poiKindFromTags({'amenity': 'hospital'}), 'Hospital');
    });

    test('capitalizes shop values, falls back to Place', () {
      expect(poiKindFromTags({'shop': 'bakery'}), 'Bakery');
      expect(poiKindFromTags({'tourism': 'hotel'}), 'Hotel');
      expect(poiKindFromTags({'highway': 'bus_stop'}), 'Place');
      expect(poiKindFromTags({}), 'Place');
    });
  });

  group('parsePois', () {
    test('keeps named nodes, drops unnamed and tagless', () {
      final pois = parsePois({
        'elements': [
          {
            'type': 'node',
            'lat': 18.65,
            'lon': 73.94,
            'tags': {'name': 'Sharma Hotel', 'amenity': 'restaurant'},
          },
          {
            'type': 'node',
            'lat': 18.66,
            'lon': 73.95,
            'tags': {'amenity': 'atm'},
          },
          {'type': 'node', 'lat': 18.67, 'lon': 73.96},
        ],
      });
      expect(pois, hasLength(1));
      expect(pois.first.name, 'Sharma Hotel');
      expect(pois.first.kind, 'Restaurant');
      expect(pois.first.lat, 18.65);
    });

    test('caps results and ignores malformed payloads', () {
      expect(parsePois({}), isEmpty);
      expect(parsePois({'elements': 'nope'}), isEmpty);
      final many = List.generate(
        80,
        (i) => {
          'type': 'node',
          'lat': 18.0 + i * 0.001,
          'lon': 73.0,
          'tags': {'name': 'Shop $i', 'shop': 'clothes'},
        },
      );
      expect(parsePois({'elements': many}), hasLength(60));
    });
  });
}
