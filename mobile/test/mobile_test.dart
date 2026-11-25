import 'package:flutter_test/flutter_test.dart';

import 'package:dz_business_mobile/l10n.dart';
import 'package:dz_business_mobile/pair_link.dart';
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

  test('PairLink parses the desktop QR payload (v1 with urls + business)', () {
    final link = PairLink.tryParse(
        '{"v":1,"n":"سوبرماركت النور","token":"482913",'
        '"urls":["http://192.168.1.10:8090","http://100.64.0.7:8090"]}');
    expect(link, isNotNull);
    expect(link!.token, '482913');
    expect(link.business, 'سوبرماركت النور');
    expect(link.hosts, ['192.168.1.10:8090', '100.64.0.7:8090']);
  });

  test('PairLink supports legacy payload, bare token, and rejects junk', () {
    final legacy = PairLink.tryParse('{"url":"http://10.0.2.2:8090/","token":"654321"}');
    expect(legacy!.hosts, ['10.0.2.2:8090']);
    expect(legacy.business, '');

    final bare = PairLink.tryParse('123456');
    expect(bare!.token, '123456');
    expect(bare.hosts, isEmpty);

    expect(PairLink.tryParse('https://example.com/other'), isNull);
    expect(PairLink.tryParse('{"url":"x","token":"12ab56"}'), isNull);
    expect(PairLink.tryParse('not json {'), isNull);
    expect(PairLink.tryParse(''), isNull);
  });

  test('new pair/scan l10n keys exist in both languages', () {
    for (final k in ['pair.scan', 'pair.manual', 'scan.title', 'scan.hint', 'scan.bad']) {
      gAr = true;
      expect(t(k), isNot(k), reason: k);
      gAr = false;
      expect(t(k), isNot(k), reason: k);
    }
  });
}
