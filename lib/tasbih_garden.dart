import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'l10n.dart';

/// حديقة الذكر: قطرات ماء تسقي بذرة تنمو مع كثرة التسبيح:
/// بذرة ← برعم ← شتلة ← نجيلة ← شجرة صغيرة ← شجرة مثمرة.
/// كل شيء مرسوم محلياً (CustomPaint) بدون أصول أو إنترنت.
class TasbihGarden extends StatefulWidget {
  /// إجمالي التسبيحات تراكمياً (لا يتصفّر يومياً).
  final int lifetime;

  /// للاختبارات: تقدّم قطرات جاهزة (0..1) بدل مؤقّت داخلي.
  final List<double>? debugDrops;

  /// إظهار سطر اسم المرحلة تحت الرسم.
  final bool showLabel;

  const TasbihGarden({super.key, required this.lifetime, this.debugDrops, this.showLabel = true});

  @override
  State<TasbihGarden> createState() => TasbihGardenState();
}

class TasbihGardenState extends State<TasbihGarden> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<DateTime> _drops = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_tick);
  }

  void _tick() {
    final now = DateTime.now();
    _drops.removeWhere((t) => now.difference(t).inMilliseconds > 700);
    if (_drops.isEmpty) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else {
      setState(() {});
    }
  }

  /// إسقاط قطرة ماء (تُستدعى عند كل تسبيحة).
  void drop() {
    if (_drops.length >= 5) return;
    _drops.add(DateTime.now());
    if (!_ctrl.isAnimating) _ctrl.repeat();
    setState(() {});
  }

  List<double> get _progresses {
    if (widget.debugDrops != null) return widget.debugDrops!;
    final now = DateTime.now();
    return [for (final t in _drops) (now.difference(t).inMilliseconds / 650).clamp(0.0, 1.0)];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// النمو المستمر 0..5 حسب عتبات تراكمية.
  static double growthFor(int lifetime) {
    const stops = [0, 25, 75, 150, 300, 600];
    for (var i = 0; i < stops.length - 1; i++) {
      if (lifetime < stops[i + 1]) {
        return i + (lifetime - stops[i]) / (stops[i + 1] - stops[i]);
      }
    }
    return 5;
  }

  /// عدد الثمار على الشجرة.
  static int fruitCount(int lifetime) {
    if (lifetime < 450) return 0;
    return (((lifetime - 450) / 150).floor() + 1).clamp(0, 12);
  }

  static String stageName(double g) {
    if (g < 1) return tr('بذرة');
    if (g < 2) return tr('برعم');
    if (g < 3) return tr('شتلة');
    if (g < 4) return tr('نجيلة');
    if (g < 5) return tr('شجرة صغيرة');
    return tr('شجرة مثمرة');
  }

  @override
  Widget build(BuildContext context) {
    final g = growthFor(widget.lifetime);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: g),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, gv, _) => SizedBox(
          width: 260,
          height: 130,
          child: CustomPaint(painter: GardenPainter(gv, fruitCount(widget.lifetime), _progresses)),
        ),
      ),
      if (widget.showLabel)
        Text('${tr('حديقة ذكرك')}: ${stageName(g)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
    ]);
  }
}

class GardenPainter extends CustomPainter {
  final double g; // 0..5
  final int fruits;
  final List<double> drops; // 0..1

  GardenPainter(this.g, this.fruits, this.drops);

  static double _rand(int i) {
    final v = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  double _seg(double from, double to, double a, double b) {
    final t = ((g - from) / (to - from)).clamp(0.0, 1.0);
    return a + (b - a) * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final groundTop = h * 0.74;
    final cx = w / 2;

    // الأرض
    canvas.drawRect(Rect.fromLTWH(0, groundTop, w, h - groundTop), Paint()..color = const Color(0xFF6D4C41));

    // اخضرار الأرض والنجيلة
    final grassF = _seg(2.2, 3.5, 0, 1);
    if (grassF > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, groundTop, w, (h - groundTop) * 0.4),
        Paint()..color = Color.lerp(const Color(0xFF6D4C41), const Color(0xFF2E7D32), grassF)!,
      );
      final blade = Paint()
        ..color = const Color(0xFF43A047)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final n = (26 * grassF).round();
      for (var i = 0; i < n; i++) {
        final x = w * _rand(i);
        final bh = 5 + 8 * _rand(i + 100);
        final lean = (_rand(i + 200) - .5) * 6;
        canvas.drawLine(Offset(x, groundTop), Offset(x + lean, groundTop - bh), blade);
      }
    }

    // النبتة: ارتفاع الساق عبر المراحل
    final stemH = g < 1
        ? _seg(0, 1, 0, 10)
        : g < 2
            ? _seg(1, 2, 10, 28)
            : g < 3
                ? _seg(2, 3, 28, 42)
                : g < 4
                    ? _seg(3, 4, 42, 70)
                    : _seg(4, 5, 70, 86);
    final base = Offset(cx, groundTop + 4);

    // البذرة (تختفي تدريجياً بعد الإنبات)
    if (g < 1.2) {
      final seedP = Paint()..color = Color.lerp(const Color(0xFF4E342E), const Color(0xFF4E342E), 1)!.withValues(alpha: (1.2 - g).clamp(0.0, 1.0));
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, groundTop + 8), width: 10, height: 7), seedP);
    }

    // الساق
    if (stemH > 1) {
      final stemTop = Offset(cx, base.dy - stemH);
      final isTree = g > 3;
      canvas.drawLine(
        base,
        stemTop,
        Paint()
          ..color = isTree ? const Color(0xFF5D4037) : const Color(0xFF388E3C)
          ..strokeWidth = isTree ? _seg(3, 5, 3, 6.5) : 3
          ..strokeCap = StrokeCap.round,
      );

      // الأوراق
      final leafF = _seg(0.6, 2, 0, 1);
      if (leafF > 0 && !isTree) {
        final leafP = Paint()..color = const Color(0xFF43A047);
        final ly = base.dy - stemH * 0.55;
        final ls = 7 * leafF;
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - ls, ly), width: ls * 2, height: ls), leafP);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + ls, ly - 4), width: ls * 2, height: ls), leafP);
      }

      // التاج والثمار
      if (isTree) {
        final canopyR = _seg(3, 5, 10, 34);
        final cy = base.dy - stemH - canopyR * 0.35;
        final canopyP = Paint()..color = const Color(0xFF2E7D32);
        canvas.drawCircle(Offset(cx, cy), canopyR, canopyP);
        canvas.drawCircle(Offset(cx - canopyR * 0.7, cy + canopyR * 0.3), canopyR * 0.65, canopyP);
        canvas.drawCircle(Offset(cx + canopyR * 0.7, cy + canopyR * 0.3), canopyR * 0.65, canopyP);
        final fruitP = Paint()..color = const Color(0xFFFFB300);
        for (var i = 0; i < fruits; i++) {
          final ang = _rand(i + 300) * 2 * math.pi;
          final rr = canopyR * (0.45 + 0.5 * _rand(i + 400));
          canvas.drawCircle(Offset(cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.8), 3.2, fruitP);
        }
      }
    }

    // قطرات الماء
    for (final p in drops) {
      final t = p.clamp(0.0, 1.0);
      final y = 6 + (groundTop - 12) * t;
      final x = cx + 10 * math.sin(t * 9);
      final alpha = (1 - t * 0.35).clamp(0.0, 1.0);
      final dropP = Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 4, dropP);
      canvas.drawLine(Offset(x, y - 8), Offset(x, y - 2), Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: alpha * 0.6)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
      // رذاذ عند الارتطام
      if (t > 0.92) {
        final splashP = Paint()..color = const Color(0xFF81D4FA).withValues(alpha: (1 - t) * 8);
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, groundTop + 2), radius: 8), math.pi, math.pi, false, splashP..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(GardenPainter old) => true;
}
