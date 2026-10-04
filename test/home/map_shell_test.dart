import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/app.dart';
import 'package:tripmesh/features/home/widgets/convoy_map.dart';
import 'package:tripmesh/features/home/widgets/maps_search_bar.dart';
import 'package:tripmesh/features/home/widgets/trip_drawer.dart';
import 'package:tripmesh/features/home/widgets/trip_nav_bar.dart';

void main() {
  testWidgets('shell stacks search over map with drawer + nav', (t) async {
    await t.pumpWidget(ProviderScope(child: TripMeshApp()));
    expect(find.byType(ConvoyMap), findsOneWidget);
    expect(find.byType(MapsSearchBar), findsOneWidget);
    expect(find.byType(TripNavBar), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Open TripMesh menu'));
    await t.pumpAndSettle();
    expect(find.byType(TripDrawer), findsOneWidget);
  });
}
