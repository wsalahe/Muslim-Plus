import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/l10n.dart';
import 'package:quran_app/l10n_en.dart';
import 'package:quran_app/l10n_data.dart';

void main() {
  tearDown(() => langPref.value = 'ar');
  test('every language translates core strings, names and templates', () {
    for (final l in kLangs) {
      langPref.value = l.$1;
      if (l.$1 == 'ar') {
        expect(tr('الإعدادات'), 'الإعدادات');
        expect(trs('الإخلاص'), 'الإخلاص');
        continue;
      }
      expect(tr('الإعدادات').isNotEmpty, true);
      expect(tr('الإعدادات'), isNot('الإعدادات'), reason: l.$1);
      expect(trs('الإخلاص'), isNot('الإخلاص'), reason: l.$1);
      expect(trp('الفجر'), isNot('الفجر'), reason: l.$1);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(tr('سورة ${trs('الإخلاص')}')), false, reason: l.$1);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(tr('الإعدادات')), false, reason: l.$1);
    }
  });
  test('placeholders preserved in each dictionary', () {
    for (final e in kDict.entries) {
      for (final kv in e.value.entries) {
        final en = kEn[kv.key];
        if (en == null) continue;
        for (final ph in ['{0}', '{1}', '{2}']) {
          expect(kv.value.contains(ph), en.contains(ph), reason: '${e.key}: ${kv.key}');
        }
      }
    }
  });
  test('coverage of UI strings per language', () {
    for (final e in kDict.entries) {
      final missing = kEn.keys.where((k) => !e.value.containsKey(k)).length;
      // ignore: avoid_print
      print('${e.key}: ${kEn.length - missing}/${kEn.length}');
    }
    for (final l in ['ru', 'zh', 'ko', 'ja']) { expect(kSurahL[l]!.length, 114); }
  });
}
