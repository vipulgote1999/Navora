# TripMesh P0-01 Bootstrap + Auth + Trips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold Flutter app with Firebase emulators, theme, models, mock auth, create/join trip working with tests green.

**Architecture:** Flutter + Riverpod + Clean repository pattern. Real Firestore/Functions behind interfaces, MockDataSources default (`MOCK_*=true`). Single `live/{uid}` doc model, `joinCodes/{code}` reservation.

**Tech Stack:** Flutter stable (3.24+), Dart 3.5+, Riverpod 2.5, firebase_core/auth/cloud_firestore, google_maps_flutter (deferred to P0-02, stub only), qr_flutter, go_router, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-04-tripmesh-p0-design.md` (copy of `/home/vipul/.opencode/plan/tripmesh-p0-corrected-plan.md`)

## Global Constraints

- MOCK_DIRECTIONS=true, MOCK_FCM=true, carEnabled=false defaults, never commit secrets.
- Firestore rules enforce request.auth.uid==docId for live/{uid}, membership-checked reads.
- Every status/message has expiresAt; clients hide expired.
- No phone-auth in P0 (Google/Apple/email only).
- No embedded turn-by-turn; navigation = url_launcher to Google Maps app (P0-02).
- Demo UIDs demo-* denied on real trips.
- `flutter test` must stay green after every task.

## Review Focus

- Join-code collision under concurrent creates expects retry with new code, not duplicate trip.
- GPS jitter stopped (accuracy>50m or <10m jump at <2m/s) expects no Firestore write.
- Stale live doc >90s expects greyed marker + Last updated Xs ago, not live.
- Unshare/leave expects live/{uid} deleted, not just unwatched.
- Demo simulator expects zero Firestore writes (local provider only).
- Add the pinning test for each line in the owning task below.

---

### Task 1: Toolchain + Git + Scaffold + Emulators

**Files:**
- Create: `.gitignore`, `.env.example`, `firebase.json`, `firestore.rules`, `pubspec.yaml` (via flutter create), `lib/main.dart`, `analysis_options.yaml`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Consumes: none
- Produces: runnable `flutter test`, `firebase emulators:start` config, `AppConfig.mockMode==true`

- [ ] **Step 1: Write failing smoke test** in `test/smoke_test.dart`:
```dart
test('app boots in mock mode', () { expect(AppConfig.mockMode, isTrue); });
```
- [ ] **Step 2: Run to verify it fails** Run: `flutter test test/smoke_test.dart -v` Expected: FAIL file not found / AppConfig undefined.
- [ ] **Step 3: Init git + install Flutter + scaffold** `git init; git add -A; git commit -m "chore: init"`. Install Flutter stable via `git clone https://github.com/flutter/flutter.git -b stable ~/flutter && export PATH="$HOME/flutter/bin:$PATH" && flutter doctor`. Run `flutter create --org com.tripmesh --project-name tripmesh .` then add deps: riverpod, firebase_core, firebase_auth, cloud_firestore, go_router, qr_flutter, url_launcher. Create `lib/core/config/app_config.dart` with `static bool mockMode=true`. Create `firebase.json` (firestore + auth emulators 8080/9099), `firestore.rules` (deny by default, allow live write iff request.auth.uid==docId), `.env.example` (GOOGLE_MAPS_KEY_ANDROID/IOS, FIREBASE_PROJECT_ID, MOCK_*).
- [ ] **Step 4: Run to verify it passes** Run: `flutter test test/smoke_test.dart -v` Expected: PASS. Run: `flutter analyze` Expected: no issues.
- [ ] **Step 5: Commit** `git add -A; git commit -m "chore: scaffold flutter + emulators + mock config"`

### Task 2: Core Models + Repository Interfaces

**Files:**
- Create: `lib/shared/models/trip.dart`, `lib/shared/models/member.dart`, `lib/shared/models/live_position.dart`, `lib/shared/models/quick_message.dart`, `lib/shared/repositories/trip_repository.dart`, `lib/shared/repositories/auth_repository.dart`
- Test: `test/models/trip_model_test.dart`

**Interfaces:**
- Consumes: AppConfig.mockMode
- Produces: `Trip(id, name, origin, destination, status, hostUid, joinCode, maxParticipants)`, `Member(uid, role, vehicleType, vehicleLabel)`, `LivePosition(uid, lat, lng, heading, speed, accuracy, status, updatedAt, expiresAt)`, `QuickMessageType` enum, `abstract TripRepository { createTrip(), joinTrip(code), watchTrip(), watchLive() }`, `abstract AuthRepository { signInGoogle/Apple/Email(), signOut(), watchUser() }`

- [ ] **Step 1: Write failing model tests** `trip_model_test.dart`: `Trip.fromMap/toMap` roundtrip, `LivePosition.isStale(now)` true when >90s, `QuickMessage.expiresAt` auto 4h, joinCode regex `^TRIP-[A-Z0-9]{4}$`.
- [ ] **Step 2: Run to verify fails** Run: `flutter test test/models/trip_model_test.dart -v` Expected: FAIL undefined classes.
- [ ] **Step 3: Implement models + abstract repos** Plain Dart classes, no Firebase imports in models. `isStale(DateTime now)=>now.difference(updatedAt).inSeconds>90`. `isExpired` same pattern.
- [ ] **Step 4: Run to verify passes** Run: `flutter test test/models/ -v` Expected: PASS.
- [ ] **Step 5: Commit** `git add lib/shared test/models; git commit -m "feat: core models + repo interfaces"`

### Task 3: Mock Auth + Providers

**Files:**
- Create: `lib/features/auth/data/mock_auth_datasource.dart`, `lib/features/auth/providers/auth_providers.dart`
- Test: `test/auth/mock_auth_test.dart`

**Interfaces:**
- Consumes: AuthRepository
- Produces: `class MockAuthDataSource implements AuthRepository`, providers `authRepositoryProvider`, `authStateProvider`

- [ ] **Step 1: Write failing test**:
```dart
test('google sign-in returns mock user', () async { final u = await repo.signInWithGoogle(); expect(u.uid, startsWith('mock-')); });
test('sign-out clears state', () async { await repo.signOut(); expect(await repo.currentUser(), isNull); });
```
- [ ] **Step 2: Run to verify fails** Run: `flutter test test/auth/mock_auth_test.dart -v` Expected: FAIL.
- [ ] **Step 3: Implement MockAuthDataSource** In-memory currentUser, no network. Google/Apple/email all return `mock-uid` with vehicle defaults Car.
- [ ] **Step 4: Run to verify passes** Run: `flutter test test/auth/ -v` Expected: PASS.
- [ ] **Step 5: Commit** `git add lib/features/auth test/auth; git commit -m "feat: mock auth + providers"`

### Task 4: Trips Create/Join (Mock + Rules Parity)

**Files:**
- Create: `lib/features/trips/data/mock_trip_datasource.dart`, `lib/features/trips/providers/trip_providers.dart`, `lib/core/utils/join_code.dart`
- Test: `test/trips/join_code_test.dart`, `test/trips/mock_trip_test.dart`

**Interfaces:**
- Consumes: TripRepository, AuthRepository
- Produces: `String generateJoinCode()` (`TRIP-XXXX`), `MockTripDataSource implements TripRepository` with `Map<String, Trip> trips`, `Map<String, String> joinCodes` reservation + retry on collision

- [ ] **Step 1: Write failing tests**: `generateJoinCode` matches regex + unique over 100 calls; `createTrip` reserves joinCodes entry; concurrent `createTrip` with forced collision retries (inject colliding code, expect second code differs); `joinTrip('BAD')` throws; demo-uid join on real trip throws.
- [ ] **Step 2: Run to verify fails** Run: `flutter test test/trips/ -v` Expected: FAIL.
- [ ] **Step 3: Implement join_code.dart + MockTripDataSource** Transaction-parity logic: claim joinCodes map first, retry 3x. Firestore rules file already denies demo-* (documented, enforced in mock too).
- [ ] **Step 4: Run to verify passes** Run: `flutter test test/trips/ -v` Expected: PASS. Run: `firebase emulators:start --only firestore,auth` smoke (manual, note in commit msg if skipped).
- [ ] **Step 5: Commit** `git add lib/features/trips lib/core/utils test/trips firestore.rules; git commit -m "feat: trips create/join mock + code reservation"`

### Task 5: Home + TripCard (P0 UI slice)

**Files:**
- Create: `lib/features/home/home_screen.dart`, `lib/shared/widgets/trip_card.dart`, `lib/app.dart`, update `lib/main.dart`
- Test: `test/widgets/trip_card_test.dart`

**Interfaces:**
- Consumes: trip_providers, authStateProvider
- Produces: `HomeScreen`, `TripCard(trip, memberCount, status)` showing name/date/participants/destination/status

- [ ] **Step 1: Write failing widget tests**: TripCard shows name + destination + n/m; Home shows Create/Join buttons + Recent list.
- [ ] **Step 2: Run to verify fails** Run: `flutter test test/widgets/ -v` Expected: FAIL.
- [ ] **Step 3: Implement minimal dark-first UI** Material3, no Maps yet. Create/Join navigate to placeholders (P0-02 owns map). Large 48dp targets, semantics labels.
- [ ] **Step 4: Run to verify passes** Run: `flutter test -v` Expected: ALL PASS. Run: `flutter analyze` Expected: clean.
- [ ] **Step 5: Commit** `git add lib test; git commit -m "feat: home + tripcard UI slice"`

---
## Self-review

- Spec coverage: P0-01 covers auth/create/join/home/mocks/emulators. Map/location/messages/demo/car deferred to P0-02/03 — intentional split for independent testable slices.
- Step scan: each step yields one artifact + checkable command. No TBD.
- Type consistency: Trip/Member/LivePosition names reused verbatim in later plans.
- Proportion: plan shorter than spec, signatures + assertions only.

## Next plans (not in this file)

- P0-02: location engine + convoy map + quick-messages + demo simulator.
- P0-03: car skeleton + privacy hardening + cost guardrails + README + App Distribution.
