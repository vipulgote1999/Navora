# Google Maps UI Research → TripMesh Targets — 2026-10-08

Sources (scraped 2026-10-08, excerpts in `.firecrawl/`):
- Google Navigation SDK docs, "Modify the navigation UI" (`gmaps-nav-controls.md`):
  primary navigation header (next-turn indicator), secondary header beneath it
  (lane guidance), footer/custom-footer slot, ETA card, trip progress bar
  (vertical 12dp bar on the leading side showing destination + current
  position, height adapts to screen breakpoints), speedometer + recenter
  button + logo alignment rules.
- Google Support, "Use navigation in Google Maps - Android"
  (`gmaps-navigate-android.md`): canonical flow —
  1. search a place, 2. tap **Directions** (long-press skips to navigation),
  3. choose transport mode, 4. alternates show **in gray**, tap gray line to
  follow it, 5. tap **Start**, 6. stop via bottom-left Close, 7. bottom
  information card during nav (swipe up for actions, down to hide),
  8. sound control bottom-right.

## Adopted targets (free stack, no new deps, dark-first kept)

1. **Primary maneuver banner** — pinned top card while navigating: big
   maneuver icon + next instruction + distance-to-maneuver, Maps green.
   Driven by existing `nearestStepIndex` + GPS. (SDK: navigation header.)
2. **Bottom ETA card** — arrival clock time + remaining min/km + End control
   while navigating; replaces Start/Stop row. Arrival = now + OSRM
   durationS. (SDK: ETA card + footer slot; Support: bottom info card.)
3. **Gray alternate routes** — OSRM `alternatives=true` (free, keyless),
   alternates drawn gray, selectable via route-option cards showing
   time + road summary (Support: "tap the gray line"; cards are our
   tap-target equivalent since flutter_map 6 polylines take no taps).
4. **Directions entry row** — origin → destination fields with swap control
   in the route card, origin defaults to "Your location" (GPS) with
   trip-area fallback. (Support flow steps 3–4.)
5. **Kept as-is** — bottom info card with steps (= Support info card),
   external-maps fallback, OSM attribution, 48dp/Semantics, throttle/
   permission patterns. No stub buttons (no fake voice/mode controls).

## Explicitly out of scope
Lane guidance art, live traffic colors, voice guidance, transport-mode
tabs, offline packs — all need paid data or heavy new surface.
