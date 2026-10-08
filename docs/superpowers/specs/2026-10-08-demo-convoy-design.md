# Demo Convoy Spec — Abhi, Bapu & Me to Bhosari

**Date:** 2026-10-08
**Branch:** `feat/maplibre-drive-mode` (demo lands on the same branch)
**Status:** Approved design, implementation started
**Prior art:** `docs/superpowers/specs/2026-10-08-maplibre-drive-mode-design.md`,
`DemoConvoy` plan review agreed in chat (sheet entry, human-like pacers,
canned fallback).

## 1. Outcome

One tap ("Demo convoy") stages a living group ride to Bhosari: the user
navigates for real while two autonomous riders (Abhi, Bapu) move along the
same route, each visible to the other in real time as circular letter
avatars. Proves the real-world convoy experience with no backend and no
walking.

Success = tap demo → route to Bhosari loads (live or canned) → Abhi/Bapu
pins glide, arrive, and stop → per-member distance chips read sensibly →
End exits cleanly with no residue. Suite green + analyze clean.

## 2. Locked decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Entry: "Demo convoy" button in TripVibeSheet explore row | One tap, most discoverable |
| D2 | Pacers: human-like (speeds, variance, pauses, arrival) | Reads as real humans next to real GPS |
| D3 | Offline: live OSRM fetch with canned Bhosari fallback | Demo never dies on stage |
| D4 | Demo = scripted `TripRepository` override, no backend | Offline, zero production coupling, clean exit |
| D5 | Add `displayName` to `Member` (+ map/parse, mock data) | Pins/names need it; real backend will too |
| D6 | Per-member remaining chips in sheet ("Abhi · 6 min") | The "following each other" feel, computed locally |

## 3. Architecture

```
[Demo convoy] tap
  → demo trip (origin = fix ?? trip area, destination = Bhosari pin ?? canned)
  → tripRepositoryProvider overridden with DemoConvoyRepository(trip)
  → setRouteEndpoints + navigating = true (normal guidance stack for Me)
DemoConvoyRepository (extends MockTripDataSource or implements TripRepository)
  ├─ membersFor → [Abhi(host), Bapu(member), Me(member)] with displayName
  └─ watchLive(tripId) → Stream ticking LivePositions along route polyline
Per-member progress → remaining distance/ETA chips in sheet
End/X → stop timers, drop override, restore explore
```

## 4. Components

1. **`Member.displayName`** (`shared/models/member.dart`): new field,
   `toMap`/`fromMap`, mock fixtures updated. uid stays the identity key.
2. **`DemoConvoyRepository`** (new, `features/trips/data/`): scripted
   pacers — Abhi starts 35% at ~14 m/s, Bapu 15% at ~9 m/s, sine variance
   ±20%, pause-and-go jitter, `riding` → `arrived`, fresh `updatedAt`
   each tick (stays colored). Emits `[]` pre-start. Timer cancelled on
   last listener drop.
3. **Demo launcher** (TripVibeSheet explore row): creates trip, pins
   Bhosari (search pin if present, else canned coords), sets endpoints,
   starts navigation. All existing guidance (banner, camera, ETA,
   arrival, reroute) runs untouched for Me.
4. **Canned Bhosari route** (new fixture): polyline + steps used when the
   OSRM fetch fails. Must be shaped like a real `TripRoute`.
5. **Per-member chips** (sheet, under ETA card): remaining distance +
   minutes per pacer from route progress; hidden when no live data.
6. **Exit path**: End/X stops pacer timer, clears override + endpoints,
   restores explore. Assert no residue (providers back to mock).

## 5. Data flow

Pacer tick (1s) → progress along polyline → `LivePosition(uid, lat, lng,
heading, speed, ...)` → `watchLive` → convoy pins + chips re-render.
Me flows through the untouched GPS stack. No cross-talk: pacers never
write `myPositionProvider`.

## 6. Error handling

| Case | Behavior |
|------|----------|
| OSRM fails | Canned route engages, notice "Demo route (offline)" |
| No GPS fix | Fallback origin (normal rule); demo still runs |
| Exit mid-drive | Timers cancelled, override dropped, explore restored |
| Hot restart | Override is container-scoped; nothing persists |

## 7. Testing

- Unit: pacer progress math (positions advance/arrive), chips formatting.
- Widget (fake timers): pacers move, arrive, exit cleans up; offline
  fallback engages when repo throws; End stops ticks.
- Sim harness: full demo journey (start → glide → arrive → exit).
- Gates: `flutter analyze`, full `flutter test`, device screenshot of
  three avatars on one route.

## 8. Non-goals

Voice, traffic, real backend sync, >3 riders, editing pacer profiles
in-app, Web embedding.
