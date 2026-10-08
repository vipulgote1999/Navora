/// Keyless raster tile-layer definitions for the maps-home view.
///
/// No API keys, no HTTP logic — just URL templates + attribution consumed
/// by `flutter_map` `TileLayer`s (wired in Task 5).
/// Map style selector for the maps-home view.
enum MapStyle { standard, dark, satellite }

/// A single keyless raster tile layer.
class MapTileLayer {
  final MapStyle style;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;

  const MapTileLayer({
    required this.style,
    required this.urlTemplate,
    this.subdomains = const [],
    required this.attribution,
  });
}

/// Keyless tile layers keyed by [MapStyle].
const Map<MapStyle, MapTileLayer> mapTileLayers = {
  MapStyle.standard: MapTileLayer(
    style: MapStyle.standard,
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: [],
    attribution: 'OpenStreetMap contributors',
  ),
  MapStyle.dark: MapTileLayer(
    style: MapStyle.dark,
    urlTemplate:
        'https://basemap.queeniemella.cc/tiles/countries/{z}/{x}/{y}.png',
    subdomains: [],
    attribution: '© queeniemella.cc | © OpenStreetMap contributors',
  ),
  MapStyle.satellite: MapTileLayer(
    style: MapStyle.satellite,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    subdomains: [],
    attribution: 'Esri, Maxar, Earthstar Geographics',
  ),
};

/// Expands the [style] layer template for tile coordinates (`z`, `x`, `y`).
///
/// Replaces `{z}`, `{x}`, `{y}`, and — when the layer defines subdomains —
/// `{s}` with the first subdomain.
String tileUrlFor(MapStyle style, int z, int x, int y) {
  final layer = mapTileLayers[style]!;
  var url = layer.urlTemplate
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$x')
      .replaceAll('{y}', '$y');
  if (url.contains('{s}') && layer.subdomains.isNotEmpty) {
    url = url.replaceAll('{s}', layer.subdomains.first);
  }
  return url;
}
