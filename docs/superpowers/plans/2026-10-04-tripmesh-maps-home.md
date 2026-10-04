# TripMesh Maps-Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Home as Maps-style shell matching reference screenshot with hidden TripMesh drawer.

**Architecture:** Map-shell + Drawer (Approach A): `HomeScreen` hosts `MapShell` Stack with `FlutterMap` OSM, floating search/chips, FABs, `TripVibeSheet`, `NavigationBar`, `Drawer` reusing `TripCard`.

**Tech Stack:** Flutter 3.12.2 / Dart, flutter_riverpod 3.4.3, flutter_map + latlong2, geolocator, url_launcher 6.3.3 (already present).

**Spec:** `docs/superpowers/specs/2026-10-04-tripmesh-maps-home-redesign-design.md`

## Global Constraints

- No `google_maps_flutter`, no Maps API key, no billing.
- Light tiles `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, dark tiles `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png`; OSM attribution visible at all times.
- Keep `ThemeMode.dark` default from `lib/app.dart:12`, Material3, 48dp touch targets, Semantics labels on all interactive map controls.
- No Firestore schema change; convoy markers are mock offsets from `MockTripDataSource.membersFor(tripId)` only.
- Default map center `18.6545, 73.9412`, zoom `14.0`.
- ETA label format `~X km · ~Y min straight-line` at 30 km/h assumption, always includes `straight-line`.
- `go_router` migration out of scope; keep `Navigator.push` to existing `CreateTripPlaceholderScreen` / `JoinTripPlaceholderScreen`.

## Review Focus

- Location permission denied forever: FAB tap must show SnackBar with settings hint, map stays on trip bounds.
- Offline tiles fail: tile error widget with `Failed to load map tiles — check connection` + retry, markers still render.
- Zero trips: sheet shows `No trips yet — create one to get started.`, map shows default bounds.
- Stale member (>90s): marker greyed + sheet shows `Last updated Xs ago`, never presented as live.
- Dark mode tile switch: dark `ThemeMode` must use CARTO dark URL, light uses OSM URL.

---

### Task 1: Deps + map UI state + ETA util

**Files:**
- Modify: `pubspec.yaml:30-43`
- Create: `lib/features/home/providers/map_ui_providers.dart`
- Create: `lib/core/utils/eta_label.dart`
- Test: `test/home/map_ui_providers_test.dart`

**Interfaces:**
- Consumes: `tripRepositoryProvider` from `lib/features/trips/providers/trip_providers.dart:7`, `authStateProvider` from `lib/features/auth/providers/auth_providers.dart:14`
- Produces:
  - `enum FollowMode { none, me, convoy }`
  - `navIndexProvider: StateProvider<int>`
  - `searchQueryProvider: StateProvider<String>`
  - `selectedTripIdProvider: StateProvider<String?>`
  - `mapFollowModeProvider: StateProvider<FollowMode>`
  - `const defaultMapCenterLat = 18.6545`, `const defaultMapCenterLng = 73.9412`, `const defaultMapZoom = 14.0`
  - `String formatEtaLabel(double kmStraightLine)` in `eta_label.dart`

- [ ] **Step 1: Write failing provider + ETA test**

```dart
test('formatEtaLabel 15km gives straight-line label', () {
  expect(formatEtaLabel(15.0), '~15.0 km · ~30 min straight-line');
});
test('navIndex defaults to 0 Explore', () {
  final c = ProviderContainer();
  expect(c.read(navIndexProvider), 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/map_ui_providers_test.dart -v`
Expected: FAIL with file/function not defined

- [ ] **Step 3: Add deps in `pubspec.yaml`**

Add `flutter_map: ^6.1.0`, `latlong2: ^0.9.1`, `geolocator: ^13.0.1` under `dependencies:`. Keep all existing pins.

- [ ] **Step 4: Implement `map_ui_providers.dart` + `eta_label.dart`**

Implement exact signatures above. `formatEtaLabel(km)`: `mins = (km / 30 * 60).round()`, return `'~${km.toStringAsFixed(1)} km · ~$mins min straight-line'`.

- [ ] **Step 5: Run tests + analyze to verify pass**

Run: `flutter pub get && flutter analyze && flutter test test/home/map_ui_providers_test.dart -v`
Expected: PASS, no analyze errors

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/features/home/providers/map_ui_providers.dart lib/core/utils/eta_label.dart test/home/map_ui_providers_test.dart
git commit -m "feat: add maps-home UI providers and ETA label"
```

### Task 2: Floating search bar + assist chips

**Files:**
- Create: `lib/features/home/widgets/maps_search_bar.dart`
- Create: `lib/features/home/widgets/assist_chips.dart`
- Test: `test/home/maps_search_test.dart`

**Interfaces:**
- Consumes: `searchQueryProvider`, `selectedTripIdProvider` from Task 1; `tripRepositoryProvider` for active-trip label
- Produces:
  - `class MapsSearchBar extends ConsumerWidget { const MapsSearchBar({super.key, required VoidCallback onMenuTap}); }`
  - `class AssistChips extends ConsumerWidget { const AssistChips({super.key}); }` rendering three chips: `Ask TripMesh`, `ActiveTrip · ETA` (uses `formatEtaLabel`), `Stops / Food / Fuel`

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets('search bar has menu, mic, avatar semantics', (t) async {
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: MapsSearchBar(onMenuTap: () {})))));
  expect(find.bySemanticsLabel('Open TripMesh menu'), findsOneWidget);
  expect(find.bySemanticsLabel('Search here'), findsOneWidget);
});
testWidgets('assist chips show Ask + ETA + filter', (t) async {
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: AssistChips()))));
  expect(find.textContaining('Ask TripMesh'), findsOneWidget);
  expect(find.textContaining('straight-line'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/maps_search_test.dart -v`
Expected: FAIL with class not defined

- [ ] **Step 3: Implement `MapsSearchBar` in `lib/features/home/widgets/maps_search_bar.dart`**

Floating `Material(elevation:3, borderRadius:28)` + `TextField` hint `Search here`, leading `IconButton(menu, onMenuTap, semantics Open TripMesh menu, 48dp)`, trailing mic stub + `CircleAvatar` from `authStateProvider` (initial or V). `onChanged` writes `searchQueryProvider`.

- [ ] **Step 4: Implement `AssistChips` in `lib/features/home/widgets/assist_chips.dart`**

Horizontal `ListView` of `AssistChip`s: `Ask TripMesh` (sparkle icon, stub onTap SnackBar `Coming in P1`), middle chip reads most-recent trip from `tripRepositoryProvider` + `formatEtaLabel(12.5)` mock distance, third `Stops / Food / Fuel` stub. All 48dp min height.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/home/maps_search_test.dart -v && flutter analyze`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/widgets/maps_search_bar.dart lib/features/home/widgets/assist_chips.dart test/home/maps_search_test.dart
git commit -m "feat: add floating maps search and assist chips"
```

### Task 3: Map canvas + markers + FABs

**Files:**
- Create: `lib/features/home/widgets/convoy_map.dart`
- Create: `lib/features/home/widgets/map_fabs.dart`
- Test: `test/home/convoy_map_test.dart`

**Interfaces:**
- Consumes: `selectedTripIdProvider`, `mapFollowModeProvider` from Task 1; `MockTripDataSource.membersFor` for mock markers
- Produces:
  - `class ConvoyMap extends ConsumerWidget { const ConvoyMap({super.key}); }` (FlutterMap + TileLayer + MarkerLayer)
  - `class MapFabs extends ConsumerWidget { const MapFabs({super.key}); }` (location + directions, 48dp, semantics `My location`, `Get directions`)
  - `LatLng memberOffset(String uid, int index)` deterministic mock offset: base center + `index * 0.002` lat/lng

- [ ] **Step 1: Write failing map test**

```dart
testWidgets('map renders attribution + H marker + FABs', (t) async {
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: Column(children: [Expanded(child: ConvoyMap()), MapFabs()])))));
  expect(find.textContaining('© OpenStreetMap'), findsOneWidget);
  expect(find.bySemanticsLabel('My location'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/convoy_map_test.dart -v`
Expected: FAIL

- [ ] **Step 3: Implement `ConvoyMap`**

`FlutterMap(options: MapOptions(initialCenter: LatLng(18.6545,73.9412), initialZoom:14))`, `TileLayer(urlTemplate: Theme.of(context).brightness==dark ? darkUrl : lightUrl, errorTileCallback` shows error text), `MarkerLayer` with destination H pin (red circle, semantics `Trip destination`) + per-member pins from `membersFor` with `memberOffset`. Tap marker sets `selectedTripIdProvider`. Includes `RichAttributionWidget` with `© OpenStreetMap contributors © CARTO`.

- [ ] **Step 4: Implement `MapFabs`**

Column of `FloatingActionButton.small` location (sets `mapFollowModeProvider` to me, SnackBar on denied `Location off — showing trip area`) + teal `FloatingActionButton` directions (calls `url_launcher` `https://www.google.com/maps/dir/?api=1&destination=18.6545,73.9412`). Handles offline: no crash.

- [ ] **Step 5: Run test covering Review Focus offline + denied**

Run: `flutter test test/home/convoy_map_test.dart -v`
Expected: PASS. Also `flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/widgets/convoy_map.dart lib/features/home/widgets/map_fabs.dart test/home/convoy_map_test.dart
git commit -m "feat: add OSM convoy map canvas and FABs"
```

### Task 4: Vibe sheet + nav bar + drawer

**Files:**
- Create: `lib/features/home/widgets/trip_vibe_sheet.dart`
- Create: `lib/features/home/widgets/trip_nav_bar.dart`
- Create: `lib/features/home/widgets/trip_drawer.dart`
- Test: `test/home/vibe_drawer_test.dart`

**Interfaces:**
- Consumes: `navIndexProvider`, `selectedTripIdProvider` from Task 1; `TripCard` from `lib/shared/widgets/trip_card.dart:8`; `authStateProvider`
- Produces:
  - `class TripVibeSheet extends ConsumerWidget { const TripVibeSheet({super.key, required DraggableScrollableController controller}); }`
  - `class TripNavBar extends ConsumerWidget { const TripNavBar({super.key}); }` (Explore/You/Contribute, writes `navIndexProvider`)
  - `class TripDrawer extends ConsumerWidget { const TripDrawer({super.key}); }` (Create/Join buttons + Recent `TripCard` list)

- [ ] **Step 1: Write failing sheet/drawer test**

```dart
testWidgets('empty trips shows empty-state + drawer lists TripCards', (t) async {
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: TripVibeSheet(controller: DraggableScrollableController())))));
  expect(find.textContaining('No trips yet'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/vibe_drawer_test.dart -v`
Expected: FAIL

- [ ] **Step 3: Implement `TripVibeSheet`**

`DraggableScrollableSheet(initialChildSize:0.22, min:0.12, max:0.75)` with drag handle semantics `Trip details`, title `Trip vibe` (or trip name when selected), status chip `Last updated Xs ago` greyed after 90s, actions row `Navigate/Share/Save`. Empty state text exactly `No trips yet — create one to get started.`.

- [ ] **Step 4: Implement `TripNavBar` + `TripDrawer`**

NavBar: `NavigationBar(selectedIndex: ref.watch(navIndexProvider), destinations: Explore/You/Contribute with icons explore/person/add, 48dp)`. Drawer: `Drawer` with auth line, `FilledButton Create trip` -> `CreateTripPlaceholderScreen`, `OutlinedButton Join trip` -> `JoinTripPlaceholderScreen`, `Recent trips` list of `TripCard`, all reusing `lib/features/home/home_screen.dart:38-60` logic.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/home/vibe_drawer_test.dart -v && flutter analyze`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/widgets/trip_vibe_sheet.dart lib/features/home/widgets/trip_nav_bar.dart lib/features/home/widgets/trip_drawer.dart test/home/vibe_drawer_test.dart
git commit -m "feat: add vibe sheet, nav bar, and trip drawer"
```

### Task 5: MapShell integration + HomeScreen wiring

**Files:**
- Create: `lib/features/home/map_shell.dart`
- Modify: `lib/features/home/home_screen.dart:27-82`
- Modify: `lib/app.dart:10-24`
- Test: `test/home/map_shell_test.dart`

**Interfaces:**
- Consumes: all widgets + providers from Tasks 1-4
- Produces:
  - `class MapShell extends ConsumerWidget { const MapShell({super.key}); }` Stack composition
  - `HomeScreen.build` returns `MapShell` (keeps class name for route compat)

- [ ] **Step 1: Write failing shell test**

```dart
testWidgets('shell stacks search over map with drawer + nav', (t) async {
  await t.pumpWidget(ProviderScope(child: TripMeshApp()));
  expect(find.byType(ConvoyMap), findsOneWidget);
  expect(find.byType(MapsSearchBar), findsOneWidget);
  expect(find.byType(TripNavBar), findsOneWidget);
  await t.tap(find.bySemanticsLabel('Open TripMesh menu'));
  await t.pumpAndSettle();
  expect(find.byType(TripDrawer), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home/map_shell_test.dart -v`
Expected: FAIL

- [ ] **Step 3: Implement `MapShell` in `lib/features/home/map_shell.dart`**

`MapShell` creates `final sheetController = DraggableScrollableController()` and returns `Scaffold(drawer: TripDrawer, bottomNavigationBar: TripNavBar, body: Stack(children: [ConvoyMap, SafeArea(Column(MapsSearchBar(onMenuTap: openDrawer), AssistChips)), Positioned(right:12, bottom:180, child: MapFabs), TripVibeSheet(controller: sheetController)]))`. `You` index shows auth-filtered list overlay stub, `Contribute` shows create/join quick actions (delegates to drawer routes). No `AppBar`.

- [ ] **Step 4: Rewire `HomeScreen` + `app.dart`**

`HomeScreen.build` returns `const MapShell()`. Keep placeholder screens untouched. Ensure `TripMeshApp` still `ThemeMode.dark` M3.

- [ ] **Step 5: Run full suite to verify it passes**

Run: `flutter analyze && flutter test test/home -v`
Expected: PASS all 5 files

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/map_shell.dart lib/features/home/home_screen.dart lib/app.dart test/home/map_shell_test.dart
git commit -m "feat: wire maps-home shell as new HomeScreen"
```
