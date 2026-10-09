# Navora Drive Mode — MapLibre 3D Migration Spec

**Date:** 2026-10-08
**Branch:** `feat/maplibre-drive-mode`
**Status:** Awaiting user review (no implementation yet)
**Prior art:** `docs/tripmesh-gmaps-ui-research-2026-10-08.md`, `TILE_PROVIDERS_RESEARCH.md`,
in-repo nav-parity commit `dbdc512` (green header, white ETA footer, white controls).

## 1. Outcome

Replace the flat north-up `flutter_map` canvas with a MapLibre vector map so that
tapping Navigate enters a Google-style drive mode: tilted perspective camera,
course-up rotation, chevron puck pinned at the lower third, lane-guidance strip,
highway shields, live speed badge, right-side control stack, ETA + Exit footer.
Explore mode keeps today's look (bearing 0, tilt 0). No API keys anywhere.

Success = on-device drive demo shows tilt ~60, rotation following GPS heading,
chevron lower-third, and all overlays from `dbdc512` intact; `flutter analyze`
clean; all existing tests green plus new unit tests.

## 2. Locked decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Single MapLibre map (replace `ConvoyMap` canvas, not dual-map) | One map codebase; explore = tilt/bearing 0 |
| D2 | Package `maplibre_gl`, style `https://tiles.openfreemap.org/styles/liberty` | Keyless + unlimited (repo tile research §2.2); package exposes `bearingTo`/`tiltTo`, `setTrackingCameraOptions(tilt)` for nav-style tilted tracking, `MyLocationTrackingMode.trackingGps`, symbols + lines |
| D3 | Keep `latlong2` in providers/state; convert at MapLibre boundary | Minimal churn: `myPositionProvider`, route models, parsers untouched in type |
| D4 | Overlays stay Flutter widgets | Header/footer/sheet/FAB work from `dbdc512` is reused, not rewritten |
| D5 | Rotate only when `speed > 1 m/s`, hold last bearing otherwise | Same rule as today's heading wedge; stationary fixes report stale bearings |
| D6 | Posted speed limits are a non-goal | Needs OSM maxspeed lookup (Overpass, rate-limited); badge shows GPS speed only |

## 3. Architecture

```
myPositionProvider (latlong2, existing)
        │ GPS fix + speed + heading
        ▼
DriveCameraController (NEW, pure Dart — no MapLibre import)
  ├─ heading low-pass (α≈0.3) + hold-last-bearing when slow
  ├─ zoom-by-speed curve: fast ≈15.0 → slow ≈17.5
  └─ ahead-point: target = fix projected forward ~15% viewport
        ▼
MapLibreMap adapter (inside ConvoyMap, same widget name/providers)
  ├─ explore:  bearingTo(0) + tiltTo(0)
  └─ guiding:  trackingGps + setTrackingCameraOptions(tilt≈60)
Overlays (existing Flutter): NavHeaderBanner + lane strip + shields +
speed badge + control stack + ETA/Exit footer
```

## 4. Components

1. **`DriveCameraController`** (`lib/features/navigation/drive_camera.dart`): pure
   functions/classes — `smoothHeading(prev, next)`, `zoomForSpeed(mps)`,
   `aheadPoint(fix, headingDeg, zoom)`. Fully unit-testable, zero native deps.
2. **Map adapter** (`convoy_map.dart` rewrite of canvas only): `MapLibreMap`
   with `myLocationEnabled`, symbols for members/destination/POIs/search pin
   (replacing `MarkerLayer`), `addLine`/`updateLine` for selected (blue
   `#4285F4`) + gray alternates (replacing `PolylineLayer`), accuracy circle
   via line/circle layer. Attribution widget shows OpenFreeMap © OpenMapTiles.
3. **OSRM parser extensions** (`route_models.dart`): `RouteStep.ref` (road
   reference e.g. A2/E35 for shields) and `RouteStep.lanes`
   (`intersections[0].lanes`: indications + valid). `fetchRoutes` needs NO new
   query params — lanes/refs ride along `steps=true` when the dataset has them.
4. **Lane strip** (new widget in `nav_banner.dart` area): renders valid-lane
   arrows for the current step; hidden entirely when `lanes` absent (expected
   around Wagholi/Pune — never an empty box).
5. **Speed badge + shields**: GPS speed pill (bottom-start, Maps position);
   shield chips (`ref` split on `;`) in header second line. Absent `ref` → no chips.
6. **Control stack** (restyle `map_fabs.dart`): mic (decorative/disabled with
   tooltip until voice lands), search, sound toggle (mute state provider),
   compass (tap = bearing 0), layers. White circular, 48dp, above ETA card.

## 5. Data flow

`myPositionProvider` fix → controller smooths heading, picks zoom, computes
ahead-point → `animateCamera(newCameraPosition(target, zoom, bearing, tilt),
duration ~300ms, linear)` each fix while guiding; explore mode animates only
on user action/first fix. Reroute (50m/10s) and arrival (25m) listeners in
`_RouteSection` unchanged. `mapFollowModeProvider` semantics unchanged
(`me` = track, `none` = user panned away).

## 6. Platform requirements (verified)

- Android API 21+, iOS 13+ (package minimums). `flutter.minSdkVersion`
  satisfies this — re-verify numeric default in plan phase.
- JDK 21 for Android builds: already auto-provisioned
  (`~/.gradle/jdks/eclipse_adoptium-21`). Dev/CI must not pin JDK 17 for this app.
- Location permissions: already handled (`location_permission.dart`); iOS
  `NSLocationWhenInUseUsageDescription` key presence re-verified in plan phase.
- Flutter 3.44 / Dart 3.12 satisfy package minimums (Flutter 3.29 / Dart 3.7).

## 7. Error handling

| Case | Behavior |
|------|----------|
| Style URL fails | Retry card over last-good map; exponential backoff; never blank |
| GPS loss mid-guidance | Camera holds; header shows last instruction + stale treatment |
| No lanes / no ref | Strip/chips hidden, layout collapses cleanly |
| MapLibre view unavailable (tests, WebGL1) | Overlays + providers still unit/widget-tested; native covered on device |
| Offline | Phase 2 (`OfflineRegionDefinition`); phase 1 surfaces the failure state |

## 8. Testing

- Unit: heading smoothing (wrap-around 359→0), zoom curve clamps,
  ahead-point math; OSRM `ref` + `lanes` parsing incl. absent-field cases.
- Widget: lane strip visible/hidden, shields, speed pill, Exit/End flows —
  overlays pumped with a fake camera controller (no native view).
- Device: explore→guiding transition (tilt/bearing), pan-break → recenter,
  reroute, arrival. Keep all 137 existing tests green.
- Gates: `flutter analyze`, full `flutter test`, fresh debug APK install.

## 9. Migration inventory (files)

- `pubspec.yaml`: add `maplibre_gl` (+ `flutter_compass` iff stationary compass
  wanted — default no); remove `flutter_map` only after parity proven.
- `lib/features/home/widgets/convoy_map.dart`: canvas rewrite (biggest file).
- `lib/features/home/map/map_tiles.dart`: style URLs replace raster templates
  (or sunset file).
- `lib/features/navigation/route_models.dart`: `ref` + `lanes` fields + tests.
- `lib/features/home/widgets/nav_banner.dart`: lane strip + shields.
- `lib/features/home/widgets/map_fabs.dart`: control stack restyle + mute.
- `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`: verify
  location keys (no new perms).
- Tests: `test/navigation/drive_camera_test.dart` (new), parser tests extend,
  overlay tests extend.

## 10. Non-goals (phase 1)

Posted speed-limit circle, voice guidance, offline regions, satellite tilt,
trip progress bar, Web embedding, removing `flutter_map` dep (kept until
parity proven on device).
