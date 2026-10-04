import 'dart:async';

import '../../../shared/repositories/auth_repository.dart';

/// In-memory [AuthRepository] for tests, demos, and mock mode.
/// No network calls. Google/Apple/email sign-ins all return a `mock-`
/// user; vehicle defaults (Car) live on [Member], applied at trip join.
class MockAuthDataSource implements AuthRepository {
  AppUser? _currentUser;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  void _setUser(AppUser user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final user = const AppUser(
      uid: 'mock-uid',
      email: 'mock@tripmesh.dev',
      displayName: 'Mock Rider',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AppUser> signInWithApple() async {
    final user = const AppUser(
      uid: 'mock-uid',
      email: 'mock@tripmesh.dev',
      displayName: 'Mock Rider',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final user = AppUser(
      uid: 'mock-uid',
      email: email,
      displayName: 'Mock Rider',
    );
    _setUser(user);
    return user;
  }

  @override
  Future<AppUser?> currentUser() async => _currentUser;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Stream<AppUser?> watchUser() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  void dispose() => _controller.close();
}
