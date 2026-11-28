import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/main.dart';
import 'package:quran_app/prayer.dart';
import 'package:quran_app/tasbih_heart.dart';

void main() {
  setUpAll(() async {
    final b = File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync();
    await ui.loadFontFromList(b, fontFamily: 'Amiri');
    await ui.loadFontFromList(b, fontFamily: 'Roboto');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.prefs = await SharedPreferences.getInstance();
  });

  testWidgets('tap counts and the chosen target drives progress', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(true), home: const TasbihPage()));
    await tester.pump(const Duration(milliseconds: 400));

    final heart = find.byType(TasbihHeart);
    expect(heart, findsOneWidget);
    expect(tester.widget<TasbihHeart>(heart).progress, 0);

    for (var i = 0; i < 3; i++) {
      await tester.tap(heart);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<TasbihHeart>(heart).count, 3);
    expect(tester.widget<TasbihHeart>(heart).target, 33);
    expect(tester.widget<TasbihHeart>(heart).progress, closeTo(3 / 33, 1e-9));

    // تغيير الهدف إلى ٩٩ يصفّر العدد ويبدأ التقدّم من جديد
    await tester.tap(find.text('٩٩'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<TasbihHeart>(heart).target, 99);
    expect(tester.widget<TasbihHeart>(heart).count, 0);

    await tester.tap(heart);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TasbihHeart>(heart).progress, closeTo(1 / 99, 1e-9));
  });
}
