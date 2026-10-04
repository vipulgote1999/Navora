# TripMesh P1 — Live Tracking, Stream Providers, Share/Save

Date: 2026-10-04
Status: scope decided by controller (standing autonomy order, no questions).
Scope: client-side + mock-stream only. No Firebase config exists in this
checkout (`google-services.json` / `GoogleService-Info.plist` absent), so
nothing here touches the network except the existing OSM/Overpass tile/POI
reads. Firestore paths stay interface-ready via `TripRepository`.

## Ruling

P1 = the four carryovers actually shippable without a backend:
1. Continuous GPS tracking to local state (position stream, throttled).
2. `watchTripsProvider` stream replacing every `MockTripDataSource`
   downcast (mock-backed broadcast, Firestore-swappable).
3. Share via system sheet + Save persisted locally.
4. Member-timestamp model change: EXCLUDED (touches shared model + mock
   tests for little P1 gain; liveness stays honest via `watchLive`).

## 1. Live tracking

`MapShell` owns tracking lifecycle: start the position stream when
Explore (nav index 0) is visible AND the app is resumed; stop otherwise
(nav switch, background, dispose). Rationale: no tracking outside the
map view, no battery drain in background.

- Stream: `Geolocator.getPositionStream(locationSettings:
  LocationSettings(accuracy: high, distanceFilter: 15))`.
- Throttle (P0 spec Sec 4, client subset): accept fix if
  `dist > 15m AND dt > 5s` OR `dt > 60s` heartbeat; drop `accuracy > 50m`;
  ignore `< 10m` jumps when `speed < 2m/s` (jitter filter).
- Each accepted fix writes `myPositionProvider` / `myAccuracyMProvider` /
  `myHeadingDegProvider` (heading only when `speed > 1`, existing rule).
- Denied mid-stream: stop stream, show existing `Location off` SnackBar.
- `livePositionsProvider` untouched (still repo-backed; mock yields []).

## 2. Stream providers

- `MockTripDataSource` gains a broadcast `StreamController<void>` change
  signal: emit on `createTrip`/`joinTrip`; add
  `Stream<List<Trip>> watchAllTrips()` yielding current list then
  re-yielding per signal. Close in a `dispose()` (test-only use).
- New `watchTripsProvider = StreamProvider<List<Trip>>` returning
  `ref.watch(tripRepositoryProvider)` cast to `MockTripDataSource`
  `watchAllTrips()` — ONE downcast lives here, deleted everywhere else:
  `assist_chips.dart`, `convoy_map.dart`, `trip_vibe_sheet.dart`,
  `trip_drawer.dart` (+ `map_shell.dart` overlay if it downcasts).
- Loading/error states: `AsyncValue.when` → loading shows existing
  empty-state text; error shows `Couldn't load trips` + retry via
  `ref.invalidate`.
- Firestore swap later: point the provider at the real repo stream; no
  widget changes.

## 3. Share + Save

- Deps: `share_plus: ^10.0.0`, `shared_preferences: ^2.2.0`.
- Share text (exact): `Join my TripMesh trip "<name>" with code <CODE>:
  navora://join/<CODE>`. Via `Share.share(text)`, try/catch silent.
- Save: `savedTripIdsProvider = StateProvider<Set<String>>` hydrated
  once from `SharedPreferences` (`tripmesh_saved_ids` string list);
  toggle writes through. Sheet buttons reflect state (`Save`/`Saved ✓`).
- No new screens; no backend writes.

## 4. Constraints (carry over)

- `ThemeMode.dark` M3, 48dp targets, Semantics on new controls.
- No `google_maps_flutter`, no API keys; OSM/Overpass only.
- Throttle constants exact: 15m / 5s / 60s heartbeat / 50m accuracy cap.
- YAGNI: no FCM, no per-device routing calls, no trip summary, no car.

## 5. Testing

- Unit: throttle predicate (pure function `acceptFix(prev, next, now)`),
  `filterTripsByQuery` unchanged, save round-trip via fake prefs
  (`SharedPreferences.setMockInitialValues`).
- Widget: stream provider emits created trip (mock `createTrip` →
  `expect(find.text(...))`); share/save buttons present with semantics.
- Commands: `flutter analyze`, `flutter test` (full suite must stay green).
