import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/tasbih_garden.dart';

void main() {
  final stages = <(String, int, List<double>)>[
    ('seed', 0, const [0.4]),
    ('sprout', 30, const [0.2]),
    ('seedling', 100, const [0.7]),
    ('grass', 200, const [0.5]),
    ('young_tree', 400, const [0.6]),
    ('fruit_tree', 900, const [0.3]),
  ];

  for (final (name, life, drops) in stages) {
    testWidgets('garden stage $name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(child: TasbihGarden(lifetime: life, debugDrops: drops, showLabel: false)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1000));
      await expectLater(find.byType(TasbihGarden), matchesGoldenFile('goldens/garden_$name.png'));
    });
  }
}
