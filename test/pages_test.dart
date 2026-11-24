import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/mushaf.dart';

void main() {
  test('604 pages cover all 6236 ayahs exactly once', () {
    final q = jsonDecode(File('assets/quran.json').readAsStringSync()) as List;
    PageData.debugLoad(jsonDecode(File('assets/pages.json').readAsStringSync()) as Map);
    var total = 0;
    final seen = <(int, int)>{};
    for (var p = 1; p <= 604; p++) {
      final a = PageData.ayahsOf(p, q);
      expect(a.isNotEmpty, true, reason: 'page $p');
      for (final e in a) {
        expect(seen.add(e), true, reason: 'dup $e');
      }
      total += a.length;
    }
    expect(total, 6236);
    expect(PageData.pageOf(1, 1), 1);
    expect(PageData.pageOf(3, 1), 50);
    expect(PageData.pageOf(114, 1), 604);
    expect(PageData.juzOf(1), 1);
    expect(PageData.juzOf(604), 30);
  });
}
