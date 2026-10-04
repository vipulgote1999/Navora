# TripMesh Maps-Home Redesign — Design Spec

Date: 2026-10-04
Status: conversational design approved (Approach A), awaiting written-spec review
Scope: Rebuild `HomeScreen` Maps-style like reference screenshot, using `flutter_map + OSM`, hidden sidebar for TripMesh actions. P0-mock first, no Firestore schema change.

## 1. Intent

Replace current list home (`AppBar + Create/Join buttons + Recent trips`) with a Google-Maps-like home:
floating search over live map, assist chips, location/directions FABs, `Trip vibe` bottom sheet, `Explore / You / Contribute` nav, hidden drawer holding `Create trip / Join trip / Recent trips`. Keep screen simple; map is primary.

Decisions from brainstorming:
- Extra features = all three: convoy live map + TripMesh actions preserved + place/trip details sheet.
- Map stack = `flutter_map + OSM` (no API key, P0-friendly). Diverges from `2026-10-04-tripmesh-p0-design.md Sec 5` (`google_maps_flutter`); abstraction must allow later swap.
- Tab mapping = Option 1 simplified: `Explore` = map, `You` = auth + my trips, `Contribute` = create/join entry, plus Drawer owns Create/Join/Recent list to keep map uncluttered.

## 2. Current design review

`lib/app.dart:10` — `MaterialApp(home: HomeScreen)`, `ThemeMode.dark`, M3 teal seed. `go_router` dependency unused.
`lib/features/home/home_screen.dart:27` — `Scaffold/AppBar/ListView`: auth line, `FilledButton Create`, `OutlinedButton Join`, `Recent trips` via `TripCard`.
`lib/shared/widgets/trip_card.dart:8` — `TripCard(trip, memberCount, status?)` with `Semantics`, date `YYYY-MM-DD`, route `origin -> destination`, `n/m + Chip(status)`.
Strengths: Riverpod (`authStateProvider`, `tripRepositoryProvider`), semantics, dark-first.
Gaps: no map, buttons push list down, no search/chips/FABs/sheet/nav, mock downcast TODO, no location/weather context.

## 3. Reference (Image 1) mapping

- Floating rounded search (logo/mic/avatar) -> `MapsSearchBar` (menu opens Drawer, mic = voice stub, avatar = auth state).
- Chips `Ask Maps / Work·43min / Restaurants` -> `AssistChips`: `Ask TripMesh` (stub), `ActiveTrip·ETA` (from selected trip + straight-line ETA), `Stops/Food/Fuel` (category filter stub).
- Map canvas + bus/H pins + `Jija Banquet Hall` label -> `FlutterMap` OSM tiles + convoy member markers + selected-trip destination marker. Attribution required.
- Right layers/compass -> layers stub + reset-north.
- FABs location + directions -> `MyLocationFAB` (geolocator, once) + `DirectionsFAB` (`url_launcher` to Maps, destination lat/lng).
- Bottom `Local vibe + 33° / 119 NAQI` + `Explore/You/Contribute` -> `TripVibeSheet` (`DraggableScrollableSheet`: trip name, route, `n/m`, status, actions) + status chip (convoy count / GPS age, not AQI) + `NavigationBar`.
- Light map in screenshot vs dark-first app: follow `ThemeMode`; light tiles `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, dark tiles `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png`.

## 4. Architecture

Approach A: Map-shell + Drawer. No new backend.

```
HomeScreen (ConsumerWidget, keeps route name)
 └─ MapShell (Stateful: map controller, nav index, sheet controller)
     ├─ FlutterMap + MarkerLayer (members, destination)
     ├─ MapsSearchBar (floating)
     ├─ AssistChips (horizontal)
     ├─ MapControls (compass/layers) + MapFabs
     ├─ TripVibeSheet (DraggableScrollableSheet)
     ├─ TripNavBar (Explore/You/Contribute)
     └─ TripDrawer (Create/Join/Recent via TripCard)
```

Providers (additive, no breaking existing):
- reuse `tripRepositoryProvider`, `authStateProvider`
- new `navIndexProvider: StateProvider<int>` (0/1/2)
- new `searchQueryProvider: StateProvider<String>`
- new `selectedTripIdProvider: StateProvider<String?>`
- new `mapFollowModeProvider: StateProvider<FollowMode>` (none/me/convoy)
- mock convoy positions derived from `MockTripDataSource.membersFor(tripId)` with fixed offsets; later swaps to `trips/{tripId}/live` listener.

Files:
- Modify: `lib/app.dart`, `lib/features/home/home_screen.dart`
- Create: `lib/features/home/map_shell.dart`, `widgets/maps_search_bar.dart`, `widgets/assist_chips.dart`, `widgets/map_fabs.dart`, `widgets/trip_vibe_sheet.dart`, `widgets/trip_drawer.dart`, `widgets/trip_nav_bar.dart`, `providers/map_ui_providers.dart`
- Deps add: `flutter_map`, `latlong2`, `geolocator`, (`url_launcher` already present)
- Tests: `test/home/map_shell_test.dart`, `test/home/trip_drawer_test.dart`

## 5. Data flow / UX

1. Open Explore -> map centers on active/selected trip destination or default 18.6545, 73.9412 (Wad Mukhwadi / Charholi corridor, zoom 14) with member markers.
2. Search typing updates `searchQueryProvider`; P0 filters local trips/places stub, no network.
3. Chip `ActiveTrip·ETA`: selects most recent trip, shows straight-line haversine km + ETA at 30 km/h city assumption, labeled `~X km · ~Y min straight-line`.
4. Marker/trip tap sets `selectedTripIdProvider` -> sheet expands with `TripCard`-like summary + `Start/Navigate/Share` (Navigate via `url_launcher`, others stub to existing placeholders).
5. `You` tab shows auth + my trips (reuse drawer list filtered); `Contribute` routes to `CreateTripPlaceholderScreen` / join (existing placeholders, no new flow in this spec).
6. Drawer always accessible via menu icon; holds `Create trip`, `Join trip`, `Recent trips` list.

## 6. Error / edge handling

- Location denied/permanently denied: FAB shows `SnackBar` with settings hint, map stays on trip bounds; no crash.
- Offline tiles: OSM tile error widget with retry text; markers still render.
- Empty trips: map shows default bounds + empty-state sheet `No trips yet — create one`.
- Stale GPS: show `Last updated Xs ago`, grey marker after 60-90s (per P0 Sec 4).
- OSM attribution visible at all times.

## 7. Testing

- Unit: haversine ETA label, chip label formatting.
- Widget: shell renders search/chips/map/sheet/nav; drawer opens and lists `TripCard`; marker tap updates sheet; semantics labels present.
- Manual: light/dark, location on/off, offline, empty trips.
- Commands: `flutter analyze`, `flutter test test/home`.

## 8. Constraints

- No `google_maps_flutter`, no Maps API key, no billing.
- Keep `ThemeMode.dark` default, M3, 48dp targets, screen-reader labels.
- No Firestore schema change; mock-only convoy offsets.
- `go_router` migration out of scope (P1 → StatefulShell); keep `Navigator.push` to placeholders.
- YAGNI: no turn-by-turn, no Places API, no FCM, no car changes in this spec.

## 9. Self-review notes

- No TBD/TODO beyond explicitly stubbed voice/Places.
- Consistent with P0 cost/privacy guards; divergence (OSM vs Google) documented in Sec 4 intro.
- Single-plan scope; car, messages, start/end untouched.
