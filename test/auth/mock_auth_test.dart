import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/features/auth/data/mock_auth_datasource.dart';
import 'package:navora/features/auth/providers/auth_providers.dart';
import 'package:navora/shared/repositories/auth_repository.dart';

void main() {
  group('MockAuthDataSource', () {
    test('google sign-in returns mock user', () async {
      final repo = MockAuthDataSource();
      final u = await repo.signInWithGoogle();
      expect(u.uid, startsWith('mock-'));
    });

    test('sign-out clears state', () async {
      final repo = MockAuthDataSource();
      await repo.signInWithGoogle();
      await repo.signOut();
      expect(await repo.currentUser(), isNull);
    });

    test('apple sign-in returns mock user', () async {
      final repo = MockAuthDataSource();
      final u = await repo.signInWithApple();
      expect(u.uid, startsWith('mock-'));
    });

    test('email sign-in returns mock user with given email', () async {
      final repo = MockAuthDataSource();
      final u = await repo.signInWithEmail('rider@navora.dev', 'secret');
      expect(u.uid, startsWith('mock-'));
      expect(u.email, 'rider@navora.dev');
    });

    test('watchUser emits signed-in user then null after sign-out',
        () async {
      final repo = MockAuthDataSource();
      final emissions = <AppUser?>[];
      final sub = repo.watchUser().listen(emissions.add);
      await Future<void>.delayed(Duration.zero); // initial null
      await repo.signInWithGoogle();
      await Future<void>.delayed(Duration.zero); // signed-in user
      await repo.signOut();
      await Future<void>.delayed(Duration.zero); // signed-out null
      await sub.cancel();
      expect(emissions.length, 3);
      expect(emissions[0], isNull);
      expect(emissions[1], isA<AppUser>());
      expect(emissions[2], isNull);
    });

    test('authRepositoryProvider defaults to MockAuthDataSource', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(authRepositoryProvider),
          isA<MockAuthDataSource>());
    });
  });
}
