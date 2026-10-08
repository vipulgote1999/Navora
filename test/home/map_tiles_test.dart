import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/features/home/map/map_tiles.dart';

void main() {
  group('mapTileLayers', () {
    test('has all three keyless styles', () {
      expect(mapTileLayers.keys,
          containsAll([MapStyle.standard, MapStyle.dark, MapStyle.satellite]));
    });

    test('standard expands OSM z/x/y', () {
      expect(tileUrlFor(MapStyle.standard, 14, 11557, 7327),
          'https://tile.openstreetmap.org/14/11557/7327.png');
    });

    test('satellite keeps Esri z/y/x order', () {
      expect(tileUrlFor(MapStyle.satellite, 14, 11557, 7327),
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/14/7327/11557');
    });

    test('dark uses keyless Mella endpoint', () {
      expect(tileUrlFor(MapStyle.dark, 14, 11557, 7327),
          'https://basemap.queeniemella.cc/tiles/countries/14/11557/7327.png');
    });

    test('every layer carries attribution', () {
      for (final l in mapTileLayers.values) {
        expect(l.attribution.trim(), isNotEmpty);
      }
    });
  });
}
