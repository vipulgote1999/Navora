import 'dart:math';

/// Join-code format shared by mocks, Firestore rules docs, and QR links.
/// Example: `TRIP-7K2Q`. Matches [Trip.joinCodePattern].
final RegExp joinCodePattern = RegExp(r'^TRIP-[A-Z0-9]{4}$');

/// Code prefix shown to users and encoded in deep links (`navora://join/<code>`).
const String joinCodePrefix = 'TRIP-';

/// Alphabet for the 4-char suffix: unambiguous uppercase + digits.
const String _suffixAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

final Random _defaultRandom = Random.secure();

/// Generates a random `TRIP-XXXX` join code.
///
/// Pass a seeded [Random] in tests for determinism.
String generateJoinCode([Random? random]) {
  final rng = random ?? _defaultRandom;
  final suffix = List.generate(
    4,
    (_) => _suffixAlphabet[rng.nextInt(_suffixAlphabet.length)],
  ).join();
  return '$joinCodePrefix$suffix';
}
