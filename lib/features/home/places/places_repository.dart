import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geocode_repository.dart';
import 'photon_repository.dart';
import 'place_poi.dart';

/// Keyless POI fetch over the public Overpass API (OpenStreetMap data).
///
/// Usage-gated by the caller (zoom + debounce + distance); every failure —
/// timeout, rate-limit, offline — returns `[]` so the map degrades to
/// tiles-only instead of erroring.
class PlacesRepository {
  static const overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  static const fetchTimeout = Duration(seconds: 10);
  static const searchTimeout = Duration(seconds: 8);

  /// Fetches up to 60 named POIs around ([lat], [lng]).
  ///
  /// [client] is injectable for tests; a fresh client is used per call
  /// otherwise and always closed.
  Future<List<PlacePoi>> fetchNearby({
    required double lat,
    required double lng,
    http.Client? client,
  }) async {
    // ~1.1km box — a walkable neighbourhood at z14+.
    const halfBox = 0.01;
    final south = lat - halfBox;
    final west = lng - halfBox;
    final north = lat + halfBox;
    final east = lng + halfBox;
    const query = '''
[out:json][timeout:10];
(
  node["amenity"~"^(restaurant|cafe|fast_food|fuel|hospital|pharmacy|atm|bank|school|place_of_worship)\$"](__S__,__W__,__N__,__E__);
  node["shop"](__S__,__W__,__N__,__E__);
  node["tourism"~"^(hotel|guest_house|attraction|museum)\$"](__S__,__W__,__N__,__E__);
);
out 60;
''';
    final body = query
        .replaceAll('__S__', '$south')
        .replaceAll('__W__', '$west')
        .replaceAll('__N__', '$north')
        .replaceAll('__E__', '$east');
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .post(
            Uri.parse(overpassUrl),
            headers: {'User-Agent': 'Navora/1.0 (POI layer)'},
            body: {'data': body},
          )
          .timeout(fetchTimeout);
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return const [];
      return parsePois(json);
    } catch (_) {
      return const [];
    } finally {
      if (owned) httpClient.close();
    }
  }

  /// Geocodes [query] via Nominatim, viewport-biased to ([lat], [lng]).
  ///
  /// Returns at most 5 results; every failure returns `[]`.
  /// [client] is injectable for tests.
  Future<List<PlaceSearchResult>> searchPlaces({
    required String query,
    double? lat,
    double? lng,
    http.Client? client,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final params = <String, String>{
      'q': q,
      'format': 'jsonv2',
      'limit': '5',
      'accept-language': 'en',
    };
    if (lat != null && lng != null) {
      params['viewbox'] = '${lng - 0.3},${lat + 0.3},${lng + 0.3},${lat - 0.3}';
      params['bounded'] = '0';
    }
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .get(
            Uri.parse(nominatimUrl).replace(queryParameters: params),
            headers: {'User-Agent': 'Navora/1.0 (place search)'},
          )
          .timeout(searchTimeout);
      if (res.statusCode != 200) return const [];
      return parseSearchResults(jsonDecode(res.body));
    } catch (_) {
      return const [];
    } finally {
      if (owned) httpClient.close();
    }
  }

  /// Autocompletes [query] via Photon (single call site for `MapsSearchBar`).
  Future<List<PlaceSearchResult>> searchPhoton({
    required String query,
    double? lat,
    double? lng,
    http.Client? client,
  }) =>
      PhotonRepository().autocomplete(
        query: query,
        lat: lat,
        lng: lng,
        client: client,
      );
}
