# MapLibre 3D Drive Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat `flutter_map` canvas with MapLibre vector 3D and add drive-mode camera + overlays.

**Architecture:** Pure-Dart `DriveCameraController` (heading smoothing, zoom-by-speed, ahead-point, update throttle) feeds a rewritten `ConvoyMap` canvas using `maplibre_gl` with OpenFreeMap keyless style; existing Flutter overlays gain lane strip, shields, speed badge, control stack.

**Tech Stack:** Flutter 3.44 / Dart 3.12, `maplibre_gl`, OpenFreeMap liberty style, OSRM (existing), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-08-maplibre-drive-mode-design.md`

## Global Constraints

- Keyless only: no API keys, tokens, or secrets in code, styles, or URLs.
- Android API 21+ / iOS 13+; Android builds require JDK 21 (already provisioned).
- `latlong2.LatLng` stays the type in all providers/models; convert at the MapLibre boundary only.
- Camera rotates only when GPS `speed > 1 m/s`; stationary holds last bearing.
- All tappable controls ≥ 48x48dp with Semantics labels (existing pattern).
- Route blue is `#4285F4`, alternates gray; nav header green is `#188038`.
- Every task ends with `flutter analyze` clean for touched files; full suite green before done.

## Review Focus

- Heading wrap-around jitter (359°→1° flips the camera): `smoothHeading` takes the shortest arc; pinned by wrap tests in Task 2.
- Per-fix camera spam janks tracking: `shouldUpdateCamera` throttles (moved > 2 m OR heading Δ > 3°); pinned by throttle tests in Task 2.
- Lanes absent around Wagholi must hide the strip, never an empty box: pinned by absent-lanes widget test in Task 5.
- Style URL unreachable must show retry over last-good map, never blank: pinned by device checklist in Task 4 (native view can't pump in `flutter test`).
- Stale/slow GPS must hold bearing, never spin: pinned by hold-bearing test in Task 2.

---

### Task 1: OSRM `ref` + `lanes` parsing

**Files:**
- Modify: `lib/features/navigation/route_models.dart`
- Test: `test/navigation/route_models_test.dart` (create if absent — check first)

**Interfaces:**
- Consumes: raw OSRM step JSON (`name`, `ref`, `intersections[0].lanes[]` with `indications[]`, `valid`).
- Produces: `RouteStep.ref` (`String`, default `''`), `RouteStep.lanes` (`List<RouteLane>`, default `const []`); `class RouteLane { final List<String> indications; final bool valid; }` — consumed by Task 5.

- [ ] **Step 1: Write failing tests** — step with `"ref": "A2"`, one intersection with `lanes: [{indications: ["left","straight"], valid: true}, {indications: ["right"], valid: false}]`; assert `ref == 'A2'`, `lanes.length == 2`, `lanes[0].valid == true`; plus a step with no `ref`/`intersections` asserting `ref == ''` and `lanes` empty.
- [ ] **Step 2: Run to verify they fail** — Run: `flutter test test/navigation/route_models_test.dart`. Expected: FAIL (no `ref`/`lanes` members).
- [ ] **Step 3: Implement** — add `ref`/`lanes` fields + `RouteLane`; extend `_parseOneRoute` step parsing (intersections list may be absent/null).
- [ ] **Step 4: Run to verify pass** — Run: `flutter test test/navigation/route_models_test.dart` then full `flutter test`. Expected: PASS, 137+ existing green.
- [ ] **Step 5: Commit** — `git add lib/features/navigation/route_models.dart test/navigation/route_models_test.dart && git commit -m "feat(nav): parse OSRM ref and lane guidance"`

### Task 2: `DriveCameraController` (pure Dart)

**Files:**
- Create: `lib/features/navigation/drive_camera.dart`
- Test: `test/navigation/drive_camera_test.dart`

**Interfaces:**
- Consumes: `latlong2.LatLng` fix, heading deg, speed m/s (existing provider types).
- Produces (consumed by Task 4): `double smoothHeading(double prevDeg, double nextDeg, {double alpha = 0.3})`, `double zoomForSpeed(double speedMps)`, `double forwardMetersForZoom(double zoom, double latitude, {double viewportHeightPx = 800, double fraction = 0.15})`, `LatLng aheadPoint(LatLng fix, double headingDeg, double forwardMeters)`, `bool shouldUpdateCamera({required LatLng prev, required LatLng next, required double prevHeading, required double nextHeading})`.

- [ ] **Step 1: Write failing tests** — `smoothHeading(350, 10) ≈ 356` (shortest arc, α=0.3); `zoomForSpeed(25) == 15.0`, `zoomForSpeed(0) == 17.5`, monotonic between; `forwardMetersForZoom(16, 18.65)` within 200–350 m; `shouldUpdateCamera` false for 1 m move + 1° turn, true for 5 m move, true for 10° turn at same spot.
- [ ] **Step 2: Run to verify they fail** — Run: `flutter test test/navigation/drive_camera_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 3: Implement** — shortest-arc lerp (`((next - prev + 540) % 360) - 180`); zoom curve: `≤3 m/s → 17.5`, `≥22 m/s → 15.0`, linear between, clamped; forward meters = `fraction * 40075016 * cos(lat) / 2^zoom * (viewportHeightPx / 256)`; `aheadPoint` via `Distance().offset`; throttle = moved > 2 m OR heading Δ > 3°.
- [ ] **Step 4: Run to verify pass** — Run: `flutter test test/navigation/drive_camera_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** — `git add lib/features/navigation/drive_camera.dart test/navigation/drive_camera_test.dart && git commit -m "feat(nav): pure-Dart drive camera math"`

### Task 3: Dependency + platform setup

**Files:**
- Modify: `pubspec.yaml`
- Modify (verify only, change iff missing): `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: nothing. Produces: `maplibre_gl` available; minSdk ≥ 21 confirmed; location keys present — consumed by Task 4.

- [ ] **Step 1: Add dep + verify resolve** — add latest stable `maplibre_gl` to `pubspec.yaml`; Run: `flutter pub get`. Expected: resolves, no version conflict.
- [ ] **Step 2: Verify platform floors** — confirm `flutter.minSdkVersion ≥ 21` (inspect `flutter build apk --verbose` config or generated manifest), JDK 21 present (`ls ~/.gradle/jdks`), `NSLocationWhenInUseUsageDescription` in `Info.plist`. Record values in commit message body.
- [ ] **Step 3: Analyze** — Run: `flutter analyze`. Expected: no issues.
- [ ] **Step 4: Commit** — `git add pubspec.yaml pubspec.lock && git commit -m "chore(nav): add maplibre_gl dependency"`

### Task 4a: `ConvoyMap` canvas swap (map, camera, markers)

**Files:**
- Modify: `lib/features/home/widgets/convoy_map.dart`
- Modify or sunset: `lib/features/home/map/map_tiles.dart` (style URLs replace raster templates)

**Interfaces:**
- Consumes: Task 2 functions; existing providers (`myPositionProvider`, `mapFollowModeProvider`, `navigatingProvider`); style `https://tiles.openfreemap.org/styles/liberty`.
- Produces: same `ConvoyMap` widget + provider contract; `MapLibreMap` with `myLocationEnabled`; symbols for members/destination; explore = `bearingTo(0)`/`tiltTo(0)`, guiding = `trackingGps` + `setTrackingCameraOptions(tilt: 60)`; attribution `OpenFreeMap © OpenMapTiles`. Route lines arrive in Task 4b.

- [ ] **Step 1: Swap canvas + markers + camera** — `MapLibreMap`, symbols for members/destination, Task 2 outputs into `animateCamera` per fix (gated by `shouldUpdateCamera`); keep POI/search/trip logic compiling (lines may be stubbed — finished in 4b).
- [ ] **Step 2: Analyze** — Run: `flutter analyze`. Expected: no issues. (Native view can't pump in `flutter test`; covered by device check.)
- [ ] **Step 3: Device verify** — fresh debug APK: explore renders as today; Start → tilt + rotation follow heading; pan breaks follow, recenter resumes.
- [ ] **Step 4: Commit** — `git add lib/features/home/widgets/convoy_map.dart lib/features/home/map/map_tiles.dart && git commit -m "feat(nav): MapLibre canvas with drive tracking"`

### Task 4b: Route lines, pins, attribution

**Files:**
- Modify: `lib/features/home/widgets/convoy_map.dart`

**Interfaces:**
- Consumes: Task 4a canvas; `routesProvider`, `selectedRouteIndexProvider`, `activeRouteProvider`, POI/search providers (existing).
- Produces: `addLine` blue `#4285F4` selected + gray alternates; POI + search pins as symbols; accuracy circle layer; style-failure retry card.

- [ ] **Step 1: Implement lines + pins** — route/alt lines, remaining pins, accuracy circle, retry card on style failure.
- [ ] **Step 2: Analyze** — Run: `flutter analyze`. Expected: no issues.
- [ ] **Step 3: Device verify** — route draws blue with gray alternates; style-offline shows retry, never blank.
- [ ] **Step 4: Commit** — `git add lib/features/home/widgets/convoy_map.dart && git commit -m "feat(nav): MapLibre route lines and pins"`

### Task 5: Lane strip + highway shields

**Files:**
- Modify: `lib/features/home/widgets/nav_banner.dart`
- Test: extend `test/navigation/nav_sheet_test.dart` header group (or nearest banner test)

**Interfaces:**
- Consumes: Task 1 `RouteStep.lanes`/`ref`; current-step index logic (existing).
- Produces: lane strip + shield chips inside `NavHeaderBanner`.

- [ ] **Step 1: Write failing widget tests** — pump `NavHeaderBanner` with a route whose current step has lanes (2 valid + 1 invalid) and `ref: 'A2;E35'`; expect 2 highlighted lane arrows + chips `A2`, `E35`; second case with no lanes/ref expects neither strip nor chips.
- [ ] **Step 2: Run to verify they fail** — Run: `flutter test test/navigation/nav_sheet_test.dart`. Expected: FAIL (no strip).
- [ ] **Step 3: Implement** — lane arrows row (◀ ↑ ▶ mapping from indications; valid = white, invalid = white 40%); shield chips from `ref.split(';')`; whole sections hidden when data absent.
- [ ] **Step 4: Run to verify pass** — Run: `flutter test test/navigation/nav_sheet_test.dart` + full suite. Expected: PASS.
- [ ] **Step 5: Commit** — `git add lib/features/home/widgets/nav_banner.dart test/navigation/nav_sheet_test.dart && git commit -m "feat(nav): lane guidance strip and highway shields"`

### Task 6: Speed badge + control stack

**Files:**
- Modify: `lib/features/home/widgets/map_fabs.dart` (and `map_shell.dart` positioning iff needed)
- Test: extend `test/home/map_shell_test.dart` or nearest FAB test with semantics finds

**Interfaces:**
- Consumes: `myPositionProvider` + new `mySpeedMpsProvider` (`StateProvider<double?>` in `map_ui_providers.dart`, written in `MapFabs._locate` from `pos.speed`, null when unknown/stationary).
- Produces: speed pill bottom-start (visible only while guiding, `km/h`); stack = mic (disabled w/ tooltip `Voice guidance coming soon`), search, sound toggle, compass reset, layers; white circular 48dp.

- [ ] **Step 1: Write failing widget tests** — guiding + speed set → finds `42 km/h` pill; finds semantics `Mute voice`, `Reset north`, `Map style`; mic tooltip text present.
- [ ] **Step 2: Run to verify they fail** — Expected: FAIL.
- [ ] **Step 3: Implement** — speed pill + restyled stack; mic `onPressed: null` with tooltip; compass sets bearing 0 via controller callback prop.
- [ ] **Step 4: Run to verify pass** — widget tests + full suite PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** — `git add <touched files> && git commit -m "feat(nav): speed badge and drive control stack"`

### Task 7: End-to-end gates

- [ ] **Step 1: Full suite** — Run: `flutter test`. Expected: all green (137 + new).
- [ ] **Step 2: Analyze** — Run: `flutter analyze`. Expected: no issues.
- [ ] **Step 3: Device pass** — fresh debug APK on device: explore→Start→tilt/rotate→reroute→arrival→Exit; lane strip on a tagged road if reachable, hidden otherwise; no crash on GPS loss (toggle location).
- [ ] **Step 4: Push** — `git push origin feat/maplibre-drive-mode`.
