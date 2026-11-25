import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n_en.dart';
import 'l10n_data.dart';

/// اللغات المدعومة: رمز اللغة واسمها بلغتها.
const List<(String, String)> kLangs = [
  ('ar', 'العربية'),
  ('en', 'English'),
  ('fr', 'Français'),
  ('ru', 'Русский'),
  ('it', 'Italiano'),
  ('zh', '中文'),
  ('ko', '한국어'),
  ('ja', '日本語'),
];

/// تفضيل اللغة (الافتراضي العربية).
final ValueNotifier<String> langPref = ValueNotifier<String>('ar');

Future<void> loadLang() async {
  final p = await SharedPreferences.getInstance();
  final v = p.getString('lang');
  langPref.value = kLangs.any((e) => e.$1 == v) ? v! : 'ar';
}

Future<void> setLang(String v) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('lang', v);
  langPref.value = v;
}

/// اللغة الفعلية.
String get lang => langPref.value;

/// صحيح لأي لغة غير العربية: أرقام لاتينية واتجاه من اليسار لليمين.
bool get isEn => lang != 'ar';

final Map<String, List<(RegExp, String)>> _tpl = {};

String? _lookup(String s) => lang == 'en' ? kEn[s] : (kDict[lang]?[s] ?? kEn[s]);

List<(RegExp, String)> _templates() {
  return _tpl[lang] ??= [
    for (final k in kEn.keys)
      if (k.contains('{}'))
        (RegExp('^${k.split('{}').map(RegExp.escape).join('(.*?)')}\$', dotAll: true), _lookup(k)!),
  ];
}

/// ترجمة نص واجهة (يعيد النص العربي كما هو إذا كانت اللغة عربية أو لا توجد ترجمة).
String tr(String s) {
  if (!isEn) return s;
  final d = _lookup(s);
  if (d != null) return d;
  for (final (re, t) in _templates()) {
    final m = re.firstMatch(s);
    if (m != null) {
      var out = t;
      for (var i = 0; i < m.groupCount; i++) {
        out = out.replaceAll('{$i}', tr(m.group(i + 1)!));
      }
      return out;
    }
  }
  return s;
}

/// اسم سورة.
String trs(String s) => !isEn ? s : (kSurahL[lang]?[s] ?? kSurahEn[s] ?? s);

/// اسم صلاة.
String trp(String s) => !isEn ? s : (kPrayerL[lang]?[s] ?? kPrayerEn[s] ?? s);
