/// Keyless place search over Nominatim (OpenStreetMap geocoder).
///
/// Policy-safe by construction: debounced + min-length gated by the caller,
/// single in-flight request, valid User-Agent, failures → `[]`.
class PlaceSearchResult {
  /// Short title: first segment of the display name.
  final String title;

  /// Full display name for the subtitle line.
  final String subtitle;
  final double lat;
  final double lng;

  const PlaceSearchResult({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });
}

/// Parses a Nominatim JSON array into results. Pure (no I/O).
List<PlaceSearchResult> parseSearchResults(dynamic json,
    {int maxResults = 5}) {
  if (json is! List) return const [];
  final out = <PlaceSearchResult>[];
  for (final e in json) {
    if (out.length >= maxResults) break;
    if (e is! Map<String, dynamic>) continue;
    final display = (e['display_name'] as String?)?.trim();
    final lat = double.tryParse('${e['lat']}');
    final lng = double.tryParse('${e['lon']}');
    if (display == null || display.isEmpty || lat == null || lng == null) {
      continue;
    }
    final title = display.split(',').first.trim();
    out.add(PlaceSearchResult(
      title: title.isEmpty ? display : title,
      subtitle: display,
      lat: lat,
      lng: lng,
    ));
  }
  return out;
}
