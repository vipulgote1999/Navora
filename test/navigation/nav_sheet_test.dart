import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/nav_banner.dart';
import 'package:navora/features/home/widgets/trip_vibe_sheet.dart';
import 'package:navora/features/navigation/route_models.dart';
import 'package:navora/features/navigation/route_providers.dart';
import 'package:navora/features/navigation/routing_repository.dart';

TripRoute sampleRoute() => const TripRoute(
      points: [
        LatLng(18.6545, 73.9412),
        LatLng(18.6580, 73.9450),
        LatLng(18.6645, 73.9512),
      ],
      distanceM: 2300.5,
      durationS: 320.0,
      steps: [
        RouteStep(
          instruction: 'Head north',
          maneuverType: 'depart',
          modifier: 'north',
          distanceM: 400,
          durationS: 60,
          location: LatLng(18.6545, 73.9412),
        ),
        RouteStep(
          instruction: 'Turn right onto MG Road',
          maneuverType: 'turn',
          modifier: 'right',
          distanceM: 1500,
          durationS: 200,
          location: LatLng(18.6580, 73.9450),
        ),
        RouteStep(
          instruction: 'Arrive at destination',
          maneuverType: 'arrive',
          modifier: '',
          distanceM: 0,
          durationS: 0,
          location: LatLng(18.6645, 73.9512),
        ),
      ],
    );

class FakeRoutingRepository extends RoutingRepository {
  int calls = 0;
  final TripRoute route;

  FakeRoutingRepository(this.route);

  @override
  Future<List<TripRoute>> fetchRoutes({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    http.Client? client,
  }) async {
    calls++;
    return [route];
  }

  @override
  Future<TripRoute?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
    http.Client? client,
  }) async {
    calls++;
    return route;
  }
}

Future<void> pumpSheet(
  WidgetTester t, {
  List<dynamic> overrides = const [],
}) async {
  await t.pumpWidget(
    ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: [...overrides],
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
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  group('route progress helpers', () {
    test('nearestStepIndex picks closest maneuver', () {
      final route = sampleRoute();
      expect(
        nearestStepIndex(route, const LatLng(18.6581, 73.9451)),
        1,
      );
      expect(
        nearestStepIndex(route, const LatLng(18.6545, 73.9412)),
        0,
      );
    });

    test('minDistanceToRouteM is zero on-route, large off-route', () {
      final route = sampleRoute();
      expect(
        minDistanceToRouteM(route, const LatLng(18.6580, 73.9450)),
        closeTo(0, 0.5),
      );
      expect(
        minDistanceToRouteM(route, const LatLng(19.0, 74.5)),
        greaterThan(50),
      );
    });
  });

  group('route section', () {
    testWidgets('shows directions entry, steps, and Start', (t) async {
      const origin = LatLng(18.6545, 73.9412);
      final fake = FakeRoutingRepository(sampleRoute());
      await pumpSheet(t, overrides: [
        routingRepositoryProvider.overrideWithValue(fake),
        routeOriginProvider.overrideWith((ref) => origin),
        routeDestinationProvider.overrideWith(
            (ref) => const LatLng(18.6645, 73.9512)),
        myPositionProvider.overrideWith((ref) => origin),
      ]);
      // Semantics node merges child text into the container label, so
      // match by pattern.
      expect(find.bySemanticsLabel(RegExp('Route details')), findsOneWidget);
      expect(find.text('Your location'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Turn right onto MG Road'), findsOneWidget);
      expect(find.text('Arrive at destination'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    });

    testWidgets('Start enables follow-me, End disables it', (t) async {
      final fake = FakeRoutingRepository(sampleRoute());
      await pumpSheet(t, overrides: [
        routingRepositoryProvider.overrideWithValue(fake),
        routeOriginProvider.overrideWith(
            (ref) => const LatLng(18.6545, 73.9412)),
        routeDestinationProvider.overrideWith(
            (ref) => const LatLng(18.6645, 73.9512)),
      ]);
      final container =
          ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));
      await t.tap(find.text('Start'));
      await t.pump();
      expect(container.read(navigatingProvider), isTrue);
      expect(container.read(mapFollowModeProvider), FollowMode.me);
      // ETA card: red long duration + distance · arrival, End control.
      expect(find.text('5 min'), findsOneWidget);
      expect(find.textContaining('2.3 km ·'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      await t.tap(find.text('End'));
      await t.pump();
      expect(container.read(navigatingProvider), isFalse);
      expect(container.read(mapFollowModeProvider), FollowMode.none);
    });

    testWidgets('null route shows no-route card with retry', (t) async {
      await pumpSheet(t, overrides: [
        routeProvider.overrideWith((ref) => Future.value(null)),
        // Explicit empty: never hit the real network in widget tests.
        routesProvider.overrideWith((ref) => Future.value(<TripRoute>[])),
        routeOriginProvider.overrideWith(
            (ref) => const LatLng(18.6545, 73.9412)),
        routeDestinationProvider.overrideWith(
            (ref) => const LatLng(18.6645, 73.9512)),
      ]);
      expect(
        find.text('No route found — check connection'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('no endpoints shows no route section', (t) async {
      await pumpSheet(t);
      expect(find.bySemanticsLabel('Route details'), findsNothing);
    });

    testWidgets('arrival stops navigation with notice', (t) async {
      final dest = const LatLng(18.6645, 73.9512);
      final fake = FakeRoutingRepository(sampleRoute());
      await pumpSheet(t, overrides: [
        routingRepositoryProvider.overrideWithValue(fake),
        routeOriginProvider.overrideWith(
            (ref) => const LatLng(18.6545, 73.9412)),
        routeDestinationProvider.overrideWith((ref) => dest),
        navigatingProvider.overrideWith((ref) => true),
      ]);
      final container =
          ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));
      container.read(myPositionProvider.notifier).state = dest;
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(container.read(navigatingProvider), isFalse);
      expect(find.text('Arrived at destination ✓'), findsOneWidget);
    });

    testWidgets('deviation refetches once per 10s', (t) async {
      final fake = FakeRoutingRepository(sampleRoute());
      await pumpSheet(t, overrides: [
        routingRepositoryProvider.overrideWithValue(fake),
        routeOriginProvider.overrideWith(
            (ref) => const LatLng(18.6545, 73.9412)),
        routeDestinationProvider.overrideWith(
            (ref) => const LatLng(18.6645, 73.9512)),
        navigatingProvider.overrideWith((ref) => true),
      ]);
      expect(fake.calls, 1);
      final container =
          ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));
      // ~7km off-route: triggers exactly one reroute.
      container.read(myPositionProvider.notifier).state =
          const LatLng(18.70, 74.00);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(fake.calls, 2);
      expect(container.read(lastRerouteAtProvider), isNotNull);
      // Still off-route but inside the throttle: no further fetch.
      container.read(myPositionProvider.notifier).state =
          const LatLng(18.71, 74.01);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(fake.calls, 2);
    });

    testWidgets('swap exchanges origin and destination', (t) async {
      const a = LatLng(18.65, 73.94);
      const b = LatLng(18.66, 73.95);
      final fake = FakeRoutingRepository(sampleRoute());
      await pumpSheet(t, overrides: [
        routingRepositoryProvider.overrideWithValue(fake),
        routeOriginProvider.overrideWith((ref) => a),
        routeDestinationProvider.overrideWith((ref) => b),
      ]);
      final container =
          ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));
      await t.tap(find.bySemanticsLabel('Swap origin and destination'));
      await t.pump();
      expect(container.read(routeOriginProvider), b);
      expect(container.read(routeDestinationProvider), a);
      expect(container.read(selectedRouteIndexProvider), 0);
    });

    testWidgets('alternate route cards switch selection', (t) async {
      const alt = TripRoute(
        points: [
          LatLng(18.6545, 73.9412),
          LatLng(18.6600, 73.9480),
          LatLng(18.6645, 73.9512),
        ],
        distanceM: 3100,
        durationS: 480,
        steps: [
          RouteStep(
            instruction: 'Head north',
            maneuverType: 'depart',
            modifier: 'north',
            distanceM: 400,
            durationS: 60,
            location: LatLng(18.6545, 73.9412),
          ),
          RouteStep(
            instruction: 'Turn left onto Nagar Road',
            maneuverType: 'turn',
            modifier: 'left',
            distanceM: 2000,
            durationS: 350,
            location: LatLng(18.6600, 73.9480),
          ),
          RouteStep(
            instruction: 'Arrive at destination',
            maneuverType: 'arrive',
            modifier: '',
            distanceM: 0,
            durationS: 0,
            location: LatLng(18.6645, 73.9512),
          ),
        ],
      );
      await pumpSheet(t, overrides: [
        routesProvider.overrideWith(
            (ref) => Future.value([sampleRoute(), alt])),
        routeOriginProvider.overrideWith(
            (ref) => const LatLng(18.6545, 73.9412)),
        routeDestinationProvider.overrideWith(
            (ref) => const LatLng(18.6645, 73.9512)),
      ]);
      expect(find.textContaining('via MG Road'), findsOneWidget);
      expect(find.textContaining('via Nagar Road'), findsOneWidget);
      final container =
          ProviderScope.containerOf(t.element(find.byType(TripVibeSheet)));
      await t.scrollUntilVisible(
        find.textContaining('via Nagar Road'),
        100,
      );
      await t.tap(find.textContaining('via Nagar Road'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(container.read(selectedRouteIndexProvider), 1);
      expect(find.text('Turn left onto Nagar Road'), findsOneWidget);
    });

    group('navigation header banner', () {
      Future<void> pumpBanner(
        WidgetTester t, {
        List<dynamic> overrides = const [],
      }) async {
        await t.pumpWidget(
          ProviderScope(
            // ignore: argument_type_not_assignable
            overrides: [...overrides],
            child: const MaterialApp(
              home: Scaffold(body: NavHeaderBanner()),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
      }

      testWidgets('shows next maneuver while navigating', (t) async {
        await pumpBanner(t, overrides: [
          routesProvider.overrideWith(
              (ref) => Future.value([sampleRoute()])),
          navigatingProvider.overrideWith((ref) => true),
          myPositionProvider.overrideWith(
              (ref) => const LatLng(18.6581, 73.9451)),
        ]);
        expect(find.text('Turn right onto MG Road'), findsOneWidget);
        expect(find.textContaining('In '), findsOneWidget);
      });

      testWidgets('hidden when not navigating', (t) async {
        await pumpBanner(t, overrides: [
          routesProvider.overrideWith(
              (ref) => Future.value([sampleRoute()])),
          myPositionProvider.overrideWith(
              (ref) => const LatLng(18.6581, 73.9451)),
        ]);
        expect(find.text('Turn right onto MG Road'), findsNothing);
        expect(find.textContaining('In '), findsNothing);
      });
    });
  });
}
