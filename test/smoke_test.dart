import 'package:flutter_test/flutter_test.dart';
import 'package:navora/core/config/app_config.dart';

void main() {
  test('app boots in mock mode', () {
    expect(AppConfig.mockMode, isTrue);
  });
}
