import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/features/home/widgets/convoy_map.dart';
import 'package:tripmesh/features/home/widgets/map_fabs.dart';
import 'package:tripmesh/features/trips/data/mock_trip_datasource.dart';
import 'package:tripmesh/features/trips/providers/trip_providers.dart';

void main() {
  testWidgets('map renders attribution + H marker + FABs', (t) async {
    await t.pumpWidget(
      ProviderScope(
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
        overrides: [tripRepositoryProvider.overrideWithValue(ds)],
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

  testWidgets('directions FAB does not crash offline', (t) async {
    await t.pumpWidget(
      ProviderScope(child: MaterialApp(home: Scaffold(body: MapFabs()))),
    );
    expect(find.bySemanticsLabel('Get directions'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Get directions'));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('first fix while following me runs auto-center', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [mapFollowModeProvider.overrideWith((ref) => FollowMode.me)],
        child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
      ),
    );
    await t.pump(const Duration(seconds: 6));
    ProviderScope.containerOf(
      t.element(find.byType(ConvoyMap)),
    ).read(myPositionProvider.notifier).state = const LatLng(18.52, 73.85);
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    expect(t.takeException(), isNull);
  });
}
