import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/map_fabs.dart';
import 'package:navora/features/home/widgets/nav_banner.dart';
import 'package:navora/features/home/widgets/trip_vibe_sheet.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/navigation/routing_repository.dart';

import 'drive_sim.dart';

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

LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );

void main() {
  testWidgets('simulated drive: banner follows, arrival ends guidance',
      (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          routingRepositoryProvider.overrideWithValue(_SimRepo(_route())),
          routeOriginProvider.overrideWith((ref) => _a),
          routeDestinationProvider.overrideWith((ref) => _c),
          navigatingProvider.overrideWith((ref) => true),
          mapFollowModeProvider.overrideWith((ref) => FollowMode.me),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const NavHeaderBanner(),
                Expanded(
                  child: TripVibeSheet(
                    controller: DraggableScrollableController(),
                  ),
                ),
                const NavSpeedPill(),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final container =
        ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));

    // At the origin the banner shows departure.
    await DriveSim.driveAlong(t, container, [_a]);
    expect(find.text('Head north'), findsWidgets);
    expect(find.text('43 km/h'), findsOneWidget);

    // Rolling toward the turn keeps departure until the turn is nearest.
    await DriveSim.driveAlong(t, container, [_lerp(_a, _b, 0.25)]);
    expect(find.text('Head north'), findsWidgets);

    // At the turn the banner advances.
    await DriveSim.driveAlong(t, container, [_b]);
    expect(find.text('Turn right onto MG Road'), findsWidgets);

    // Near the destination the banner shows arrival, still guiding.
    await DriveSim.driveAlong(t, container, [_lerp(_b, _c, 0.9)]);
    expect(container.read(navigatingProvider), isTrue);

    // On the destination: arrival asks confirmation, still guiding.
    await DriveSim.driveAlong(t, container, [_c]);
    expect(find.text("You've arrived"), findsOneWidget);
    expect(container.read(navigatingProvider), isTrue);
    // Confirming ends guidance with a notice.
    await t.tap(find.text('End navigation'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(container.read(navigatingProvider), isFalse);
    expect(find.text('Arrived at destination ✓'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('bearing helper points north/east', () {
    expect(
      DriveSim.bearingBetween(
          const LatLng(18.0, 73.0), const LatLng(19.0, 73.0)),
      closeTo(0, 0.5),
    );
    expect(
      DriveSim.bearingBetween(
          const LatLng(18.0, 73.0), const LatLng(18.0, 74.0)),
      closeTo(90, 0.5),
    );
  });
}
