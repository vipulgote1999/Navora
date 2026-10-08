import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/widgets/trip_vibe_sheet.dart';
import 'package:navora/features/trips/data/mock_trip_datasource.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';
import 'package:navora/shared/models/trip.dart';

void main() {
  testWidgets('watchTrips stream emits new trip after createTrip', (t) async {
    final ds = MockTripDataSource();
    await t.pumpWidget(
      ProviderScope(
        overrides: [tripRepositoryProvider.overrideWithValue(ds)],
        child: MaterialApp(
          home: Scaffold(
            body: TripVibeSheet(
              controller: DraggableScrollableController(),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('No trips yet'), findsOneWidget);

    await ds.createTrip(
      name: 'Stream Trip',
      origin: 'A',
      destination: 'B',
      hostUid: 'host1',
    );
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // Title (focused trip) + TripCard in the list.
    expect(find.text('Stream Trip'), findsWidgets);
  });

  testWidgets('trips error shows retry that invalidates watchTrips', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          watchTripsProvider.overrideWith(
            (ref) => Stream<List<Trip>>.error(StateError('boom')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TripVibeSheet(
              controller: DraggableScrollableController(),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text("Couldn't load trips"), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
