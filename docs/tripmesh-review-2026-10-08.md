# TripMesh In-Depth Review — 2026-10-08

## 1. Architecture snapshot
- **Stack:** Flutter (Material3, dark-first) + Riverpod (legacy StateProvider/StreamProvider) + Firebase (unused in checkout, mock mode) + `flutter_map` 6 + `latlong2` + `geolocator` 13 + `http` + `url_launcher` + `share_plus` + `shared_preferences`.
- **Entry:** `main.dart` → `ProviderScope` → `TripMeshApp` (hard `ThemeMode.dark`) → `HomeScreen` → `MapShell`.
- **Maps-home:** `MapShell` (nav index, lifecycle-owned tracking, saved-ids hydrate, startup permission) → `ConvoyMap` (OSM tiles, destination H pin, member pins, blue-dot + heading wedge + accuracy circle, POI pins, search-focus pin) + `MapsSearchBar` + `_SearchResultsDropdown` + `AssistChips` + `TripVibeSheet` + `MapFabs` + `TripNavBar`/`TripDrawer`.
- **Data philosophy (keyless, free):** OSM tiles (`tile.openstreetmap.org`), Overpass POIs, Nominatim search — all no-key, degrade-to-empty on failure. Consistent User-Agent `TripMesh/1.0`.
- **Trips:** `MockTripDataSource` (in-memory, join-code reservation parity, broadcast `watchAllTrips`) consumed via `watchTripsProvider` stream; members via single-key providers (no per-row family watches — good).
- **Tracking:** `TrackingController` (check-only silent start, interactive on gesture) + pure `acceptFix` gate (accuracy>50 veto → dt>60 heartbeat → jitter <10m & speed<2 reject → dist>15m AND dt>5s). OS `distanceFilter:15`. Lifecycle: tracks only on Explore + resumed; stops otherwise (battery-correct).
- **Navigation today:** external-only. `MapFabs._directions` + `TripVibeSheet._navigate/_navigateToPlace` build Google Maps `https://www.google.com/maps/dir/?api=1` URLs and `launchUrl(externalApplication)`. No in-app route, no ETA, no turn list.

## 2. Strengths to preserve
- Battery/lifecycle discipline (stop on nav-away/background, silent auto-start).
- Permission UX (once-per-install startup prompt, check-only vs interactive, deniedForever → Settings action, SnackBar never crashes).
- Test coverage pattern (throttle boundaries, stream, prefs round-trip, timed-pump map widget tests).
- Accessibility (48dp hit targets, Semantics labels) and dark-first M3.
- Degrade-gracefully convention (tiles retry, POI/search → `[]`, trips error → retry card, share/navigate try/catch silent).

## 3. Gaps by area
- **Maps/home:** ETA chip is fake (`formatEtaLabel(12.5)` straight-line, `~30km/h` assumption); `AssistChips` all stub (`Coming in P1`); no route line; member pins use deterministic `memberOffset` (+0.002/index) not real positions; convoy center hardcoded Wagholi.
- **Tracking:** no live-write path (mock `watchLive` yields `[]`); `createdAt` used as liveness proxy (marked TODO, honest but temporary); no background navigation mode.
- **Trips/auth:** mock-only repo, placeholder Create/Join screens, `YouTripsOverlay` mock-auth stub.
- **Search/places:** Nominatim viewport bias fixed ±0.3; Overpass box fixed ±0.01 (~1.1km); zoom gate z14; no caching; POI tap is SnackBar-only.
- **Share/save:** done (exact `navora://join/<CODE>` text, `tripmesh_saved_ids` key). No deep-link handler for `navora://join`.
- **Navigation (core gap):** zero in-app routing. `directionsUri` hardcodes Google Maps web URL — works but kicks user out of app, needs Google Maps installed/browser, no convoy context, no offline story.
- **Config/hygiene:** `GOOGLE_MAPS_KEY_*` placeholders in `.env.example` contradict keyless reality; `app.dart` bypasses `go_router` dep (dead dep); `qr_flutter` unused in checkout; README is stock Flutter template.

## 4. Prioritized free improvement backlog
### Quick wins (no new deps, no keys)
1. Wire ETA chip to real straight-line distance (myPosition → active destination/searchFocus) instead of hardcoded 12.5 km.
2. Remove/justify dead deps (`go_router` or adopt it; `qr_flutter` or drop it); update README from template to TripMesh + OSM attribution.
3. Clean `.env.example` (drop Google Maps keys or mark legacy-external-only).
4. Add `navora://join` deep-link handling (at least code-prefill) so Share text round-trips.
5. Cache last Nominatim/Overpass results in-memory with TTL to cut rate-limit risk.
6. Make Overpass box zoom-scaled and POI categories filterable via Stops/Food/Fuel chip.
### Free navigation (this goal, OSRM-first)
7. `RoutingRepository` over public OSRM (`router.project-osrm.org`, no key) with `overview=full&geometries=geojson&steps=true`.
8. Route polyline layer on `ConvoyMap` + distance/duration header.
9. Turn-by-turn sheet (step list with icons, current-step highlight via nearest-point index).
10. Follow-me navigation mode (camera follows GPS, reroute on >50m deviation, cancel on arrival <25m).
11. Graceful states: loading, no-route, offline, rate-limited (all → inline message + external-Google-Maps fallback retained).
### Later (out of scope now)
- Voice guidance (TTS), offline tiles/packs, background navigation service, live convoy position writes, Firestore backend swap.

## 5. Constraints for navigation work
- Free + keyless only (no Google Directions/Maps SDK billing). OSRM public server; respect rate limits (debounce, cache, single in-flight).
- Keep OSM attribution visible; keep existing throttle/permission/Semantics/48dp patterns.
- `flutter analyze` 0 issues, `flutter test` 0 failures.
- Keep external Google Maps intent as fallback (already a dep via `url_launcher`), never as primary.
