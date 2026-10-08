import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/map/map_tiles.dart';

void main() {
  group('mapStyleUrls', () {
    test('has all three keyless styles', () {
      expect(mapStyleUrls.keys,
          containsAll([MapStyle.standard, MapStyle.dark, MapStyle.satellite]));
    });

    test('standard uses OpenFreeMap liberty', () {
      expect(mapStyleUrl(MapStyle.standard),
          'https://tiles.openfreemap.org/styles/liberty');
    });

    test('dark uses OpenFreeMap dark', () {
      expect(
          mapStyleUrl(MapStyle.dark), 'https://tiles.openfreemap.org/styles/dark');
    });

    test('satellite keeps Esri z/y/x overlay template', () {
      expect(esriTileUrl(14, 11557, 7327),
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/14/7327/11557');
    });

    test('attribution credits OSM', () {
      expect(mapAttribution, contains('OpenStreetMap'));
    });
  });
}
