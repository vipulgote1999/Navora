import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/auth/data/mock_auth_datasource.dart';
import 'package:navora/features/auth/providers/auth_providers.dart';
import 'package:navora/features/home/home_screen.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/trips/data/mock_trip_datasource.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';
import 'package:navora/shared/models/trip.dart';
import 'package:navora/shared/widgets/trip_card.dart';

final _sampleTrip = Trip(
  id: 'trip_1',
  name: 'Weekend Ride',
  origin: 'Pune',
  destination: 'Lonavala',
  status: TripStatus.planning,
  hostUid: 'mock-uid',
  joinCode: 'TRIP-AB12',
  maxParticipants: 8,
  createdAt: DateTime(2026, 10, 4),
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TripCard', () {
    testWidgets('shows name + date + destination + n/m + status', (tester) async {
      await tester.pumpWidget(
        _wrap(TripCard(trip: _sampleTrip, memberCount: 2)),
      );

      expect(find.text('Weekend Ride'), findsOneWidget);
      expect(find.text('2026-10-04'), findsOneWidget);
      expect(find.text('Lonavala'), findsOneWidget);
      expect(find.text('2/8'), findsOneWidget);
      expect(find.text('planning'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    testWidgets('shows Create/Join buttons + recent list', (tester) async {
      final trips = MockTripDataSource();
      await trips.createTrip(
        name: 'Weekend Ride',
        origin: 'Pune',
        destination: 'Lonavala',
        hostUid: 'mock-uid',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(trips),
            authRepositoryProvider.overrideWithValue(MockAuthDataSource()),
            mapNativeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      // Flush 5s attribution timer + OSM tile retries (pumpAndSettle never
      // settles: timer + tile retries keep scheduling frames).
      await tester.pump(const Duration(seconds: 6));

      // Maps-home shell: Create/Join live in the drawer; the recent list
      // shows in the vibe sheet (and the drawer once opened).
      expect(find.text('Weekend Ride'), findsWidgets);
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Create trip'), findsOneWidget);
      expect(find.text('Join trip'), findsOneWidget);
      expect(find.text('Weekend Ride'), findsWidgets);
    });
  });
}
