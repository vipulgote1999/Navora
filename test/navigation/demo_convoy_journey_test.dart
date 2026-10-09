import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/widgets/trip_vibe_sheet.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/navigation/routing_repository.dart';
import 'package:navora/features/trips/data/demo_convoy_repository.dart';
import 'package:navora/features/trips/providers/trip_providers.dart';


const _a = LatLng(18.6545, 73.9412);
const _b = LatLng(18.6580, 73.9450);
const _c = LatLng(18.6645, 73.9512);

TripRoute _route() => const TripRoute(
      points: [_a, _b, _c],
      distanceM: 2300.5,
      durationS: 320.0,
      steps: [
        RouteStep(
          instruction: 'Head north',
          maneuverType: 'depart',
          modifier: '',
          distanceM: 400,
          durationS: 60,
          location: _a,
        ),
        RouteStep(
          instruction: 'Turn right onto MG Road',
          maneuverType: 'turn',
          modifier: 'right',
          distanceM: 1500,
          durationS: 200,
          location: _b,
        ),
        RouteStep(
          instruction: 'Arrive at destination',
          maneuverType: 'arrive',
          modifier: '',
          distanceM: 0,
          durationS: 0,
          location: _c,
        ),
      ],
    );

class _SimRepo extends RoutingRepository {
  final TripRoute route;
  _SimRepo(this.route);

  @override
  Future<List<TripRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    http.Client? client,
  }) async =>
      [route];
}

void main() {
  testWidgets('demo convoy journey: pacers glide, chips tick, exit cleans up',
      (t) async {
    final fake = _SimRepo(_route());
    final sheet = DraggableScrollableController();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          routingRepositoryProvider.overrideWithValue(fake),
          routeOriginProvider.overrideWith(
              (ref) => const LatLng(18.6545, 73.9412)),
          routeDestinationProvider.overrideWith(
              (ref) => const LatLng(18.6645, 73.9512)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TripVibeSheet(controller: sheet),
          ),
        ),
      ),
    );
    await t.pump();
    // Expand the sheet so the explore-row controls are hittable.
    sheet.animateTo(0.75, duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut);
    await t.pumpAndSettle();
    final container =
        ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));

    // 1. Launch the demo convoy from the explore row.
    await t.tap(find.text('Demo convoy'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(container.read(navigatingProvider), isTrue);
    final demo = container.read(demoRepositoryProvider);
    expect(demo, isNotNull);

    // 2. Pacers move: two ticks of route progress, chips stay visible.
    container.listen(livePositionsProvider(demoTripId), (_, _) {});
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    final first = container.read(livePositionsProvider(demoTripId)).value!;
    await t.pump(const Duration(seconds: 2));
    final second = container.read(livePositionsProvider(demoTripId)).value!;
    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    final moved = first.indexWhere((p) => p.uid == 'abhi');
    expect(moved, greaterThanOrEqualTo(0));
    // Progress grows (or arrives) between ticks.
    final advanced = second[moved].lat != first[moved].lat ||
        second[moved].status != first[moved].status;
    expect(advanced, isTrue);
    expect(find.textContaining('Abhi ·'), findsOneWidget);
    expect(find.textContaining('Bapu ·'), findsOneWidget);

    // 3. Exit: End disposes the demo, stops ticks, restores explore.
    await t.tap(find.text('End'));
    await t.pump();
    expect(container.read(navigatingProvider), isFalse);
    expect(container.read(demoRepositoryProvider), isNull);
    expect(find.textContaining('Abhi ·'), findsNothing);

    // 4. No residue: pacer positions stop advancing after exit.
    final frozen =
        container.read(livePositionsProvider(demoTripId)).value;
    await t.pump(const Duration(seconds: 2));
    expect(
      container.read(livePositionsProvider(demoTripId)).value,
      frozen,
    );
    expect(t.takeException(), isNull);
  });
}
