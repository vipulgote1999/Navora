/// Nearby place (POI) from OpenStreetMap, via the Overpass API.
///
/// Keyless and offline-safe: unnamed elements are dropped, results are
/// capped, and any transport failure surfaces as an empty list (never a
/// throw past the repository boundary).
class PlacePoi {
  final String name;
  final double lat;
  final double lng;

  /// Human kind label: `Restaurant`, `Cafe`, `Fuel`, `ATM`, `Shop`, …
  final String kind;

  const PlacePoi({
    required this.name,
    required this.lat,
    required this.lng,
    required this.kind,
  });
}

/// Maps raw OSM tags to a short display kind. Unknown tags → `Place`.
String poiKindFromTags(Map<String, dynamic> tags) {
  final amenity = (tags['amenity'] as String?)?.toLowerCase();
  const amenityKinds = {
    'restaurant': 'Restaurant',
    'cafe': 'Cafe',
    'fast_food': 'Fast food',
    'fuel': 'Fuel',
    'hospital': 'Hospital',
    'pharmacy': 'Pharmacy',
    'atm': 'ATM',
    'bank': 'Bank',
    'school': 'School',
    'place_of_worship': 'Worship',
  };
  if (amenity != null && amenityKinds.containsKey(amenity)) {
    return amenityKinds[amenity]!;
  }
  final shop = tags['shop'] as String?;
  if (shop != null && shop.isNotEmpty) {
    return shop.length > 14 ? 'Shop' : '${shop[0].toUpperCase()}${shop.substring(1)}';
  }
  final tourism = (tags['tourism'] as String?)?.toLowerCase();
  const tourismKinds = {
    'hotel': 'Hotel',
    'guest_house': 'Guest house',
    'attraction': 'Attraction',
    'museum': 'Museum',
  };
  if (tourism != null && tourismKinds.containsKey(tourism)) {
    return tourismKinds[tourism]!;
  }
  return 'Place';
}

/// Parses an Overpass JSON response into displayable POIs.
///
/// Pure function (no I/O) so it unit-tests without network. Caps at
/// [maxResults] to bound marker count on dense streets.
List<PlacePoi> parsePois(Map<String, dynamic> json, {int maxResults = 60}) {
  final elements = json['elements'];
  if (elements is! List) return const [];
  final out = <PlacePoi>[];
  for (final e in elements) {
    if (out.length >= maxResults) break;
    if (e is! Map<String, dynamic>) continue;
    final tags = e['tags'];
    if (tags is! Map<String, dynamic>) continue;
    final name = (tags['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final lat = (e['lat'] as num?)?.toDouble();
    final lng = (e['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    out.add(PlacePoi(
      name: name,
      lat: lat,
      lng: lng,
      kind: poiKindFromTags(tags),
    ));
  }
  return out;
}
