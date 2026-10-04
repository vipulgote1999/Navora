import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripmesh/features/home/providers/map_ui_providers.dart';
import 'package:tripmesh/shared/models/trip.dart';

Trip _trip() => Trip(
      id: 't1',
      name: 'Pune Getaway',
      origin: 'A',
      destination: 'B',
      status: TripStatus.planning,
      hostUid: 'h',
      joinCode: 'ABC123',
      maxParticipants: 4,
    );

/// Mounts a [Consumer] on [container] and captures its [WidgetRef],
/// so the `WidgetRef`-typed helpers can be exercised in tests.
Future<WidgetRef> _widgetRef(WidgetTester t, ProviderContainer c) async {
  WidgetRef? captured;
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured!;
}

void main() {
  test('shareTextFor uses the exact spec format', () {
    expect(
      shareTextFor(_trip()),
      'Join my TripMesh trip "Pune Getaway" with code ABC123:\n'
      'navora://join/ABC123',
    );
  });

  testWidgets('toggleSavedTrip adds/removes and persists across loads',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ref = await _widgetRef(t, c);

    await loadSavedTripIds(ref);
    expect(c.read(savedTripIdsProvider), isEmpty);

    await toggleSavedTrip(ref, 't1');
    expect(c.read(savedTripIdsProvider), contains('t1'));

    // Fresh container sees the persisted value (survives restart).
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final ref2 = await _widgetRef(t, c2);
    await loadSavedTripIds(ref2);
    expect(c2.read(savedTripIdsProvider), contains('t1'));

    await toggleSavedTrip(ref2, 't1');
    expect(c2.read(savedTripIdsProvider), isNot(contains('t1')));

    // Third container reload proves the removal persisted (not just in-memory).
    final c3 = ProviderContainer();
    addTearDown(c3.dispose);
    final ref3 = await _widgetRef(t, c3);
    await loadSavedTripIds(ref3);
    expect(c3.read(savedTripIdsProvider), isNot(contains('t1')));
  });
}
