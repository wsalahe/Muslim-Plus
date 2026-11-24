import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/prayer.dart';

void main() {
  test('guessMethod by region', () {
    expect(guessMethod(30.04, 31.23), 'egy');
    expect(guessMethod(21.42, 39.82), 'umm');
    expect(guessMethod(25.2, 55.27), 'dxb');
    expect(guessMethod(29.37, 47.98), 'kwt');
    expect(guessMethod(41.0, 28.9), 'tur');
    expect(guessMethod(24.8, 67.0), 'khi');
    expect(guessMethod(40.7, -74), 'isna');
    expect(guessMethod(48.8, 2.3), 'mwl');
  });
  test('Cairo egyptian times plausible', () {
    final p = CalculationMethod.egyptian.getParameters();
    final t = PrayerTimes(Coordinates(30.0444, 31.2357), DateComponents(2026, 11, 24), p, utcOffset: const Duration(hours: 2));
    print('CAIRO ${t.fajr} ${t.dhuhr} ${t.asr} ${t.maghrib} ${t.isha}');
    expect(t.fajr.isBefore(t.dhuhr), true);
    expect(t.maghrib.hour, inInclusiveRange(16, 17));
  });
}
