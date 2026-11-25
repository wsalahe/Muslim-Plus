import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main.dart';
import 'l10n.dart';
import 'mushaf.dart';

enum FrameKind { gold, ornate, green, plain, simple }

/// مظهر المصحف: ألوان وإطار وشكل لافتة السورة. كلها رسوم أصلية مرسومة بالكود.
class MushafTheme {
  final String id;
  final String name; // مفتاح عربي للترجمة
  final Color paper, ink, accent, accent2;
  final FrameKind kind;
  final bool solidBanner;
  final Color bannerInk;
  final bool auto; // الكلاسيكي يتبع الوضع الليلي للتطبيق
  const MushafTheme(this.id, this.name, this.paper, this.ink, this.accent, this.accent2, this.kind,
      {this.solidBanner = false, this.bannerInk = Colors.white, this.auto = false});

  static const all = <MushafTheme>[
    MushafTheme('gold', 'كلاسيك ذهبي', Color(0xFFFBF3DD), Color(0xFF2B2118), gold, gold, FrameKind.gold, auto: true),
    MushafTheme('ornate', 'مزخرف بنفسجي', Color(0xFFFFFFFF), Color(0xFF2A2340), Color(0xFFB8913A), Color(0xFF6B5A8E), FrameKind.ornate),
    MushafTheme('green', 'أخضر مؤطر', Color(0xFFF4F8EC), Color(0xFF16301F), Color(0xFF2E7D4F), Color(0xFF1B5E3A), FrameKind.green, solidBanner: true),
    MushafTheme('clean', 'قراءة نظيفة', Color(0xFFFFFFFF), Color(0xFF1E2A2E), Color(0xFF1B9AAA), Color(0xFF1B9AAA), FrameKind.plain),
    MushafTheme('night', 'ليلي', Color(0xFF16202C), Color(0xFFE3E8EE), Color(0xFFD9B45A), Color(0xFF6C86A3), FrameKind.gold),
    MushafTheme('amoled', 'أسود', Color(0xFF000000), Color(0xFFEDEDED), Color(0xFFB38B2E), Color(0xFF6E5A2A), FrameKind.simple),
    MushafTheme('sepia', 'بني قديم', Color(0xFFF1E3C4), Color(0xFF3B2A18), Color(0xFF9A6B2F), Color(0xFF7A5226), FrameKind.gold),
    MushafTheme('blue', 'أزرق', Color(0xFFEEF4FB), Color(0xFF12263F), Color(0xFF2F6DB5), Color(0xFF1C4A80), FrameKind.green, solidBanner: true),
    MushafTheme('emerald', 'زمردي', Color(0xFF0E2A22), Color(0xFFE6F2EA), Color(0xFFD4B35C), Color(0xFF2F7D63), FrameKind.ornate),
    MushafTheme('rose', 'وردي هادئ', Color(0xFFFDF1F0), Color(0xFF3A2024), Color(0xFFB5657A), Color(0xFF8C3F55), FrameKind.ornate),
    MushafTheme('sand', 'رملي', Color(0xFFF6EFE3), Color(0xFF332B22), Color(0xFFA38660), Color(0xFF8A7048), FrameKind.simple),
    MushafTheme('grey', 'رمادي هادئ', Color(0xFFF1F2F4), Color(0xFF23262B), Color(0xFF6B7280), Color(0xFF4B5563), FrameKind.plain),
  ];

  static String get currentId => Store.prefs.getString('mushaf_theme') ?? 'gold';
  static MushafTheme byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  /// المظهر الفعلي (الكلاسيكي يتبع الوضع الليلي).
  MushafTheme resolve(BuildContext context) {
    if (!auto) return this;
    if (Theme.of(context).brightness == Brightness.dark) {
      return const MushafTheme('gold', 'كلاسيك ذهبي', Color(0xFF1F1B14), Color(0xFFEADFC3), gold, gold, FrameKind.gold, auto: true);
    }
    return this;
  }
}

/// الإطار المحيط بالصفحة حسب النوع.
class MushafFrame extends StatelessWidget {
  final MushafTheme th;
  final Widget child;
  const MushafFrame({super.key, required this.th, required this.child});

  @override
  Widget build(BuildContext context) {
    switch (th.kind) {
      case FrameKind.plain:
        return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: child);
      case FrameKind.simple:
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: th.accent.withValues(alpha: .8), width: 1.2), borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: child,
          ),
        );
      case FrameKind.gold:
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: th.accent.withValues(alpha: .8), width: 1.6), borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: th.accent.withValues(alpha: .45), width: .8)),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: child,
            ),
          ),
        );
      case FrameKind.green:
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Container(
            decoration: BoxDecoration(color: th.paper, border: Border.all(color: th.accent2, width: 5)),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: th.accent, width: 1.5)),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: child,
            ),
          ),
        );
      case FrameKind.ornate:
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: CustomPaint(
            painter: _OrnatePainter(th),
            child: Padding(padding: const EdgeInsets.fromLTRB(26, 24, 26, 22), child: child),
          ),
        );
    }
  }
}

class _OrnatePainter extends CustomPainter {
  final MushafTheme th;
  _OrnatePainter(this.th);
  @override
  void paint(Canvas c, Size s) {
    final outer = Rect.fromLTWH(0, 0, s.width, s.height);
    c.drawRect(outer.deflate(1), Paint()..color = th.accent2..style = PaintingStyle.stroke..strokeWidth = 5);
    c.drawRect(outer.deflate(8), Paint()..color = th.accent..style = PaintingStyle.stroke..strokeWidth = 1.4);
    c.drawRect(outer.deflate(15), Paint()..color = th.accent2.withValues(alpha: .6)..style = PaintingStyle.stroke..strokeWidth = .9);
    // زخارف الزوايا ومنتصف الأضلاع: معينات وزهرات صغيرة
    void diamond(Offset o, double r) {
      final p = Path()..moveTo(o.dx, o.dy - r)..lineTo(o.dx + r, o.dy)..lineTo(o.dx, o.dy + r)..lineTo(o.dx - r, o.dy)..close();
      c.drawPath(p, Paint()..color = th.accent);
      c.drawPath(p, Paint()..color = th.accent2..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    void flower(Offset o, double r) {
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * r * .6, r * .32, Paint()..color = th.accent.withValues(alpha: .85));
      }
      c.drawCircle(o, r * .28, Paint()..color = th.accent2);
    }
    for (final x in [8.0, s.width - 8]) {
      for (final y in [8.0, s.height - 8]) {
        flower(Offset(x, y), 14);
      }
    }
    for (final x in [s.width / 2]) {
      diamond(Offset(x, 8), 6);
      diamond(Offset(x, s.height - 8), 6);
    }
    diamond(Offset(8, s.height / 2), 6);
    diamond(Offset(s.width - 8, s.height / 2), 6);
    for (final f in [.25, .75]) {
      diamond(Offset(s.width * f, 8), 3.5);
      diamond(Offset(s.width * f, s.height - 8), 3.5);
      diamond(Offset(8, s.height * f), 3.5);
      diamond(Offset(s.width - 8, s.height * f), 3.5);
    }
  }

  @override
  bool shouldRepaint(covariant _OrnatePainter old) => old.th.id != th.id;
}

/// صفحة اختيار المظهر مع معاينة حيّة وحجم الخط.
class MushafThemePage extends StatefulWidget {
  final List quran;
  const MushafThemePage({super.key, required this.quran});
  @override
  State<MushafThemePage> createState() => _MushafThemePageState();
}

class _MushafThemePageState extends State<MushafThemePage> {
  String id = MushafTheme.currentId;
  double size = Store.prefs.getDouble('mushaf_pg_size') ?? 24;
  int previewPage = 2;

  @override
  Widget build(BuildContext context) {
    final th = MushafTheme.byId(id);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('مظهر المصحف'))),
        body: Column(children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * .42,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: MushafPageFace(page: previewPage, quran: widget.quran, fontSize: size * .8, theme: th)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text(tr('حجم الخط')),
              Expanded(
                child: Slider(
                  value: size, min: 16, max: 34, divisions: 9, activeColor: gold,
                  onChanged: (v) => setState(() => size = v),
                  onChangeEnd: (v) => Store.prefs.setDouble('mushaf_pg_size', v),
                ),
              ),
            ]),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3, padding: const EdgeInsets.all(10), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .95,
              children: [
                for (final t in MushafTheme.all)
                  InkWell(
                    onTap: () { setState(() => id = t.id); Store.prefs.setString('mushaf_theme', t.id); },
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.paper, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: id == t.id ? gold : t.accent2.withValues(alpha: .5), width: id == t.id ? 3 : 1.2),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('بِسْمِ ٱللَّهِ', style: TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, color: t.ink)),
                        const SizedBox(height: 4),
                        Container(height: 6, width: 46, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(height: 6),
                        Text(tr(t.name), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: t.ink, fontWeight: id == t.id ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
