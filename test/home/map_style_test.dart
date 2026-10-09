import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';
import 'package:navora/features/home/widgets/map_fabs.dart';

void main() {
  testWidgets('map renders attribution + placeholder pin in test mode',
      (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [mapNativeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [Expanded(child: ConvoyMap()), MapFabs()],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('© OpenStreetMap'), findsOneWidget);
    expect(find.bySemanticsLabel('Trip destination'), findsOneWidget);
    expect(find.bySemanticsLabel('My location'), findsOneWidget);
  });
}
