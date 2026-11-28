import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';

/// زوج صور القلب (حجر متشقّق + قلب حيّ بنفس الحدود) إن وُجد في الأصول.
/// إن لم يوجد يُرسم القلب بالمتجهات بنفس الشكل، فلا يتعطّل شيء.
class HeartArt {
  static ui.Image? charcoal;
  static ui.Image? living;
  static bool _tried = false;

  static bool get available => charcoal != null && living != null;

  static Future<void> ensure() async {
    if (_tried) return;
    _tried = true;
    try {
      final a = await rootBundle.load('assets/heart/charcoal.webp');
      final b = await rootBundle.load('assets/heart/living.webp');
      charcoal = await decodeImageFromList(a.buffer.asUint8List());
      living = await decodeImageFromList(b.buffer.asUint8List());
    } catch (_) {}
  }
}

/// ذهب التطبيق (نسخة محلية لتجنّب دورة الاستيراد).
const _gold = Color(0xFFD4AF37);

String _digits(int n) => isEn
    ? n.toString()
    : n.toString().split('').map((d) => d == '-' ? d : String.fromCharCode(0x660 + int.parse(d))).join();

/// قلب الذكر: قلب من حجر أسود متشقّق يتفتّت ويحيا قطعةً قطعة
/// بقدر ما تُتمّ من الذكر حتى الهدف المختار (٣٣ / ٩٩ / ١٠٠ / مفتوح).
/// الرسم كله محلي بـ CustomPaint: بلا أصول ولا إنترنت ولا زيادة في الحجم.
/// في وضع السكون لا يعمل أي مؤقّت ولا إعادة رسم: الحركة تحدث عند اللمس فقط.
class TasbihHeart extends StatefulWidget {
  /// تقدّم الذكر 0..1 = العدد الحالي ÷ الهدف المختار.
  final double progress;
  final String dhikr;
  final int count;
  /// 0 = مفتوح (بلا هدف).
  final int target;
  /// للاختبارات: أعمار القطرات 0..1 بدل مؤقّت داخلي.
  final List<double>? debugDrops;
  /// للاختبارات: قيمة نبضة ثابتة بدل مؤقّت.
  final double? debugBeat;
  final bool showText;
  final VoidCallback? onTap;

  const TasbihHeart({
    super.key,
    required this.progress,
    required this.dhikr,
    required this.count,
    required this.target,
    this.debugDrops,
    this.debugBeat,
    this.showText = true,
    this.onTap,
  });

  @override
  State<TasbihHeart> createState() => TasbihHeartState();
}

class TasbihHeartState extends State<TasbihHeart> with TickerProviderStateMixin {
  late final AnimationController _drops;
  late final AnimationController _beat;
  final List<DateTime> _falling = [];

  @override
  void initState() {
    super.initState();
    _drops = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..addListener(_tick);
    _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..addListener(_tick);
    if (!HeartArt._tried) {
      HeartArt.ensure().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _tick() {
    if (widget.debugDrops != null) return;
    final now = DateTime.now();
    _falling.removeWhere((t) => now.difference(t).inMilliseconds > 950);
    if (_falling.isEmpty && _drops.isAnimating) _drops.stop();
    if (mounted) setState(() {});
  }

  /// نبضة قلب + خرزة تسقط (تُستدعى عند كل ذكر).
  void beat() {
    if (widget.debugDrops != null) return;
    if (_falling.length >= 6) _falling.removeAt(0);
    _falling.add(DateTime.now());
    _beat.forward(from: 0);
    if (!_drops.isAnimating) _drops.repeat();
    if (mounted) setState(() {});
  }

  List<double> get _ages {
    if (widget.debugDrops != null) return widget.debugDrops!;
    final now = DateTime.now();
    return [for (final t in _falling) (now.difference(t).inMilliseconds / 950).clamp(0.0, 1.0)];
  }

  double get _beatValue => widget.debugBeat ?? _beat.value;

  @override
  void dispose() {
    _drops.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
        aspectRatio: 0.84,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: RepaintBoundary(
            child: Stack(children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (c, v, _) => CustomPaint(
                    painter: HeartPainter(
                      progress: v,
                      drops: _ages,
                      beat: _beatValue,
                      dark: dark,
                      charcoal: HeartArt.charcoal,
                      living: HeartArt.living,
                    ),
                  ),
                ),
              ),
              if (widget.showText) ...[
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      tr('طهر قلبك'),
                      style: const TextStyle(fontFamily: 'Amiri', fontSize: 21, color: _gold, height: 1.2),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      widget.dhikr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Amiri', fontSize: 24, color: Colors.white, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text(_digits(widget.count), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 6),
                      Text(
                        widget.target == 0 ? tr('مفتوح') : '/ ${_digits(widget.target)}',
                        style: TextStyle(fontSize: 15, color: _gold.withValues(alpha: .9)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _Dashes(progress: widget.progress.clamp(0.0, 1.0), segments: widget.target == 0 ? 24 : (widget.target <= 40 ? widget.target : 20)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// شرطات التقدّم أسفل العداد.
class _Dashes extends StatelessWidget {
  final double progress;
  final int segments;
  const _Dashes({required this.progress, required this.segments});

  @override
  Widget build(BuildContext context) {
    final filled = (progress * segments).round().clamp(0, segments);
    return Row(children: [
      for (var i = 0; i < segments; i++)
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1.1),
            decoration: BoxDecoration(
              color: i < filled ? _gold : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
    ]);
  }
}

/// قلب مصغّر لبطاقات الأذكار: حجر يمتلئ حياةً من الأسفل بحسب التقدّم.
class HeartBadge extends StatelessWidget {
  final double progress;
  final double size;
  const HeartBadge({super.key, required this.progress, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (c, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: HeartBadgePainter(v)),
      ),
    );
  }
}

class HeartBadgePainter extends CustomPainter {
  final double progress;
  HeartBadgePainter(this.progress);

  static Path heartPath() => Path()
    ..moveTo(50, 89)
    ..cubicTo(12, 63, 8, 40, 22, 28)
    ..cubicTo(34, 17, 46, 24, 50, 34)
    ..cubicTo(54, 24, 66, 17, 78, 28)
    ..cubicTo(92, 40, 88, 63, 50, 89)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100.0;
    canvas.save();
    canvas.scale(k);
    final path = heartPath();
    canvas.drawPath(path, Paint()..color = const Color(0xFF2A2A2E));
    if (progress > 0) {
      canvas.save();
      canvas.clipPath(path);
      canvas.clipRect(Rect.fromLTRB(0, 100 - 100 * progress, 100, 100));
      final g = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2554A), Color(0xFF9E1B26)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
      canvas.drawPath(path, g);
      canvas.restore();
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF0E0E10));
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeartBadgePainter old) => old.progress != progress;
}

/// لوحة القلب: حجر متشقّق يتحوّل إلى قلب حيّ قطعةً قطعة بحسب التقدّم.
class HeartPainter extends CustomPainter {
  final double progress;
  final List<double> drops;
  final double beat;
  final bool dark;
  final ui.Image? charcoal;
  final ui.Image? living;

  HeartPainter({
    required this.progress,
    required this.drops,
    required this.beat,
    required this.dark,
    this.charcoal,
    this.living,
  });

  bool get hasArt => charcoal != null && living != null;

  static const double _unitW = 100.0;
  static const double _unitH = 122.0;

  // ---------------- الهندسة ----------------

  static List<Offset> _cubic(Offset a, Offset c1, Offset c2, Offset b, [int n = 14]) {
    final out = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n, u = 1 - t;
      out.add(a * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + b * (t * t * t));
    }
    return out;
  }

  static Path _tube(List<Offset> pts, double w) {
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      final prev = i == 0 ? pts.first : pts[i - 1];
      final next = i == pts.length - 1 ? pts.last : pts[i + 1];
      var d = next - prev;
      if (d.distance < 1e-6) d = const Offset(1, 0);
      final n = Offset(-d.dy, d.dx) / d.distance * (w / 2);
      left.add(pts[i] + n);
      right.add(pts[i] - n);
    }
    final p = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    for (final o in right.reversed) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    p.addOval(Rect.fromCircle(center: pts.first, radius: w / 2));
    p.addOval(Rect.fromCircle(center: pts.last, radius: w / 2));
    return p;
  }

  /// شكل بيضاوي بحافة متكسّرة كالصخر (حدود قطع القلب).
  static Path _blob(double cx, double cy, double rx, double ry, double deg, [int seed = 0]) {
    final a = deg * math.pi / 180, ca = math.cos(a), sa = math.sin(a);
    const n = 84;
    final p = Path();
    for (var i = 0; i <= n; i++) {
      final t = i / n * 2 * math.pi;
      final wob = 1 + .055 * (_rand(seed * 97 + (i % n)) - .5) * 2 + .03 * math.sin(t * 7 + seed);
      final x = rx * wob * math.cos(t), y = ry * wob * math.sin(t);
      final px = cx + x * ca - y * sa, py = cy + x * sa + y * ca;
      if (i == 0) {
        p.moveTo(px, py);
      } else {
        p.lineTo(px, py);
      }
    }
    p.close();
    return p;
  }

  static Path _aorta() {
    final pts = _cubic(const Offset(45, 60), const Offset(42, 47), const Offset(46, 36), const Offset(56, 34)) +
        _cubic(const Offset(56, 34), const Offset(63, 33), const Offset(66, 38), const Offset(65, 47));
    return _tube(pts, 10.5);
  }

  static Path _pulmonary() {
    final pts = _cubic(const Offset(40, 53), const Offset(37, 47), const Offset(40, 42), const Offset(47, 40)) +
        _cubic(const Offset(47, 40), const Offset(51, 39), const Offset(54, 39), const Offset(57, 40));
    return _tube(pts, 8.6);
  }

  static Path _vena() => _tube(_cubic(const Offset(70, 34), const Offset(72, 39), const Offset(73, 45), const Offset(70, 51)), 7.6);

  static Path _branches() {
    var p = _tube(_cubic(const Offset(49, 37), const Offset(48, 34), const Offset(48, 32), const Offset(48, 29), 6), 3.4);
    p = Path.combine(PathOperation.union, p, _tube(_cubic(const Offset(56, 34), const Offset(57, 31), const Offset(57, 29), const Offset(58, 27), 6), 3.2));
    p = Path.combine(PathOperation.union, p, _tube(_cubic(const Offset(63, 35), const Offset(65, 32), const Offset(65, 30), const Offset(66, 27), 6), 3.0));
    p = Path.combine(PathOperation.union, p, _tube(_cubic(const Offset(46, 40), const Offset(43, 37), const Offset(41, 35), const Offset(39, 32), 6), 3.8));
    p = Path.combine(PathOperation.union, p, _tube(_cubic(const Offset(56, 40), const Offset(59, 38), const Offset(61, 36), const Offset(63, 33), 6), 3.4));
    return p;
  }

  /// حدود القلب العضلي: شكل واحد مرسوم يدوياً (لا اتحاد دوائر).
  static Path _outline() => Path()
    ..moveTo(49, 42)
    ..cubicTo(42, 35, 31, 37, 28.5, 47)
    ..cubicTo(26.5, 57, 31, 68, 37, 77)
    ..cubicTo(41, 83, 45, 88, 49, 89)
    ..cubicTo(54, 88, 61, 82, 65, 72)
    ..cubicTo(69, 63, 70, 52, 66, 45)
    ..cubicTo(62, 38, 54, 36, 49, 42)
    ..close();

  static Path _coronaries() {
    var p = _tube(_cubic(const Offset(40, 50), const Offset(36, 58), const Offset(38, 68), const Offset(42, 79), 12), 1.7);
    p = Path.combine(PathOperation.union, p, _tube(_cubic(const Offset(52, 52), const Offset(56, 58), const Offset(56, 68), const Offset(52, 81), 12), 1.6));
    p = Path.combine(PathOperation.union, p, _tube(_cubic(const Offset(33, 60), const Offset(37, 63), const Offset(42, 65), const Offset(47, 65), 8), 1.3));
    return p;
  }

  static final List<_Piece> _pieces = [
    _Piece(_aorta(), 0.03, _Tissue.artery),
    _Piece(_branches(), 0.08, _Tissue.vein),
    _Piece(_pulmonary(), 0.14, _Tissue.vein),
    _Piece(_vena(), 0.20, _Tissue.vein),
    _Piece(_blob(36, 46, 11.5, 9.5, -14, 1), 0.33, _Tissue.muscle),
    _Piece(_blob(63, 45, 11, 9.5, 12, 2), 0.43, _Tissue.muscle),
    _Piece(_blob(40, 66, 16.5, 21.5, -12, 3), 0.54, _Tissue.muscle),
    _Piece(_blob(56, 68, 14, 19.5, 7, 4), 0.67, _Tissue.muscle),
    _Piece(_blob(34.5, 80, 10.5, 12, -22, 5), 0.80, _Tissue.muscle),
    _Piece(_coronaries(), 0.90, _Tissue.vessel),
  ];

  static final Path _silhouette = [
    _outline(),
    _aorta(),
    _branches(),
    _pulmonary(),
    _vena(),
  ].skip(1).fold<Path>(_outline(), (acc, p) => Path.combine(PathOperation.union, acc, p));

  static double _rand(int i) {
    final v = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  static final List<Path> _cracks = () {
    final out = <Path>[];
    for (var i = 0; i < 16; i++) {
      var x = 27 + 42 * _rand(i + 1), y = 40 + 46 * _rand(i + 40);
      final p = Path()..moveTo(x, y);
      var ang = _rand(i + 90) * math.pi * 2;
      for (var s = 0; s < 5; s++) {
        ang += (_rand(i * 7 + s) - .5) * 1.6;
        final len = 3 + 5 * _rand(i * 11 + s);
        x += math.cos(ang) * len;
        y += math.sin(ang) * len;
        p.lineTo(x, y);
      }
      out.add(p);
    }
    return out;
  }();

  /// حدّ الصدع المتقدّم: جبهة أفقية متكسّرة تنزل من الأعلى إلى الأسفل
  /// (الأوعية أولاً ثم الأذينان ثم البطينان ثم القمة) في الصورة الحقيقية.
  static Path _crackFront(Rect r, double p) {
    final front = r.top + r.height * (0.04 + 0.96 * p);
    final path = Path()..moveTo(r.left, r.top);
    const n = 44;
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final x = r.left + r.width * u;
      final wob = 0.028 * math.sin(u * 11 + p * 7) + 0.016 * math.sin(u * 29 + 1.7) + 0.010 * math.sin(u * 53 + p * 3);
      final tongue = 0.075 * math.pow(math.max(0.0, math.sin(u * 8.5 + 0.7)), 7);
      final y = front + r.height * (wob + tongue * (1 - p * .8));
      path.lineTo(x, y);
    }
    path
      ..lineTo(r.right, r.top)
      ..close();
    return path;
  }

  static double _beatCurve(double t) {
    if (t <= 0 || t >= 1) return 0;
    double thump(double x) => (x <= 0 || x >= 1) ? 0.0 : math.sin(math.pi * x);
    return (0.9 * thump(t / .26) + 0.6 * thump((t - .30) / .36)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _unitW;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF11171A), Color(0xFF04070A)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.save();
    canvas.translate(0, (size.height - _unitH * k) / 2);
    canvas.scale(k);

    // قوس المحراب
    final arch = Path()
      ..moveTo(7, 119)
      ..lineTo(7, 58)
      ..cubicTo(7, 27, 30, 9, 50, 9)
      ..cubicTo(70, 9, 93, 27, 93, 58)
      ..lineTo(93, 119);
    canvas.drawPath(arch, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _gold.withValues(alpha: .18));

    // هالة خلف القلب تكبر مع التقدّم
    const glowC = Offset(48, 60);
    final glowR = 46.0 + 8 * progress;
    canvas.drawCircle(glowC, glowR, Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFB0202A).withValues(alpha: .10 + .32 * progress),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: glowC, radius: glowR)));
    canvas.drawCircle(const Offset(48, 55), 34.0, Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: .05),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: const Offset(48, 55), radius: 34)));

    final pulse = _beatCurve(beat);
    canvas.save();
    canvas.translate(48, 60);
    canvas.rotate(-8 * math.pi / 180);
    canvas.scale(1.1 * (1 + .035 * pulse));
    canvas.translate(-48, -60);

    // منطقة القطع الظاهرة حتى الآن (حدود متكسّرة كالصخر)
    Path? mask;
    for (final p in _pieces) {
      if (progress <= p.at) continue;
      mask = mask == null ? p.path : Path.combine(PathOperation.union, mask, p.path);
    }
    if (progress >= .95) mask = _silhouette;

    if (hasArt) {
      // الزوج الصوري: الحجر، ثم القلب الحيّ يُكشف بحدّ صدع متقدّم.
      final iw = charcoal!.width.toDouble(), ih = charcoal!.height.toDouble();
      const box = Rect.fromLTWH(16, 15, 68, 71);
      final sc = math.min(box.width / iw, box.height / ih);
      final dst = Rect.fromCenter(center: box.center, width: iw * sc, height: ih * sc);
      final src = Rect.fromLTWH(0, 0, iw, ih);
      canvas.drawImageRect(charcoal!, src, dst, Paint()..filterQuality = FilterQuality.medium);
      if (progress > 0.002) {
        final front = _crackFront(dst, progress);
        canvas.save();
        canvas.clipPath(front);
        canvas.drawImageRect(living!, src, dst, Paint()..filterQuality = FilterQuality.medium);
        canvas.restore();
        canvas.drawPath(front, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFFF8A4C).withValues(alpha: .38 * (1 - .55 * progress))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2));
      }
    } else {
      // احتياطي متجهي بنفس الشكل حتى تصل الصور.
      canvas.drawPath(_silhouette, Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E3E45), Color(0xFF232327), Color(0xFF141416)],
        ).createShader(const Rect.fromLTWH(24, 30, 48, 62)));
      canvas.save();
      canvas.clipPath(_silhouette);
      final crackP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05
        ..color = const Color(0xFF08080A);
      for (final c in _cracks) {
        canvas.drawPath(c, crackP);
      }
      for (final c in _cracks.take(7)) {
        canvas.drawPath(c.shift(const Offset(.7, -.7)), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0xFF63636C).withValues(alpha: .5));
      }
      canvas.restore();
      canvas.drawPath(_silhouette, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF5A5A63).withValues(alpha: .45));

      if (mask != null) {
        canvas.save();
        canvas.clipPath(_outline());
        canvas.clipPath(mask);
        // عضلة واحدة متّصلة بإضاءة ناعمة
        canvas.drawRect(const Rect.fromLTWH(18, 18, 66, 86), Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.45, -0.55),
            radius: 0.95,
            colors: [Color(0xFFD2454C), Color(0xFFB0232E), Color(0xFF7C121C)],
            stops: [0, .5, 1],
          ).createShader(const Rect.fromLTWH(26, 33, 45, 58)));
        // أخاديد وظلال العضلة
        final shade = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: .10);
        canvas.drawPath(Path()..addPolygon(_cubic(const Offset(41, 45), const Offset(36, 56), const Offset(38, 70), const Offset(45, 82), 12), false), shade);
        canvas.drawPath(Path()..addPolygon(_cubic(const Offset(54, 47), const Offset(58, 58), const Offset(57, 72), const Offset(52, 84), 12), false), shade);
        // إضاءة علوية
        canvas.drawOval(Rect.fromCenter(center: const Offset(37, 50), width: 26, height: 14), Paint()..color = Colors.white.withValues(alpha: .16));
        canvas.drawOval(Rect.fromCenter(center: const Offset(57, 55), width: 9, height: 18), Paint()..color = Colors.white.withValues(alpha: .08));
        canvas.drawOval(Rect.fromCenter(center: const Offset(58, 76), width: 26, height: 22), Paint()..color = Colors.black.withValues(alpha: .18));
        // الشرايين والأوردة والعرق فوق العضلة
        for (final p in _pieces) {
          if (p.tissue == _Tissue.muscle) continue;
          final a = ((progress - p.at) / .10).clamp(0.0, 1.0);
          if (a <= 0) continue;
          canvas.drawPath(p.path, Paint()..color = p.tissue.color.withValues(alpha: a));
        }
        canvas.restore();
        canvas.drawPath(mask, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFF9A63).withValues(alpha: .30 * (1 - .6 * progress))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      }
    }

    canvas.restore(); // النبضة

    // خيط الخرز
    final arc = _cubic(const Offset(6, 31), const Offset(28, 13), const Offset(72, 13), const Offset(94, 27), 12);
    canvas.drawPath(Path()..addPolygon(arc, false), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0xFF2E6B49).withValues(alpha: .5));
    final active = (progress * (arc.length - 1)).floor().clamp(0, arc.length - 1);
    for (var i = 0; i < arc.length; i++) {
      final on = i <= active;
      canvas.drawCircle(arc[i], 2.7, Paint()..color = on ? const Color(0xFF57C98A) : const Color(0xFF2E6349));
      if (on) {
        canvas.drawCircle(arc[i] - const Offset(.9, .9), .9, Paint()..color = Colors.white.withValues(alpha: .5));
      }
    }

    // خرزات ساقطة عند كل ذكر
    for (final d in drops) {
      final t = d.clamp(0.0, 1.0);
      final s = arc[active];
      final x = s.dx + 4 * math.sin(t * 3);
      final y = s.dy + 48 * t * t;
      final a = (1 - t).clamp(0.0, 1.0);
      canvas.drawLine(Offset(x, y - 12 * (1 - t)), Offset(x, y - 3), Paint()
        ..color = const Color(0xFF7BE0A5).withValues(alpha: a * .35)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(x, y), 2.8 * (1 - t * .3), Paint()..color = const Color(0xFF7BE0A5).withValues(alpha: a));
    }

    // جزيئات هادئة
    final drift = drops.isEmpty ? 0.0 : -5 * drops.last;
    for (var i = 0; i < 14; i++) {
      final bx = 8 + 84 * _rand(i + 3);
      final by = 22 + 92 * _rand(i + 33);
      canvas.drawCircle(Offset(bx, by + drift), .7 + 1.2 * _rand(i + 7), Paint()
        ..color = Colors.white.withValues(alpha: .05 + .12 * progress));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(HeartPainter old) => old.progress != progress || old.beat != beat || old.dark != dark || old.charcoal != charcoal || old.living != living || old.drops.length != drops.length || (drops.isNotEmpty && old.drops.isNotEmpty && old.drops.last != drops.last);
}

enum _Tissue { muscle, artery, vein, vessel }

extension _TissueColor on _Tissue {
  Color get color => switch (this) {
        _Tissue.muscle => const Color(0xFFB02330),
        _Tissue.artery => const Color(0xFFB42530),
        _Tissue.vein => const Color(0xFF6B788C),
        _Tissue.vessel => const Color(0xFF6E1017),
      };
}

class _Piece {
  final Path path;
  final double at;
  final _Tissue tissue;
  const _Piece(this.path, this.at, this.tissue);
}
