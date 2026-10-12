# Navora on Android Auto — current state, scaffolding, verification

Branch: `feat/android-auto` (worktree `.worktrees/navora-android-auto`, cut from `main@93c127e`).
Status: **scaffolding lands the car host integration; live map Surface + Photon search results are Phase 2b/2c.**

## 1. Verdict

Phone-only before this branch (single `FlutterActivity`, no `CarAppService`).
After this branch: the APK declares `navigation` to the car host, shows
trips / search / guidance templates in DHU, and mirrors Dart navigation state
into the head unit. No Flutter UI is projected (forbidden by Google) — the car
face is native Car App Library 1.7.0.

## 2. What was added

| Area | Files |
|---|---|
| Gradle | `android/app/build.gradle.kts` → `androidx.car.app:app:1.7.0` + junit |
| Manifest | `android/app/src/main/AndroidManifest.xml` → background/foreground perms, car meta-data, `NavoraCarAppService` (NAVIGATION), `NavoraNavigationService` |
| Descriptor | `android/app/src/main/res/xml/automotive_app_desc.xml` → `<uses name="navigation"/>` |
| Native shell | `car/NavoraCarAppService.kt`, `car/NavoraSession.kt`, `car/CarNavState.kt`, `car/CarBridge.kt` |
| Templates | `car/screens/NavoraRootScreen.kt` (PlaceListMapTemplate), `car/screens/NavoraSearchScreen.kt` (SearchTemplate), `car/screens/NavoraGuidanceScreen.kt` (NavigationTemplate + TravelEstimate) |
| Phone service | `service/NavoraNavigationService.kt` (ongoing notification, location foregroundServiceType) |
| Bridge | `MainActivity.kt` (MethodChannel `navora/car` + EventChannel `navora/car/commands`), `lib/features/car/car_navigation_snapshot.dart`, `lib/features/car/car_channel.dart` |
| Tests | `test/car/car_channel_contract_test.dart`, `android/app/src/test/.../CarNavStateTest.kt` |

Architecture: **Dart is the brain** (OSRM/Photon/trips/tracking), **Kotlin is the car face**.
Dart pushes `updateNavigation/clearNavigation/updateTrips`; car posts
`selectTrip/search/startDemo/endNavigation/toggleMute` back over the event stream.
`CarNavState` is the process-local snapshot both sides share.

## 3. Limits of this scaffolding (next phases)

- No live map Surface on the head unit yet — guidance shows maneuver + ETA + step
  distance ( поворачивает DHU green). Native MapLibre SurfaceCallback is Phase 2c.
- Search echoes the submitted query as one startable row; full Photon result lists
  stream via `updateTrips` in Phase 2b.
- `CarNavState` refresh is action-driven (`invalidate()` on tap); add a
  LifecycleObserver to auto-invalidate on Dart pushes for live ETA ticking.
- `createHostValidator` returns ALLOW_ALL (correct for DHU). Restrict to the
  Play allowlist before store submission.
- Background location still needs the Play Data Safety disclosure + runtime
  rationale UI before requesting `ACCESS_BACKGROUND_LOCATION`.

## 4. Verify locally

```bash
cd .worktrees/navora-android-auto
export PATH="/home/vipul/flutter/bin:$PATH"
flutter analyze
flutter test test/car/car_channel_contract_test.dart
cd android && ./gradlew :app:testDebugUnitTest --tests "com.navora.navora.car.*"
cd android && ./gradlew :app:assembleDebug
```

Manifest merge check (proves the car service reaches the APK):

```bash
grep -o "CarAppService\|car.application\|NAVIGATION\|foregroundServiceType" \
  ../build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml | sort | uniq -c
aapt dump badging ../build/app/outputs/flutter-apk/app-debug.apk | grep -i "uses-permission" | head
```

## 5. DHU (head-unit) manual test

1. Install DHU via SDK Manager (Extras → Android Auto Desktop Head Unit), start it.
2. `adb forward tcp:5277 tcp:5277 && ./gradlew :app:installDebug`
3. In DHU: phone connected → Navora appears under navigation apps.
4. Matrix: trips list (0/1/6+), Search submit → guidance, Demo → maneuver/ETA,
   Mute toggle, End → back to root, day/night, wide + portrait, rotary.
5. Kill phone screen: guidance + notification persist (foreground service).

## 6. Play path (after DHU green)

Declare Android Auto navigation in Play Console, add privacy policy covering
background location + Firebase trip sharing, complete Data Safety, attach DHU
video + test account, expect 1–3 week navigation-category review.
Keep "Open in Google Maps" fallback until approval lands.
