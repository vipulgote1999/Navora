/// Minimal signed-in user. Plain Dart — no Firebase imports.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;

  const AppUser({required this.uid, this.email, this.displayName});
}

/// Auth operations. Mock + Firebase datasources implement this.
/// P0: Google/Apple/email only — no phone auth.
abstract class AuthRepository {
  Future<AppUser> signInWithGoogle();

  Future<AppUser> signInWithApple();

  Future<AppUser> signInWithEmail(String email, String password);

  Future<AppUser?> currentUser();

  Future<void> signOut();

  Stream<AppUser?> watchUser();
}
