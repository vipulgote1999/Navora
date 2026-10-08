import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/app.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';
import 'package:navora/features/home/widgets/maps_search_bar.dart';
import 'package:navora/features/home/widgets/trip_drawer.dart';
import 'package:navora/features/home/widgets/trip_nav_bar.dart';

void main() {
  testWidgets('shell stacks search over map with drawer + nav', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [mapNativeProvider.overrideWith((ref) => false)],
      child: NavoraApp(),
    ));
    expect(find.byType(ConvoyMap), findsOneWidget);
    expect(find.byType(MapsSearchBar), findsOneWidget);
    expect(find.byType(TripNavBar), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Open Navora menu'));
    await t.pumpAndSettle();
    expect(find.byType(TripDrawer), findsOneWidget);
    // Flush the attribution popup auto-hide timer so teardown is clean.
    await t.pump(const Duration(seconds: 6));
  });
}
