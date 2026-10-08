import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navora/core/utils/eta_label.dart';
import 'package:navora/features/home/providers/map_ui_providers.dart';

void main() {
  test('formatEtaLabel 15km gives straight-line label', () {
    expect(formatEtaLabel(15.0), '~15.0 km · ~30 min straight-line');
  });
  test('navIndex defaults to 0 Explore', () {
    final c = ProviderContainer();
    expect(c.read(navIndexProvider), 0);
  });
}
