import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/widgets/nav_banner.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/navigation/routing_repository.dart';

RouteResult _testRoute() => RouteResult(
      points: <LatLng>[const LatLng(18.65, 73.94), const LatLng(18.52, 73.85)],
      distanceM: 2300,
      durationS: 600,
      maneuvers: const <RouteManeuver>[
        RouteManeuver(instruction: 'Head out', distanceM: 350, index: 0),
      ],
      engine: 'test',
    );

void main() {
  testWidgets('hidden without route, shows maneuver with route', (t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: NavBanner())),
      ),
    );
    expect(find.bySemanticsLabel('Current maneuver'), findsNothing);

    container.read(activeRouteProvider.notifier).state = _testRoute();
    await t.pump();
    expect(find.bySemanticsLabel('Current maneuver'), findsOneWidget);
    expect(find.text('Head out'), findsOneWidget);
    expect(find.text('2.3 km'), findsOneWidget);

    await t.tap(find.byTooltip('Clear route'));
    await t.pump();
    expect(find.bySemanticsLabel('Current maneuver'), findsNothing);
  });
}
