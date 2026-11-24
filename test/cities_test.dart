import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/cities.dart';

void main() {
  final all = CityDb.parse(File('assets/cities.txt').readAsStringSync());
  test('city db loads and searches in Arabic and Latin', () {
    expect(all.length > 30000, true);
    final a = CityDb.search(all, 'المنصورة');
    expect(a.first.cc, 'EG');
    expect(a.first.name, 'Al Mansurah');
    expect(CityDb.search(all, 'Mansoura').any((c) => c.cc == 'EG' && c.name == 'Al Mansurah'), true);
    expect(CityDb.search(all, 'cairo').first.cc, 'EG');
    expect(CityDb.search(all, 'الرياض').first.cc, 'SA');
    expect(CityDb.search(all, 'a'), isEmpty);
  });
  test('nearest and method by country', () {
    final c = CityDb.nearest(all, 31.0364, 31.3807)!;
    expect(c.name, 'Al Mansurah');
    expect(methodForCountry('EG'), 'egy');
    expect(methodForCountry('SA'), 'umm');
    expect(methodForCountry('FR'), 'mwl');
    expect(CityDb.nearest(all, 0, -30), isNull);
  });
}
