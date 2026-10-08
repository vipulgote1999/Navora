# Navora Google Maps Parity (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Navora's map, search, and routing to Google Maps parity using only free keyless services, in the isolated worktree on branch `feat/navora-gmaps-parity`.

**Architecture:** Keep the existing `flutter_map` 6 + Riverpod `StateProvider` structure. Add small pure-Dart service files (tile definitions, Photon parser + cache, routing repository with Valhalla-primary/OSRM-fallback) and wire them into the existing `ConvoyMap` / `MapsSearchBar` / `MapShell` UI with graceful degradation.

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_map ^6.1.0, latlong2, http, flutter_riverpod (legacy StateProvider), flutter_test.

**Spec:** `NAVORA_COMPREHENSIVE_RESEARCH.md` (master synthesis) plus `TILE_PROVIDERS_RESEARCH.md`, `ROUTING_API_RESEARCH.md`, `geocoding-research-report.md`, `NAVORA_MAP_RESEARCH.md` — all at the worktree root. Exact endpoint URLs and response shapes below are copied from those reports.

## Global Constraints

- Zero-cost only: keyless endpoints only, no paid APIs, no API-key provisioning in code.
- Every OSM-family HTTP call sends `User-Agent: TripMesh/1.0 (...)` and times out (search 8s, POI 10s, routing 12s).
- Every network failure degrades to empty (`[]` / `null`), never throws to the UI.
- flutter_map v6 API only: `TileLayer(urlTemplate, userAgentPackageName, subdomains?, errorTileCallback, tileBuilder)`. No v7/v8 caching APIs.
- Riverpod legacy pattern: `import 'package:flutter_riverpod/legacy.dart'` for `StateProvider`, as in `lib/features/home/providers/map_ui_providers.dart`.
- Dark-first look preserved; light/dark tile choice follows `Theme.of(context).brightness`.
- Attribution always visible: OSM contributors on standard tiles; add Esri / Mella credit when those layers are active.
- TDD per task: failing test first, watched fail, then pass; commit per task.

## Review Focus

- Tile URL typos (wrong `{z}/{x}/{y}` order, especially Esri `{z}/{y}/{x}`) show blank maps instead of errors — each layer needs a URL-shape test.
- Photon returns GeoJSON `features`, not Nominatim's flat array — a parser written for one shape silently drops the other's results.
- Valhalla polyline `shape` is an encoded polyline string, not GeoJSON — decoding it wrong draws routes across the ocean.
- Nominatim 1 req/s policy: autocomplete without debounce + cache hammers the service and gets blocked.
- Route fetch on every map pan drains battery/data — routing must only fire on explicit user action, never on camera events.

---

### Task 1: Keyless tile-layer definitions + map style provider

**Files:**
- Create: `lib/features/home/map/map_tiles.dart`
- Create: `test/home/map_tiles_test.dart`
- Modify: `lib/features/home/providers/map_ui_providers.dart` (append only, lines 104-110 area)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `enum MapStyle { standard, dark, satellite }` in `lib/features/home/map/map_tiles.dart`
  - `class MapTileLayer { final MapStyle style; final String urlTemplate; final List<String> subdomains; final String attribution; const MapTileLayer(...) }`
  - `const Map<MapStyle, MapTileLayer> mapTileLayers` with exact entries below
  - `String tileUrlFor(MapStyle style, int z, int x, int y)` — expands `{z}/{x}/{y}` (`{s}` → first subdomain)
  - `final mapStyleProvider = StateProvider<MapStyle>((ref) => MapStyle.standard)`

Exact layer table (copied verbatim from `TILE_PROVIDERS_RESEARCH.md`):

| style | urlTemplate | subdomains | attribution |
|---|---|---|---|
| standard | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | `[]` | `OpenStreetMap contributors` |
| dark | `https://basemap.queeniemella.cc/tiles/countries/{z}/{x}/{y}.png` | `[]` | `© queeniemella.cc \| © OpenStreetMap contributors` |
| satellite | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | `[]` | `Esri, Maxar, Earthstar Geographics` |

- [ ] **Step 1: Write the failing test** in `test/home/map_tiles_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/map_tiles_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:tripmesh/features/home/map/map_tiles.dart'"

- [ ] **Step 3: Implement `MapStyle`, `MapTileLayer`, `mapTileLayers`, `tileUrlFor` in `lib/features/home/map/map_tiles.dart`** using the exact table above. `{s}` expansion: replace `{s}` with `subdomains.first` when non-empty. No HTTP, no keys.

- [ ] **Step 4: Append `mapStyleProvider` to `lib/features/home/providers/map_ui_providers.dart`** (after `searchFocusProvider`, before the default-center constants). One line + doc comment, no other edits.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/home/map_tiles_test.dart`
Expected: PASS (5/5)

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/map/map_tiles.dart test/home/map_tiles_test.dart lib/features/home/providers/map_ui_providers.dart
git commit -m "feat: keyless tile layers with style provider"
```

---

### Task 2: Photon autocomplete parser + TTL search cache

**Files:**
- Create: `lib/features/home/places/photon_repository.dart`
- Create: `test/home/photon_test.dart`
- Modify: `lib/features/home/places/places_repository.dart` (add `searchPhoton` method only)

**Interfaces:**
- Consumes: `PlaceSearchResult` from `lib/features/home/places/geocode_repository.dart`.
- Produces:
  - `List<PlaceSearchResult> parsePhotonResults(dynamic json, {int maxResults = 5})` — pure, parses GeoJSON `features` (`properties.name`/`city`/`street`/`country`, `geometry.coordinates` as `[lng, lat]`).
  - `class PhotonRepository { Future<List<PlaceSearchResult>> autocomplete({required String query, double? lat, double? lng, http.Client? client}) }` — GET `https://photon.komoot.io/api` with `q`, `limit=5`, `lat`/`lon` bias when given; 8s timeout; `User-Agent: TripMesh/1.0 (photon autocomplete)`; failures → `[]`; min 3 chars → `[]`.
  - `class SearchCache { SearchCache({Duration ttl = 10min}); List<PlaceSearchResult>? get(String key); void put(String key, List<PlaceSearchResult> v); }` — in-memory, TTL-expiry, key = `q|lat,lng` rounded to 3 decimals.
  - `PlacesRepository.searchPhoton(...)` — thin delegate to `PhotonRepository().autocomplete(...)` so `MapsSearchBar` has one call site.

Photon shape (from `geocoding-research-report.md`): `GET https://photon.komoot.io/api?q=Brandenburger&limit=5&lat=52.52&lon=13.40` → `{"features": [{"geometry": {"coordinates": [13.40, 52.52]}, "properties": {"name": "Brandenburger Tor", "city": "Berlin", "country": "Germany"}}]}`. Title = `properties.name ?? street ?? city ?? "Unknown place"`; subtitle = `[name, city, country].non-empty.join(', ')`.

- [ ] **Step 1: Write the failing test** in `test/home/photon_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:tripmesh/features/home/places/photon_repository.dart';

void main() {
  group('parsePhotonResults', () {
    test('parses GeoJSON features lng/lat order', () {
      final results = parsePhotonResults({
        'features': [
          {
            'geometry': {'coordinates': [73.8567, 18.5204]},
            'properties': {'name': 'Shaniwar Wada', 'city': 'Pune', 'country': 'India'},
          },
          {'geometry': {'coordinates': ['bad', 18.5]}, 'properties': {}},
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.title, 'Shaniwar Wada');
      expect(results.first.lat, closeTo(18.5204, 0.0001));
      expect(results.first.lng, closeTo(73.8567, 0.0001));
    });

    test('rejects non-map payloads', () {
      expect(parsePhotonResults([]), isEmpty);
      expect(parsePhotonResults(null), isEmpty);
    });
  });

  group('PhotonRepository', () {
    test('sends lat/lon bias and User-Agent, returns parsed', () async {
      String? ua;
      final repo = PhotonRepository();
      final results = await repo.autocomplete(
        query: 'wada',
        lat: 18.52,
        lng: 73.85,
        client: MockClient((req) async {
          ua = req.headers['User-Agent'];
          expect(req.url.queryParameters['lat'], '18.52');
          return http.Response(
              jsonEncode({'features': []}), 200);
        }),
      );
      expect(results, isEmpty);
      expect(ua, contains('TripMesh/1.0'));
    });

    test('short query short-circuits without HTTP', () async {
      var called = false;
      final repo = PhotonRepository();
      final results = await repo.autocomplete(
        query: 'ab',
        client: MockClient((_) async { called = true; return http.Response('{}', 200); }),
      );
      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('failure degrades to empty', () async {
      final repo = PhotonRepository();
      final results = await repo.autocomplete(
        query: 'pune',
        client: MockClient((_) async => http.Response('err', 500)),
      );
      expect(results, isEmpty);
    });
  });

  group('SearchCache', () {
    test('round-trips within TTL', () {
      const r = PlaceSearchResultRef(title: 'A', subtitle: 'B', lat: 1, lng: 2);
      final cache = SearchCache(ttl: const Duration(minutes: 10));
      cache.put('q|1,2', const [r]);
      expect(cache.get('q|1,2'), hasLength(1));
    });
  });
}
```

NOTE: `PlaceSearchResult` has a const constructor — use it directly (`const PlaceSearchResult(title: ..., subtitle: ..., lat: ..., lng: ...)`), not `PlaceSearchResultRef`. The sketch above uses the real class name.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/photon_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `parsePhotonResults`, `PhotonRepository`, `SearchCache` in `lib/features/home/places/photon_repository.dart`** per the Photon shape above. `http` import only; `MockClient` lives in tests. Cache key normalization: `q.trim().toLowerCase()` + `|` + `lat.toStringAsFixed(3),lng.toStringAsFixed(3)` (or `noloc` when absent).

- [ ] **Step 4: Add `PlacesRepository.searchPhoton` delegate** in `lib/features/home/places/places_repository.dart` (import photon file, 8-line method, no changes to existing methods).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/home/photon_test.dart test/home/geocode_test.dart`
Expected: PASS (all)

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/places/photon_repository.dart lib/features/home/places/places_repository.dart test/home/photon_test.dart
git commit -m "feat: photon autocomplete with TTL cache"
```

---

### Task 3: Hybrid routing repository (Valhalla primary, OSRM fallback)

**Files:**
- Create: `lib/features/navigation/routing_repository.dart`
- Create: `test/navigation/routing_test.dart`

**Interfaces:**
- Consumes: `LatLng` from `latlong2`.
- Produces:
  - `class RoutePoint { final double lat; final double lng; const RoutePoint(this.lat, this.lng); }`
  - `class RouteManeuver { final String instruction; final double distanceM; final int index; const RouteManeuver(...) }`
  - `class RouteResult { final List<LatLng> points; final double distanceM; final double durationS; final List<RouteManeuver> maneuvers; final String engine; const RouteResult(...) }`
  - `List<LatLng> decodePolyline(String encoded)` — pure Google-encoded-polyline decoder (precision 6 for Valhalla `shape`, precision 5 flag for OSRM).
  - `RouteResult? parseValhallaRoute(Map<String, dynamic> json)` — reads `trip.legs[0].shape` (precision 6), `trip.summary.{length,time}`, `trip.legs[0].maneuvers[i].instruction + .length`; null on missing shape.
  - `RouteResult? parseOsrmRoute(Map<String, dynamic> json)` — reads `routes[0]` with `geometry` polyline5 (precision 5), `distance`, `duration`, `legs[].steps[]` → maneuver text via `osrmInstruction(type, modifier, name, ref)`; null when `code != 'Ok'` or no routes.
  - `class RoutingRepository { Future<RouteResult?> getRoute({required RoutePoint from, required RoutePoint to, http.Client? client}) }` — tries Valhalla POST `https://valhalla1.openstreetmap.de/route` (`{"locations":[{"lat"},{"lat}],"costing":"auto","directions_type":"instructions","language":"en-US"}`, 12s timeout, UA `TripMesh/1.0 (routing)`), falls back to OSRM GET `https://router.project-osrm.org/route/v1/driving/{lng},{lat};{lng},{lat}?overview=full&geometries=polyline&steps=true` on any failure/null; returns null only if both fail.

Valhalla shape (from `ROUTING_API_RESEARCH.md`): `{"trip": {"summary": {"length": 12.3, "time": 900}, "legs": [{"shape": "encoded...", "maneuvers": [{"instruction": "Turn right onto MG Road", "length": 0.5}]}]}}` — summary length is km, time is seconds. OSRM shape: `{"code":"Ok","routes":[{"geometry":"encoded...","distance":12300,"duration":900,"legs":[{"steps":[{"maneuver":{"type":"turn","modifier":"right"},"name":"MG Road"}]}]}]}`.

- [ ] **Step 1: Write the failing test** in `test/navigation/routing_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/navigation/routing_repository.dart';

void main() {
  group('decodePolyline', () {
    test('decodes precision-5 reference vector', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
      expect(pts, hasLength(3));
      expect(pts.first.latitude, closeTo(38.5, 0.0001));
      expect(pts.first.longitude, closeTo(-120.2, 0.0001));
    });

    test('empty string yields empty', () {
      expect(decodePolyline('', precision: 5), isEmpty);
    });
  });

  group('parseValhallaRoute', () {
    test('reads shape/summary/maneuvers', () {
      final r = parseValhallaRoute({
        'trip': {
          'summary': {'length': 1.0, 'time': 120},
          'legs': [
            {
              'shape': '_p~iF~ps|U',
              'maneuvers': [
                {'instruction': 'Head east', 'length': 0.5},
              ],
            }
          ],
        }
      });
      expect(r, isNotNull);
      expect(r!.engine, 'valhalla');
      expect(r.maneuvers.first.instruction, 'Head east');
    });

    test('null on missing shape', () {
      expect(parseValhallaRoute({'trip': {}}), isNull);
    });
  });

  group('RoutingRepository', () {
    test('uses OSRM fallback when Valhalla fails', () async {
      final repo = RoutingRepository();
      final result = await repo.getRoute(
        from: const RoutePoint(18.65, 73.94),
        to: const RoutePoint(18.52, 73.85),
        client: MockClient((req) async {
          if (req.url.host.contains('valhalla')) {
            return http.Response('boom', 500);
          }
          return http.Response(
              jsonEncode({
                'code': 'Ok',
                'routes': [
                  {
                    'geometry': '_p~iF~ps|U',
                    'distance': 1000,
                    'duration': 300,
                    'legs': [
                      {
                        'steps': [
                          {
                            'maneuver': {'type': 'depart'},
                            'name': 'MG Road',
                          }
                        ]
                      }
                    ],
                  }
                ]
              }),
              200);
        }),
      );
      expect(result, isNotNull);
      expect(result!.engine, 'osrm');
    });

    test('null when both engines fail', () async {
      final repo = RoutingRepository();
      final result = await repo.getRoute(
        from: const RoutePoint(18.65, 73.94),
        to: const RoutePoint(18.52, 73.85),
        client: MockClient((_) async => http.Response('x', 500)),
      );
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/navigation/routing_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `decodePolyline` (precision param, default 6), `parseValhallaRoute`, `parseOsrmRoute`, `osrmInstruction`, `RoutingRepository` in `lib/features/navigation/routing_repository.dart`**. `osrmInstruction(type, modifier, name, ref)`: `depart` → `Head out${name.isNotEmpty ? ' on $name' : ''}`; `arrive` → `Arrive at destination`; `roundabout` → `At the roundabout, take exit ${exit ?? 1}`; else `Turn ${modifier ?? type}${name.isNotEmpty ? ' onto $name' : ''}` with empty-modifier collapse. No UI, no providers here.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/navigation/routing_test.dart`
Expected: PASS (all)

- [ ] **Step 5: Commit**

```bash
git add lib/features/navigation/routing_repository.dart test/navigation/routing_test.dart
git commit -m "feat: hybrid valhalla-primary osrm-fallback routing"
```

---

### Task 4: Route display state + navigation banner widget

**Files:**
- Create: `lib/features/navigation/route_providers.dart`
- Create: `lib/features/home/widgets/nav_banner.dart`
- Create: `test/navigation/route_providers_test.dart`
- Create: `test/home/nav_banner_test.dart`

**Interfaces:**
- Consumes: `RouteResult` from Task 3; `StateProvider` legacy pattern.
- Produces:
  - `final activeRouteProvider = StateProvider<RouteResult?>((ref) => null)`
  - `final routeLoadingProvider = StateProvider<bool>((ref) => false)`
  - `final routeErrorProvider = StateProvider<String?>((ref) => null)`
  - `Future<void> fetchRoute(WidgetRef ref, RoutePoint from, RoutePoint to, {RoutingRepository? repo})` — sets loading true/error null, calls repo, sets activeRoute or error text `Couldn't load route — check connection`, loading false. Never throws.
  - `NavBanner extends ConsumerWidget` in `nav_banner.dart`: watches `activeRouteProvider`; `null` → `SizedBox.shrink()`; else top card with first maneuver instruction, distance text (`RouteFormat.distance`), and a close button clearing `activeRouteProvider`. Semantics label `Current maneuver`.

- [ ] **Step 1: Write the failing tests**

`test/navigation/route_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/navigation/route_providers.dart';
import 'package:tripmesh/features/navigation/routing_repository.dart';

void main() {
  test('fetchRoute populates activeRoute on success', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await fetchRoute(
      container,
      const RoutePoint(18.65, 73.94),
      const RoutePoint(18.52, 73.85),
      repo: _OkRepo(),
    );
    expect(container.read(activeRouteProvider), isNotNull);
    expect(container.read(routeLoadingProvider), isFalse);
  });

  test('fetchRoute sets error text on failure, never throws', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await fetchRoute(
      container,
      const RoutePoint(18.65, 73.94),
      const RoutePoint(18.52, 73.85),
      repo: _FailRepo(),
    );
    expect(container.read(activeRouteProvider), isNull);
    expect(container.read(routeErrorProvider), isNotNull);
  });
}
```

`_OkRepo`/`_FailRepo` are test-only subclasses of `RoutingRepository` overriding `getRoute` (no HTTP). If `getRoute` is not overridable, inject via constructor function instead — implementer's choice, tests pin behavior not seam.

`test/home/nav_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/home/widgets/nav_banner.dart';
import 'package:tripmesh/features/navigation/route_providers.dart';
import 'package:tripmesh/features/navigation/routing_repository.dart';

void main() {
  testWidgets('hidden without route, shows maneuver with route', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: NavBanner()))));
    expect(find.bySemanticsLabel('Current maneuver'), findsNothing);
    // Second pump with overridden route tested via container override in impl.
  });
}
```

(The banner test is intentionally minimal: hidden-state + semantics contract. Visible-state is covered by provider tests + manual device check.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/navigation/route_providers_test.dart test/home/nav_banner_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `route_providers.dart`** (`fetchRoute(ref-or-container, ...)` — accept `Ref`/`WidgetRef`; for testability accept `Ref` since `WidgetRef implements Ref`). Distance format helper `RouteFormat.distance(double meters)` → `<1km: '350 m'`, else `'2.3 km'`.

- [ ] **Step 4: Implement `NavBanner`** per contract. Close button: `IconButton(icon: Icon(Icons.close), tooltip: 'Clear route', onPressed: clear)`. Min 48dp touch target.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/navigation/route_providers_test.dart test/home/nav_banner_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/navigation/route_providers.dart lib/features/home/widgets/nav_banner.dart test/navigation/route_providers_test.dart test/home/nav_banner_test.dart
git commit -m "feat: route state with navigation banner"
```

---

### Task 5: Wire style toggle + route polyline into ConvoyMap

**Files:**
- Modify: `lib/features/home/widgets/convoy_map.dart`
- Modify: `lib/features/home/map_shell.dart`
- Create: `test/home/map_style_test.dart`

**Interfaces:**
- Consumes: `mapTileLayers` + `mapStyleProvider` (Task 1), `activeRouteProvider` (Task 4).
- Produces: map renders `TileLayer` from `ref.watch(mapStyleProvider)` (URL + attribution per style, `userAgentPackageName: 'tripmesh'` kept, existing `errorTileCallback` + `tileBuilder` retry unchanged); route polyline via `PolylineLayer` when `activeRouteProvider != null` (color = theme primary, `strokeWidth: 5`); `MapShell` overlays `NavBanner` under the search bar and a style-toggle control (existing `MapFabs` area or AssistChips row — implementer's choice, one control cycling standard → dark → satellite with semantics label `Map style`).

- [ ] **Step 1: Write the failing test** in `test/home/map_style_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/widgets/convoy_map.dart';

void main() {
  testWidgets('convoy map uses dark tile URL when style is dark', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [mapStyleProvider.overrideWith((ref) => MapStyle.dark)],
      child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
    ));
    await t.pump();
    final tileLayer = t.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, contains('queeniemella'));
  });

  testWidgets('convoy map uses satellite URL when style is satellite', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [mapStyleProvider.overrideWith((ref) => MapStyle.satellite)],
      child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
    ));
    await t.pump();
    final tileLayer = t.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, contains('arcgisonline'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/map_style_test.dart`
Expected: FAIL (current `ConvoyMap` ignores `mapStyleProvider`; URL stays OSM)

- [ ] **Step 3: Modify `ConvoyMap`** — replace `lightTileUrl`/`darkTileUrl` branch with `mapTileLayers[ref.watch(mapStyleProvider)]`; attribution widget reflects active layer; add `PolylineLayer(polylines: [Polyline(points: route.points, color: primary, strokeWidth: 5)])` when route present. Delete the now-unused `lightTileUrl`/`darkTileUrl` consts. Keep all existing markers, POI logic, error handling untouched.

- [ ] **Step 4: Modify `MapShell`** — insert `NavBanner` below `_SearchResultsDropdown` and add the style-cycle control. No changes to tracking/nav-index logic.

- [ ] **Step 5: Run full suite**

Run: `flutter test`
Expected: PASS (all tests, pre-existing + new)

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/widgets/convoy_map.dart lib/features/home/map_shell.dart test/home/map_style_test.dart
git commit -m "feat: style toggle with satellite and route polyline"
```

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-08-navora-gmaps-parity.md`. Execution method already supplied (subagent-driven). Please review the plan. Does it capture what you want?
