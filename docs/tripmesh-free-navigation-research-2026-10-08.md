# Free Navigation Research — TripMesh (OSRM-first) — 2026-10-08

Verified live: `GET router.project-osrm.org/route/v1/driving/...?overview=full&geometries=geojson&steps=true` → HTTP 200, `{"code":"Ok","routes":[{legs:[{steps:[...]}]}]}` with GeoJSON LineStrings + maneuver/distances. Keyless from this machine, no signup.

## Options compared
| Engine | Cost/key | Fit for TripMesh | Verdict |
|---|---|---|---|
| **OSRM public demo server** (`router.project-osrm.org`) | Free, **no key**, fair-use rate limits | Driving/walking/cycling profiles; `geometries=geojson` drops straight into `flutter_map` Polyline; `steps=true` gives turn-by-turn maneuvers; self-hostable later for scale | **Chosen for v1** — matches keyless OSM/Overpass/Nominatim philosophy, zero billing surface |
| Valhalla public (`valhalla1.openstreetmap.de`) | Free, no key, community-hosted | Rich costing (auto/bicycle/pedestrian, truck), but larger responses, less stable demo, more parsing work | Backup/self-host candidate, not v1 |
| GraphHopper | Free tier ~500 req/day **with API key** | Good API + matrix/iso, but key provisioning + quota tracking violates keyless constraint | Rejected for v1 |
| OpenRouteService | Free tier ~2000 req/day **with API key** | Nice profiles + extras, same key/quota problem | Rejected for v1 |
| Google Directions / Maps SDK | Pay-as-you-go, key + billing | Best traffic/ETA, but billing + keys + ToS display rules | Rejected — kept only as external-app fallback intent (already in app, free to link) |

## Chosen design (free, keyless, minimal new surface)
- **Service:** `RoutingRepository.fetchRoute({required origin, required destination, profile=driving, http.Client?})` → GET OSRM with `overview=full&geometries=geojson&steps=true`, 10s timeout, `User-Agent: TripMesh/1.0 (routing)`. Returns `TripRoute?` (null = no-route/offline/rate-limit, never throws). Pure `parseOsrmRoute(json)` for tests.
- **Model:** `TripRoute { points: List<LatLng>, distanceM, durationS, steps: List<RouteStep> }`; `RouteStep { instruction, distanceM, durationS, maneuverType, location }`. Instruction text derived locally from OSRM `maneuver.type + modifier + name` (e.g. "Turn right onto MG Road", "Arrive at destination").
- **State (Riverpod, existing patterns):** `routingRepositoryProvider`, `routeOriginProvider`/`routeDestinationProvider` (LatLng?), `routeProvider` (FutureProvider auto-refetch), `navigatingProvider` (bool), `routeDeviationProvider`? Reroute trigger: nearest-segment distance > 50m → `ref.invalidate(routeProvider)`. Arrival < 25m → stop + "Arrived" SnackBar.
- **Map:** `PolylineLayer` (teal, width 5) under markers in `ConvoyMap`; on route load, fit bounds (origin→destination) via `MapController.fitBounds` guarded try/catch; keep OSM attribution.
- **UI:** extend `TripVibeSheet` (no new screens): route header (routed km + mins, replaces straight-line label when route present), step list (icon per maneuver, current-step highlight = nearest step index), `Start`/`Stop` navigation buttons (48dp, Semantics), loading/no-route/offline inline states, existing external Google Maps button retained as fallback.
- **Tracking reuse:** `TrackingController` + `myPositionProvider` unchanged; while navigating set `mapFollowModeProvider=FollowMode.me` so camera follows GPS; heading wedge already shows bearing.
- **Policy/safety:** single in-flight request, debounce destination changes 600ms (same as search), in-memory cache last origin/dest→route (TTL 5 min), no API keys added, no new paid deps. `flutter_map` 6 already supports PolylineLayer — no new map dep.
- **Tests:** parser tests (Ok/empty/error JSON), repository tests with injected `http.Client` (200/500/timeout), widget test: route polyline renders + step list appears; follow-mode test reuses existing patterns.

## Failure matrix (all degrade, never crash)
- Offline/timeout/non-200/`code != Ok`/empty routes → `null` → sheet shows "No route found — check connection" + retry + external-maps fallback.
- Rate-limit (429) → same no-route card with "Try again shortly".
- Deviation > 50m while navigating → silent refetch once per 10s max.
- Arrival ≤ 25m → stop navigation, keep polyline, show "Arrived".
