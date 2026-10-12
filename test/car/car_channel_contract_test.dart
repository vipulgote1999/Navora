import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/car/car_channel.dart';
import 'package:navora/features/car/car_navigation_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CarNavigationSnapshot contract (must match CarBridge.kt / CarNavState.kt)', () {
    test('channel + keys stay in sync with native', () {
      expect(CarNavigationSnapshot.channelName, 'navora/car');
      expect(CarChannel.methodUpdate, 'updateNavigation');
      expect(CarChannel.methodClear, 'clearNavigation');
      expect(CarChannel.methodTrips, 'updateTrips');
      expect(CarNavigationSnapshot.keyDestination, 'destination');
      expect(CarNavigationSnapshot.keyDistanceM, 'distanceM');
      expect(CarNavigationSnapshot.keyDurationS, 'durationS');
    });

    test('rejects empty destination and negative values', () {
      expect(
        const CarNavigationSnapshot(
          destination: '  ', distanceM: 10, durationS: 5).isValid,
        isFalse);
      expect(
        const CarNavigationSnapshot(
          destination: 'Wagholi', distanceM: -1, durationS: 5).isValid,
        isFalse);
      expect(
        const CarNavigationSnapshot(
          destination: 'Wagholi', distanceM: 10, durationS: -2).isValid,
        isFalse);
      expect(
        const CarNavigationSnapshot(
          destination: 'Wagholi', distanceM: 8200, durationS: 720).isValid,
        isTrue);
    });

    test('truncates to car limits (40 title / 120 text / clamp range)', () {
      final long = List.filled(200, 'A').join();
      final s = CarNavigationSnapshot(
        destination: long, maneuverText: long, road: long,
        distanceM: 1e12, durationS: 1 << 30, stepM: -0.0);
      final map = s.toMap();
      expect((map['destination'] as String).length,
          CarNavigationSnapshot.maxTitleChars);
      expect((map['maneuverText'] as String).length,
          CarNavigationSnapshot.maxTextChars);
      expect((map['road'] as String).length,
          CarNavigationSnapshot.maxTitleChars);
      expect((map['distanceM'] as num).toDouble() <= 9999999, isTrue);
      expect((map['durationS'] as num).toInt() <= 99999, isTrue);
    });

    test('sanitizeTitles mirrors native: trim, drop empty, dedupe, cap 6', () {
      final out = CarNavigationSnapshot.sanitizeTitles([
        '  Weekend Convoy  ', '', '   ', 'Weekend Convoy',
        'Bhosari Demo', 'Airport Run', 'Trip 4', 'Trip 5', 'Trip 6', 'Trip 7',
        'A very long trip title that definitely exceeds forty characters limit here',
      ]);
      expect(out.length, CarNavigationSnapshot.maxTrips);
      expect(out.first, 'Weekend Convoy');
      expect(out.contains(''), isFalse);
      expect(out.toSet().length, out.length);
      expect(out.every((t) => t.length <= CarNavigationSnapshot.maxTitleChars), isTrue);
    });
  });

  group('CarChannel method calls', () {
    const channelName = 'navora/car';
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async {
          calls.add(call);
          return true;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
    });

    test('updateNavigation sends snapshot map and returns true', () async {
      final ch = CarChannel();
      final ok = await ch.updateNavigation(const CarNavigationSnapshot(
        destination: 'Wagholi, Pune',
        maneuverText: 'Head north toward Nagar Road',
        road: 'Nagar Road',
        distanceM: 8200,
        durationS: 720,
        stepM: 350,
      ));
      expect(ok, isTrue);
      expect(calls.single.method, 'updateNavigation');
      final args = calls.single.arguments as Map;
      expect(args['destination'], 'Wagholi, Pune');
      expect(args['distanceM'], 8200);
    });

    test('updateNavigation short-circuits invalid snapshots (no platform call)', () async {
      final ch = CarChannel();
      final ok = await ch.updateNavigation(const CarNavigationSnapshot(
        destination: '', distanceM: 0, durationS: 0));
      expect(ok, isFalse);
      expect(calls, isEmpty);
    });

    test('updateTrips sanitizes before sending', () async {
      final ch = CarChannel();
      final ok = await ch.updateTrips([' A ', '', 'A', 'B']);
      expect(ok, isTrue);
      final args = calls.single.arguments as Map;
      expect(args['titles'], ['A', 'B']);
    });

    test('returns false when no host (MissingPluginException)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
      final ch = CarChannel();
      // No handler + no native host: invokeMethod throws MissingPluginException
      // on the test binding; wrapper must map it to false, not throw.
      final ok = await ch.updateTrips(['x']);
      expect(ok, isFalse);
    });
  });
}
