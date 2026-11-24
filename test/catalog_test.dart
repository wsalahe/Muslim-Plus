import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/main.dart';

void main() {
  final cat = jsonDecode(File('assets/catalog.json').readAsStringSync());
  test('catalog valid', () {
    expect(surahs.length, 114);
    expect((cat['sheikhs'] as List).length, 5);
    for (final s in cat['sheikhs']) {
      final keys = <String>{};
      for (final x in s['surahs']) {
        expect(x['n'], inInclusiveRange(1, 114));
        expect(x['url'], startsWith('https://github.com/wsalahe/Quran-kareem/releases/download/${s['id']}/'));
        expect(keys.add(keyOf(x)), true, reason: 'dup ${keyOf(x)}');
        expect(titleOf(x), contains('سورة'));
      }
    }
  });
  test('key and title', () {
    expect(keyOf({'n': 2, 'p': 3}), '002_p3');
    expect(keyOf({'n': 112, 'p': 0}), '112');
    expect(titleOf({'n': 112, 'p': 0}), 'سورة الإخلاص');
  });
}
