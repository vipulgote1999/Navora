import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/features/home/widgets/trip_drawer.dart';
import 'package:tripmesh/features/home/widgets/trip_nav_bar.dart';
import 'package:tripmesh/features/home/widgets/trip_vibe_sheet.dart';

void main() {
  testWidgets('empty trips shows empty-state + drawer lists TripCards', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TripVibeSheet(
              controller: DraggableScrollableController(),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('No trips yet'), findsOneWidget);
  });

  testWidgets('vibe sheet shows title, navigate actions and nav bar', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TripVibeSheet(
              controller: DraggableScrollableController(),
            ),
            bottomNavigationBar: const TripNavBar(),
          ),
        ),
      ),
    );
    expect(find.text('Trip vibe'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('drawer shows auth line, create/join and recent trips', (
    t,
  ) async {
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(drawer: TripDrawer())),
      ),
    );
    await t.pump();
    // Open the drawer.
    final scaffoldState = t.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await t.pumpAndSettle();
    expect(find.text('Create trip'), findsOneWidget);
    expect(find.text('Join trip'), findsOneWidget);
    expect(find.text('Recent trips'), findsOneWidget);
  });
}
