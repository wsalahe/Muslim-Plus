import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/extras.dart';
import 'package:quran_app/prayer.dart';

void main() {
  test('zakat: below and above nisab', () {
    final a = computeZakat(cash: 1000, goldGrams: 0, goldPrice: 100, silverGrams: 0, silverPrice: 1, trade: 0, debts: 0, silverNisab: false);
    expect(a.due, false);
    final b = computeZakat(cash: 10000, goldGrams: 0, goldPrice: 100, silverGrams: 0, silverPrice: 1, trade: 0, debts: 0, silverNisab: false);
    expect(b.due, true);
    expect(b.zakat, closeTo(250, 1e-9));
    final c = computeZakat(cash: 10000, goldGrams: 0, goldPrice: 100, silverGrams: 0, silverPrice: 1, trade: 0, debts: 5000, silverNisab: false);
    expect(c.due, false);
  });
  test('no duplicated bismillah inside first ayah; counts intact', () {
    final d = jsonDecode(File('assets/quran.json').readAsStringSync()) as List;
    expect(d.length, 114);
    expect(d.fold<int>(0, (a, s) => a + (s['a'] as List).length), 6236);
    for (final s in d) {
      final first = (s['a'] as List).first as String;
      if (s['n'] != 1) expect(first.contains('ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ') && first.startsWith('بِسْمِ'), false, reason: 'surah ${s['n']}');
    }
  });
  test('30 muezzins and raw files exist', () {
    expect(kMuezzins.length, 30);
    for (var i = 1; i <= 30; i++) {
      expect(File('android/app/src/main/res/raw/a${i.toString().padLeft(2, '0')}.mp3').existsSync(), true);
    }
  });
}
