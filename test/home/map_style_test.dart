import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/home/map/map_tiles.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';
import 'package:navora/features/home/widgets/convoy_map.dart';

void main() {
  testWidgets('convoy map uses dark tile URL when style is dark', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [mapStyleProvider.overrideWith((ref) => MapStyle.dark)],
      child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
    ));
    await t.pump();
    final tileLayer = t.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, contains('queeniemella'));
    // Flush POI debounce + attribution popup timers so teardown is clean.
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('convoy map uses satellite URL when style is satellite', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [mapStyleProvider.overrideWith((ref) => MapStyle.satellite)],
      child: const MaterialApp(home: Scaffold(body: ConvoyMap())),
    ));
    await t.pump();
    final tileLayer = t.widget<TileLayer>(find.byType(TileLayer));
    expect(tileLayer.urlTemplate, contains('arcgisonline'));
    // Flush POI debounce + attribution popup timers so teardown is clean.
    await t.pump(const Duration(seconds: 6));
  });
}
