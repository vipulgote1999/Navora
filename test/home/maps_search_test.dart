import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmesh/features/home/widgets/assist_chips.dart';
import 'package:tripmesh/features/home/widgets/maps_search_bar.dart';

void main() {
  testWidgets('search bar has menu, mic, avatar semantics', (t) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MapsSearchBar(onMenuTap: () {})),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Open TripMesh menu'), findsOneWidget);
    expect(find.bySemanticsLabel('Search here'), findsOneWidget);
  });

  testWidgets('assist chips show Ask + ETA + filter', (t) async {
    await t.pumpWidget(
      ProviderScope(child: MaterialApp(home: Scaffold(body: AssistChips()))),
    );
    expect(find.textContaining('Ask TripMesh'), findsOneWidget);
    expect(find.textContaining('straight-line'), findsOneWidget);
  });
}
