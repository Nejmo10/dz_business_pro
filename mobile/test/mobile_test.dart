import 'package:flutter_test/flutter_test.dart';

import 'package:dz_business_mobile/l10n.dart';
import 'package:dz_business_mobile/ui_kit.dart';

void main() {
  test('Money formats centimes to DZD display exactly like the desktop', () {
    gAr = false;
    final pos = Money.fmt(12500000);
    expect(pos.endsWith(' DA'), true);
    expect(pos.replaceAll(RegExp(r'[\u00A0\u202F ]'), '').startsWith('125000'), true);
    expect(pos.contains(','), true);
    expect(Money.fmt(-500).startsWith('-'), true);
    expect(Money.fmt(0), '0,00 DA');
  });

  test('l10n covers both languages and falls back to the key', () {
    gAr = true;
    expect(t('tab.home'), 'الرئيسية');
    gAr = false;
    expect(t('tab.home'), 'Accueil');
    expect(t('missing.key'), 'missing.key');
  });

  test('every displayed method name key exists for all payment methods', () {
    for (final m in ['cash', 'card', 'transfer', 'partial', 'credit']) {
      gAr = true;
      expect(t('method.$m'), isNot('method.$m'), reason: m);
      gAr = false;
      expect(t('method.$m'), isNot('method.$m'), reason: m);
    }
  });
}
