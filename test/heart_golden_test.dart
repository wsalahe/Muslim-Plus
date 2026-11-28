import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/tasbih_heart.dart';

Future<void> _loadFonts() async {
  final bytes = File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync();
  await ui.loadFontFromList(bytes, fontFamily: 'Amiri');
  await ui.loadFontFromList(bytes, fontFamily: 'Roboto');
}

void main() {
  setUpAll(_loadFonts);

  final stages = <(String, double, int)>[
    ('stone', 0.0, 0),
    ('vessels', 0.20, 7),
    ('upper', 0.38, 13),
    ('half', 0.55, 18),
    ('body', 0.78, 26),
    ('alive', 1.0, 33),
  ];

  for (final (name, p, c) in stages) {
    testWidgets('heart stage $name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0D10),
          body: Center(
            child: SizedBox(
              width: 360,
              child: TasbihHeart(
                progress: p,
                dhikr: 'أستغفر الله',
                count: c,
                target: 33,
                debugDrops: const [],
                debugBeat: 0,
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await expectLater(find.byType(TasbihHeart), matchesGoldenFile('goldens/heart_$name.png'));
    });
  }
}
