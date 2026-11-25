import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n_en.dart';

/// تفضيل اللغة: system (لغة الجهاز) أو ar أو en.
final ValueNotifier<String> langPref = ValueNotifier<String>('system');

Future<void> loadLang() async {
  final p = await SharedPreferences.getInstance();
  langPref.value = p.getString('lang') ?? 'system';
}

Future<void> setLang(String v) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('lang', v);
  langPref.value = v;
}

/// اللغة الفعلية: ar أو en. «لغة الجهاز» تعطي en للإنجليزية وar لغيرها.
String get lang {
  final v = langPref.value;
  if (v == 'ar' || v == 'en') return v;
  return ui.PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'ar';
}

bool get isEn => lang == 'en';

List<(RegExp, String)>? _tpl;

List<(RegExp, String)> _templates() {
  return _tpl ??= [
    for (final e in kEn.entries)
      if (e.key.contains('{}'))
        (RegExp('^${e.key.split('{}').map(RegExp.escape).join('(.*?)')}\$', dotAll: true), e.value),
  ];
}

/// ترجمة نص واجهة (يعيد النص العربي كما هو إذا كانت اللغة عربية أو لا توجد ترجمة).
String tr(String s) {
  if (!isEn) return s;
  final d = kEn[s];
  if (d != null) return d;
  for (final (re, en) in _templates()) {
    final m = re.firstMatch(s);
    if (m != null) {
      var out = en;
      for (var i = 0; i < m.groupCount; i++) {
        out = out.replaceAll('{$i}', tr(m.group(i + 1)!));
      }
      return out;
    }
  }
  return s;
}

/// اسم سورة.
String trs(String s) => isEn ? (kSurahEn[s] ?? s) : s;

/// اسم صلاة.
String trp(String s) => isEn ? (kPrayerEn[s] ?? s) : s;
