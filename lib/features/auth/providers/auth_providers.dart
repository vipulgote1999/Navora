import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/auth_repository.dart';
import '../data/mock_auth_datasource.dart';

/// Default [AuthRepository]. Mock in-memory; a later plan swaps in Firebase.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final ds = MockAuthDataSource();
  ref.onDispose(ds.dispose);
  return ds;
});

/// Current signed-in user stream for Tasks 4-5 consumers.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchUser();
});
