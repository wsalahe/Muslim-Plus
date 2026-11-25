import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('100 reciters, https mp3 servers, unique ids', () {
    final l = jsonDecode(File('assets/reciters.json').readAsStringSync()) as List;
    expect(l.length, 100);
    expect(l.map((e) => e['id']).toSet().length, 100);
    for (final e in l) {
      expect((e['server'] as String).startsWith('https://'), true);
      expect((e['server'] as String).endsWith('/'), true);
      expect((e['name'] as String).isNotEmpty, true);
    }
  });
}
