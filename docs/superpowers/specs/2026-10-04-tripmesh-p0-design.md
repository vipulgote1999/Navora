# TripMesh - Corrected P0 Plan (Mocks-First, Free-Tier, Car-Ready)

Date: 2026-10-04
Scope: Strict P0 only. Mocks-first. Safe template car companion. Phone UX never depends on car approval.
Workspace: /home/vipul/Project/Navora (empty, no git). Plan-only, no code yet.

Product principle: Google Maps gets you there. TripMesh makes sure everyone gets there together. No Maps clone. Convoy-awareness layer only.

## 1. What we are targeting

In for P0:
- Auth (Google, Apple, email only, no phone-auth), profile + vehicle
- Create trip, join via code / QR / deep-link, invite share
- google_maps_flutter convoy map, interpolated markers, fit-convoy, follow-me/leader
- Adaptive location to trips/{tripId}/live/{uid} single doc per member
- Local distance + straight-line ETA + shared route ordering
- Quick-message bottom sheet (7 one-tap), status with expiry
- Start/end trip, privacy banner + delete-on-unshare
- Demo Mode local-only (Car A-E on polyline)
- Emulator + mocks, .env.example, README skeleton
- Car skeleton behind flag OFF: CarService abstraction + Android CarAppService stub + iOS scene stub + DHU/sim notes

Out (stub interfaces only, no UI/logic):
- Stops, falling-behind engine, auto-arrival, FCM production push, offline cache, trip summary, groups, voice, premium, full Auto/CarPlay store release

## 2. Architecture corrections (from review)

Clean + feature-first + Riverpod, repository pattern:

lib/core/theme, location, maps, permissions, utils
lib/features/auth, home, trips, trip_map, participants, quick_messages, navigation, profile, settings, car
lib/shared/widgets, models, repositories

Rules:
- No logic in widgets. Repos expose interfaces. DataSources: Real vs Mock (Directions, Location, FCM, Car).
- CarService abstract: getConvoySnapshot(), sendQuickMessage(), requestNavigate(). Default NoOpCarService. Remote flag carEnabled=false.
- VoiceCommandHandler interface stub only.

## 3. Data model + security (critical fixes)

trips/{tripId}: name, origin{lat,lng,label}, destination{placeId,lat,lng,label}, status[lobby/active/ended], hostUid, joinCode, maxParticipants (P0<=5), thresholds, polylineCache, routeUpdatedAt, createdAt
trips/{tripId}/members/{uid}: role[host/member], vehicleType, vehicleLabel, joinedAt, lastSeen
trips/{tripId}/live/{uid}: lat,lng,heading,speed,accuracy,status,updatedAt(serverTimestamp), expiresAt
trips/{tripId}/events/{id}: system only (joined/started/ended/leader_changed), actorUid, ts
trips/{tripId}/messages/{id}: user templates only (WAIT, GO_AHEAD, FUEL, BREAK, FOOD, HELP, MEET), senderUid, ts, expiresAt
joinCodes/{code}: tripId, expiresAt (reservation to prevent collisions)

Rules (no client-trusted membership):
- live/{uid}: write iff request.auth.uid==uid AND isMember(tripId). Read iff isMember.
- members/{uid}: create only via Function transaction in P0-final; P0-mock allows self-join in emulator with validation function parity.
- Unshare/leave triggers Function (or client + Function sweep in Blaze phase) to delete live/{uid}. Stale live docs TTL-deleted after trip end.
- Demo UIDs (demo-*) denied on real trips.

Join flow: check-then-create replaced by transaction on joinCodes/{code}. Retry on collision. QR = code + deep-link navora://join/TRIP-XXXX.

Events vs messages strictly separated. Every status/message has expiresAt. Clients hide expired. Cleanup Function (Blaze phase only).

## 4. Location engine (corrected throttle)

Android: ACCESS_FINE_LOCATION + FOREGROUND_SERVICE_LOCATION, foregroundServiceType=location, prominent disclosure. iOS: WhenInUse first, escalate to Always only in active convoy, NSLocation strings + blue-bar indicator.

Write rule (combined, not distance-only):
- write if (dist>threshold AND time>minInterval) OR time>maxHeartbeat
- P0: fast 5s/minInterval 5s/>15m, slow 10s/>30m, stopped 60s heartbeat, pause <5km/h
- Drop fixes accuracy>50m, jitter filter (ignore <10m jumps when speed<2m/s)
- updatedAt=serverTimestamp only. Interpolation uses server time, not device clock.

Read: 1 listener per trip on live collection. Detach in background + when speed<5km/h for >5min (show stale). UI: Last updated Xs ago, grey-out after 60-90s. Never present stale as live.

ETA/distance P0: straight-line haversine labeled as such + shared polyline ordering (leader = furthest along route). One cached Routes polyline per trip, 24h TTL. No per-device/per-minute routing calls.

## 5. Map UX P0

google_maps_flutter + VehicleMarker (initial, heading arrow, status color: green active, orange warning, red HELP only). Ticker lerp interpolation. Controls: re-center, fit-convoy via LatLngBounds, follow-me, follow-leader. Bottom: destination, km remaining (polyline remaining), ETA (cached route + avg speed), n/m active. Leader distinct ring. Reduced-motion + high-contrast + screen-reader labels + 48dp targets.

Navigation: Navigate button fires url_launcher to Google Maps app (destination placeId/latlng). No embedded turn-by-turn.

## 6. Auth, trips, messages, start/end, privacy

Auth: firebase_auth Google/Apple/email. users/{uid}: name, photoURL, vehicleType[Car/Bike/SUV/Other], vehicleLabel. No phone-auth in P0 (SMS cost).

Create: name, origin (current/manual), destination (Places search, 1 Routes call cached), private, maxParticipants, thresholds. Output code + link + QR. Share via system share (WhatsApp/Telegram compatible, no SDK).

Join preview: name/host/destination/participants, confirm vehicle, then transaction join.

Quick sheet: 7 large buttons. Single write to messages/. P0 FCM = MOCK_FCM local fan-out (show in-app). Real FCM in P1/Blaze.

Start/end: host-only (Function-validated). Leader orphan fix: if host stale 2-5min, oldest active member auto-promoted (Function in Blaze, client-election + rules in Spark phase with docs). Any member can end after timeout.

Privacy: explicit banner Location sharing is ON, Pause/Leave/Stop. OFF deletes live doc. No tracking outside active trip. Analytics events only (no GPS): app_opened, trip_created/joined/started/completed, quick_message_sent, etc.

## 7. Demo Mode (isolated)

Local-only provider keyed isDemo=true. Cars A-E follow prebuilt polyline with speeds/offsets to demo ahead/behind/stopped. Start/Pause/Reset/End. Banner: Demo: these friends aren't real. Zero Firestore writes in P0 demo. Optional emulator trip trips/demo-* in dev only.

## 8. Car compatibility (safe companion, flag OFF)

No custom map/TBT on head unit. 6-tap limit. Phone UX independent.

Shared: MethodChannel tripmash/car -> CarService snapshot.

Android Auto P0 skeleton:
- CarAppService + ListTemplate/PaneTemplate (trip name, distance, convoy count, top 2-3 members), actions WAIT/STOP/HELP/NAVIGATE
- automotive_app_desc.xml, androidx.car.app metadata, DHU test notes
- No NavigationTemplate TBT in P0 (needs nav-category Play approval)

CarPlay P0 skeleton:
- Swift CPTemplateApplicationSceneDelegate returning CPListTemplate (trip + quick statuses) + CPInformationTemplate
- No CPMapTemplate in P0 (needs com.apple.developer.carplay-maps + review)
- flutter_carplay behind flag, NoOp default. Entitlement request drafts documented, not bundled in TestFlight P0.

Docs required: manifest entries, NSLocation strings, Play Data Safety + disclosure text, Apple Always justification, DHU/sim steps. If denied, phone app unaffected.

## 9. Cost / free-tier plan

Targets: Spark free (50k reads/20k writes/day). Blaze only if Functions needed, with $1/$5 alerts.

Math (4h, blended ~2.1k writes/veh): 5v=10.5k writes PASS / 52k reads FAIL Spark. Reads are limiter due to fan-out.

Guardrails:
- Emulator-first dev, MOCK_DIRECTIONS/MOCK_FCM=true default
- No Functions in Spark phase (Rules + client). Blaze upgrade explicit decision
- No phone-auth, 1 Routes call/trip cached, 1 listener/trip
- Harder throttle (Sec 4), delete live after trip, per-trip write budget 12k + kill-switch + REMOTE_CONFIG live_tracking_enabled
- Free distrib: GitHub Actions + Firebase App Distribution + DHU/simulator, no device farm
- Dashboard: daily quota log, budget alerts

## 10. Testing P0

Unit: haversine, relative (450m behind Rahul), ETA, throttle predicate, expiry, joinCode retry.
Repo/provider tests (Riverpod), widget (TripCard, StatusChip, QuickMessageSheet, ETAWidget), integration with simulator: 5/10/25/50 vehicles, GPS loss, offline, rapid destination change. DHU + iOS sim for car stubs.

## 11. Env + README outline

.env.example: GOOGLE_MAPS_KEY_ANDROID, GOOGLE_MAPS_KEY_IOS, FIREBASE_PROJECT_ID, FIREBASE_OPTIONS, MOCK_DIRECTIONS, MOCK_FCM, carEnabled. Never commit secrets.

README must cover: what/why, arch, Firebase emulator setup, Maps setup, Android/iOS permissions + background, Auto/CarPlay limits + entitlement steps, env, build/run, testing, deploy (App Distribution), cost/privacy notes.

## 12. Deliverable checklist mapping

1. Structure: Sec 2. 2. Implemented: Sec 1 In. 3. Mocked: Directions/FCM/Car/Functions-parity. 4. Needs keys: Maps, Firebase, Apple/Google car entitlements. 5-6. Setup docs: Sec 11. 7-8. Permissions: Sec 4+8. 9-10. Auto/CarPlay limits: Sec 8. 11. Cost: Sec 9. 12-13. Testing/deploy: Sec 10+9.

Next: approve this corrected P0, then proceed to file-level implementation plan (writing-plans) in build mode.
