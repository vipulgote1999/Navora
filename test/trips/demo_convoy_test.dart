import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navora/features/trips/data/demo_convoy_repository.dart';
import 'package:navora/shared/models/live_position.dart';

const _a = LatLng(18.6545, 73.9412);
const _b = LatLng(18.6580, 73.9450);
const _c = LatLng(18.6645, 73.9512);

void main() {
  group('DemoConvoyRepository', () {
    test('members are Abhi, Bapu and Me with display names', () {
      final repo = DemoConvoyRepository(tripId: 'demo-trip', routePoints: const [_a, _b, _c]);
      final members = repo.membersFor('demo-trip');
      expect(members.map((m) => m.displayName),
          containsAll(['Abhi', 'Bapu', 'Me']));
      expect(members, hasLength(3));
      repo.dispose();
    });

    test('pacers advance along the route and arrive', () {
      final repo = DemoConvoyRepository(tripId: 'demo-trip', routePoints: const [_a, _b, _c]);
      final start = repo.positionsAt(0);
      final abhi0 = start.firstWhere((p) => p.uid == 'abhi');
      final bapu0 = start.firstWhere((p) => p.uid == 'bapu');
      // Abhi starts ahead of Bapu.
      final total = const Distance()
          .as(LengthUnit.Meter, _a, _c);
      double progress(LivePosition p) => const Distance()
          .as(LengthUnit.Meter, _a, LatLng(p.lat, p.lng)) / total;
      expect(progress(abhi0), greaterThan(progress(bapu0)));

      final late = repo.positionsAt(3600);
      for (final p in late) {
        expect(p.status, 'arrived');
        expect(p.lat, closeTo(_c.latitude, 0.001));
        expect(p.lng, closeTo(_c.longitude, 0.001));
      }
      repo.dispose();
    });

    test('watchLive yields empty pre-start then pacer fixes', () async {
      final repo = DemoConvoyRepository(tripId: 'demo-trip', routePoints: const [_a, _b, _c]);
      final events = await repo.watchLive('demo-trip').take(2).toList();
      expect(events.first, isEmpty);
      expect(events[1].map((p) => p.uid), containsAll(['abhi', 'bapu']));
      expect(
        events[1].every((p) =>
            DateTime.now().difference(p.updatedAt).inSeconds.abs() < 30),
        isTrue,
      );
      repo.dispose();
    });
  });
}
