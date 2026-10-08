/// Keyless vector map styles for the maps-home view.
///
/// No API keys, no HTTP logic — just style URLs + attribution consumed by
/// the MapLibre canvas in `ConvoyMap`. Satellite is the liberty vector
/// base with an Esri World Imagery raster overlay added at runtime
/// (hybrid look, still keyless).
enum MapStyle { standard, dark, satellite }

/// MapLibre style documents keyed by [MapStyle].
const Map<MapStyle, String> mapStyleUrls = {
  MapStyle.standard: 'https://tiles.openfreemap.org/styles/liberty',
  MapStyle.dark: 'https://tiles.openfreemap.org/styles/dark',
  // Base for satellite; the Esri overlay is added in ConvoyMap.
  MapStyle.satellite: 'https://tiles.openfreemap.org/styles/liberty',
};

/// Esri World Imagery raster tiles overlaid for [MapStyle.satellite].
///
/// Non-commercial use only; keep behind the style switcher, never default.
const String esriRasterTemplate =
    'https://server.arcgisonline.com/ArcGIS/rest/services/'
    'World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// Attribution shown on the map (OpenFreeMap requires OSM credit).
const String mapAttribution =
    '© OpenStreetMap contributors · © OpenMapTiles';

/// Style document URL for [style].
String mapStyleUrl(MapStyle style) => mapStyleUrls[style]!;

/// Expands [esriRasterTemplate] for tile coordinates (`z`, `x`, `y`).
///
/// Esri uses `z/y/x` order. Kept beside the style map so the satellite
/// overlay template stays tested without a native map view.
String esriTileUrl(int z, int x, int y) => esriRasterTemplate
    .replaceAll('{z}', '$z')
    .replaceAll('{x}', '$x')
    .replaceAll('{y}', '$y');
