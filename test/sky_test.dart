import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/prayer.dart';

void main() {
  testWidgets('sky golden', (t) async {
    t.view.physicalSize = const Size(800, 1300);
    t.view.devicePixelRatio = 2;
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Column(children: [
      SizedBox(width: 400, height: 300, child: CustomPaint(painter: SkyPainter(DateTime(2026, 11, 24, 17)))),
      SizedBox(width: 400, height: 300, child: CustomPaint(painter: SkyPainter(DateTime(2026, 11, 24, 11)))),
    ])));
    await expectLater(find.byType(Column), matchesGoldenFile('/tmp/sky.png'));
  });
  test('sunnah times between maghrib and fajr', () {
    final p = CalculationMethod.egyptian.getParameters();
    final pt = PrayerTimes(Coordinates(30.0444, 31.2357), DateComponents(2026, 11, 24), p, utcOffset: const Duration(hours: 2));
    final s = SunnahTimes(pt);
    expect(s.middleOfTheNight.isAfter(pt.maghrib), true);
    expect(s.lastThirdOfTheNight.isAfter(s.middleOfTheNight), true);
    print('MID ${s.middleOfTheNight} LAST ${s.lastThirdOfTheNight}');
  });
}
