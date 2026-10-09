import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';
import 'package:navora/features/home/widgets/map_fabs.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/trips/data/mock_trip_datasource.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';

void main() {
  testWidgets('map renders attribution + H marker + FABs', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [mapNativeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [Expanded(child: ConvoyMap()), MapFabs()],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('© OpenStreetMap'), findsOneWidget);
    expect(find.bySemanticsLabel('My location'), findsOneWidget);
    // Flush the attribution popup auto-hide timer so teardown is clean.
    await t.pump(const Duration(seconds: 6));
  });

  test('memberOffset is deterministic base + index * 0.002', () {
    final a = memberOffset('u1', 0);
    expect(a.latitude, defaultMapCenterLat);
    expect(a.longitude, defaultMapCenterLng);
    final b = memberOffset('u2', 3);
    expect(b.latitude, defaultMapCenterLat + 3 * 0.002);
    expect(b.longitude, defaultMapCenterLng + 3 * 0.002);
    expect(memberOffset('u1', 2), memberOffset('other', 2));
  });

  testWidgets('tapping destination marker sets selectedTripId', (t) async {
    final ds = MockTripDataSource();
    final trip = await ds.createTrip(
      name: 'Pune Run',
      origin: 'A',
      destination: 'B',
      hostUid: 'host1',
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(ds),
          mapNativeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: Scaffold(body: ConvoyMap())),
      ),
    );
    await t.pump(const Duration(seconds: 6));
    await t.tap(find.bySemanticsLabel('Trip destination'));
    await t.pump();
    final container = ProviderScope.containerOf(
      t.element(find.byType(ConvoyMap)),
    );
    expect(container.read(selectedTripIdProvider), trip.id);
  });

  testWidgets('location FAB is offline-safe, snackbar on denied', (t) async {
    await t.pumpWidget(
      ProviderScope(child: MaterialApp(home: Scaffold(body: MapFabs()))),
    );
    await t.tap(find.bySemanticsLabel('My location'));
    // Widget-test env has no geolocator plugin, so both permission checks
    // hang until MapFabs.locationTimeout (3s each) -> denied SnackBar.
    // Fake-async pumps advance the timeouts without real waiting.
    await t.pump();
    await t.pump(const Duration(seconds: 4));
    await t.pump(const Duration(seconds: 4));
    await t.pump();
    expect(
      find.text('Location off — showing trip area'),
      findsOneWidget,
    );
  });

  testWidgets('directions FAB starts in-app routing, never external', (t) async {
    await t.pumpWidget(
      ProviderScope(child: MaterialApp(home: Scaffold(body: MapFabs()))),
    );
    expect(find.bySemanticsLabel('Get directions'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Get directions'));
    await t.pump();
    final container =
        ProviderScope.containerOf(t.element(find.byType(MapFabs)));
    expect(container.read(navigatingProvider), isTrue);
    expect(
      container.read(routeDestinationProvider),
      const LatLng(defaultMapCenterLat, defaultMapCenterLng),
    );
    expect(t.takeException(), isNull);
  });

  group('drive control stack', () {
    Future<void> pumpGuiding(WidgetTester t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            navigatingProvider.overrideWith((ref) => true),
            mySpeedMpsProvider.overrideWith((ref) => 11.7),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: const Column(
                children: [Expanded(child: SizedBox()), NavSpeedPill()],
              ),
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('speed pill shows GPS speed while guiding', (t) async {
      await pumpGuiding(t);
      expect(find.text('42 km/h'), findsOneWidget);
    });

    testWidgets('stack has mute, compass, recenter; mic is parked',
        (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [navigatingProvider.overrideWith((ref) => true)],
          child: const MaterialApp(home: Scaffold(body: MapFabs())),
        ),
      );
      await t.pump();
      expect(find.bySemanticsLabel('Mute voice'), findsOneWidget);
      expect(find.bySemanticsLabel('Reset north'), findsOneWidget);
      expect(find.bySemanticsLabel('My location'), findsOneWidget);
      expect(
        find.byTooltip('Voice guidance coming soon'),
        findsOneWidget,
      );
    });

    testWidgets('sound tap toggles mute, compass tap bumps reset nonce',
        (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [navigatingProvider.overrideWith((ref) => true)],
          child: const MaterialApp(home: Scaffold(body: MapFabs())),
        ),
      );
      await t.pump();
      final container =
          ProviderScope.containerOf(t.element(find.byType(MapFabs)));
      await t.tap(find.bySemanticsLabel('Mute voice'));
      await t.pump();
      expect(container.read(mapMutedProvider), isTrue);
      expect(find.bySemanticsLabel('Unmute voice'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Reset north'));
      await t.pump();
      expect(container.read(compassResetNonceProvider), 1);
      expect(t.takeException(), isNull);
    });
  });
}
