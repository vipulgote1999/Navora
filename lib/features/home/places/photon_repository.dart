import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'geocode_repository.dart';

/// Keyless autocomplete over the Photon API (OpenStreetMap data).
///
/// Policy-safe by construction: min-length gated by the caller path,
/// valid User-Agent, 8s timeout, every failure returns `[]`.
class PhotonRepository {
  static const photonUrl = 'https://photon.komoot.io/api';
  static const autocompleteTimeout = Duration(seconds: 8);

  /// Autocompletes [query] via Photon, biased to ([lat], [lng]) when given.
  ///
  /// Returns at most 5 results; every failure returns `[]`.
  /// [client] is injectable for tests.
  Future<List<PlaceSearchResult>> autocomplete({
    required String query,
    double? lat,
    double? lng,
    http.Client? client,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final params = <String, String>{
      'q': q,
      'limit': '5',
    };
    if (lat != null && lng != null) {
      params['lat'] = '$lat';
      params['lon'] = '$lng';
    }
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .get(
            Uri.parse(photonUrl).replace(queryParameters: params),
            headers: {'User-Agent': 'TripMesh/1.0 (photon autocomplete)'},
          )
          .timeout(autocompleteTimeout);
      if (res.statusCode != 200) return const [];
      return parsePhotonResults(jsonDecode(res.body));
    } catch (_) {
      return const [];
    } finally {
      if (owned) httpClient.close();
    }
  }
}

/// Parses a Photon GeoJSON payload into results. Pure (no I/O).
List<PlaceSearchResult> parsePhotonResults(dynamic json,
    {int maxResults = 5}) {
  if (json is! Map<String, dynamic>) return const [];
  final features = json['features'];
  if (features is! List) return const [];
  final out = <PlaceSearchResult>[];
  for (final f in features) {
    if (out.length >= maxResults) break;
    if (f is! Map<String, dynamic>) continue;
    final geometry = f['geometry'];
    if (geometry is! Map<String, dynamic>) continue;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) continue;
    final lng = double.tryParse('${coords[0]}');
    final lat = double.tryParse('${coords[1]}');
    if (lat == null || lng == null) continue;
    final props = f['properties'];
    final propsMap = props is Map<String, dynamic> ? props : const {};
    String? nonEmpty(String key) {
      final v = (propsMap[key] as String?)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final name = nonEmpty('name');
    final street = nonEmpty('street');
    final city = nonEmpty('city');
    final country = nonEmpty('country');
    final title = name ?? street ?? city ?? 'Unknown place';
    final subtitle = [name, city, country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    out.add(PlaceSearchResult(
      title: title,
      subtitle: subtitle,
      lat: lat,
      lng: lng,
    ));
  }
  return out;
}

/// In-memory search-result cache with TTL expiry.
class SearchCache {
  final Duration ttl;
  final _entries = <String, ({List<PlaceSearchResult> value, DateTime at})>{};

  SearchCache({this.ttl = const Duration(minutes: 10)});

  /// Normalizes a cache key: lowercase trimmed query + rounded coords.
  static String keyFor(String query, double? lat, double? lng) {
    final q = query.trim().toLowerCase();
    final loc = (lat != null && lng != null)
        ? '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}'
        : 'noloc';
    return '$q|$loc';
  }

  List<PlaceSearchResult>? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void put(String key, List<PlaceSearchResult> v) {
    _entries[key] = (value: v, at: DateTime.now());
  }
}
