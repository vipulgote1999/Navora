# Demo Convoy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One-tap staged group ride to Bhosari with two autonomous pacers and real navigation for Me.

**Architecture:** Scripted `TripRepository` override emitting pacer live positions; `displayName` on `Member`; launcher button + canned fallback + per-member chips; exit restores explore.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Riverpod overrides, `flutter_test` with fake timers.

**Spec:** `docs/superpowers/specs/2026-10-08-demo-convoy-design.md`

## Global Constraints

- Keyless/offline-safe: demo works with zero network (canned fallback).
- Pacers never write `myPositionProvider` (Me stays real).
- All tappables ≥ 48dp with Semantics labels.
- Every task ends with `flutter analyze` clean; full suite green before done.

## Review Focus

- Pacer timer leaking after exit (should stop all ticks; pin with exit test).
- `displayName` missing in any `Member.fromMap` path (old cached maps).
- Canned route shaped unlike real routes (must carry steps + points).
- Chips showing for stale/empty live data (hide when unknown).
- Demo override leaking into non-demo trips (override scoped to demo flow only).

---

### Task 1: `Member.displayName`

**Files:**
- Modify: `lib/shared/models/member.dart`
- Test: `test/models/` (nearest member/model test — check existing first)

**Interfaces:**
- Consumes: nothing. Produces: `Member.displayName` (`String`, default `''`), round-trip in `toMap`/`fromMap` — consumed by pins/chips in Task 4.

- [ ] **Step 1: Write the failing test** — `fromMap(toMap(Member(displayName: 'Abhi')))` preserves `displayName`; default `''` when key absent.
- [ ] **Step 2: Run to verify it fails** — Run: `flutter test <file>`. Expected: FAIL (no field).
- [ ] **Step 3: Implement** — field + map/parse + update mock fixtures/membersFor call sites.
- [ ] **Step 4: Run to verify pass** — file test + full `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(demo): Member displayName"`

### Task 2: Pacer engine + `DemoConvoyRepository`

**Files:**
- Create: `lib/features/trips/data/demo_convoy_repository.dart`
- Test: `test/trips/demo_convoy_test.dart`

**Interfaces:**
- Consumes: route polyline points (`List<LatLng>`), pacer profiles.
- Produces: repo with `membersFor` → 3 display-named members; `watchLive(tripId)` → ticking `LivePosition`s (Abhi 35%/~14 m/s, Bapu 15%/~9 m/s, sine ±20%, pause jitter, `arrived` at end, fresh `updatedAt`); `dispose()` cancels timer — consumed by Task 3.

- [ ] **Step 1: Write failing tests** — positions advance along points; arrival status at end; empty pre-start; dispose stops ticks.
- [ ] **Step 2: Run to verify they fail** — Expected: FAIL (no file).
- [ ] **Step 3: Implement** — cumulative-distance pacer (reuse pattern from `DriveSimulator`), injectable clock/interval for fake timers.
- [ ] **Step 4: Run to verify pass** — new tests + full suite PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(demo): scripted convoy repository"`

### Task 3: Launcher + canned route + exit

**Files:**
- Modify: `lib/features/home/widgets/trip_vibe_sheet.dart` (explore row button + demo start/exit wiring)
- Create: canned Bhosari `TripRoute` fixture (test-adjacent or `lib/…/demo_bhosari_route.dart`)
- Test: extend demo test with widget flow (tap → navigating + override active; End → override dropped, timers stopped)

**Interfaces:**
- Consumes: Task 2 repo; existing `setRouteEndpoints`, `navigatingProvider`, search pin.
- Produces: working demo entry/exit — consumed by Task 4 chips.

- [ ] **Step 1: Write failing widget test** — tap Demo convoy → navigating true, pacer positions flow; End → override gone, no further ticks.
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (no button).
- [ ] **Step 3: Implement** — button, trip setup (origin = fix ?? trip area; dest = search pin ?? canned coords), live-fetch with canned fallback + "Demo route (offline)" notice, exit cleanup.
- [ ] **Step 4: Run to verify pass** — new + full suite PASS, analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(demo): convoy launcher with offline fallback"`

### Task 4: Per-member remaining chips

**Files:**
- Modify: sheet route section (chips under ETA card)
- Test: widget test (chip text per pacer progress; hidden with no live data)

**Interfaces:**
- Consumes: Task 2 live positions + route polyline; Task 1 displayName.
- Produces: "Abhi · 6 min" chips.

- [ ] **Step 1: Write failing widget test** — described above.
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.
- [ ] **Step 3: Implement** — remaining = route length behind pacer → `X.X km · N min` at pacer speed; hide when unknown/stale.
- [ ] **Step 4: Run to verify pass** — new + full suite PASS, analyze clean.
- [ ] **Step 5: Commit** — `git commit -m "feat(demo): per-member remaining chips"`

### Task 5: Sim journey + gates

- [ ] **Step 1: Sim scenario** — start demo → pacers glide → arrive → exit, asserting pins/chips/notice/cleanup via `DriveSim`-style scripted providers.
- [ ] **Step 2: Full suite** — `flutter test` all green.
- [ ] **Step 3: Analyze** — clean.
- [ ] **Step 4: Device pass** — debug APK, screenshot three avatars on one route.
- [ ] **Step 5: Push** — `git push origin feat/maplibre-drive-mode`.
