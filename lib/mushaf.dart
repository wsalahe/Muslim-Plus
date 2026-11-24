import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'main.dart';
import 'features.dart';

const _paperLight = Color(0xFFFBF3DD);
const _paperDark = Color(0xFF1F1B14);
const _inkLight = Color(0xFF2B2118);
const _inkDark = Color(0xFFEADFC3);

/// بيانات الصفحات: بداية كل صفحة من 604 صفحة (سورة، آية) من Tanzil، وبداية الأجزاء.
class PageData {
  static List<List<int>>? _starts;
  static List<List<int>>? _juz;

  static Future<void> load() async {
    if (_starts != null) return;
    final j = jsonDecode(await rootBundle.loadString('assets/pages.json')) as Map;
    _starts = [for (final e in (j["pages"] as List)) (e as List).cast<int>()];
    _juz = [for (final e in (j["juz"] as List)) (e as List).cast<int>()];
  }

  static void debugLoad(Map j) {
    _starts = [for (final e in (j["pages"] as List)) (e as List).cast<int>()];
    _juz = [for (final e in (j["juz"] as List)) (e as List).cast<int>()];
  }

  static int get count => 604;

  static bool _le(List<int> a, int s, int ay) => a[0] < s || (a[0] == s && a[1] <= ay);

  /// رقم الصفحة (١..٦٠٤) التي تحتوي الآية.
  static int pageOf(int s, int ay) {
    var p = 1;
    for (var i = 0; i < count; i++) {
      if (_le(_starts![i], s, ay)) {
        p = i + 1;
      } else {
        break;
      }
    }
    return p;
  }

  static int juzOf(int page) {
    final st = _starts![page - 1];
    var j = 1;
    for (var i = 0; i < _juz!.length; i++) {
      if (_le(_juz![i], st[0], st[1])) j = i + 1;
    }
    return j;
  }

  /// آيات الصفحة: قائمة (سورة، آية) مرتبة.
  static List<(int, int)> ayahsOf(int page, List quran) {
    final a = _starts![page - 1];
    final end = page < count ? _starts![page] : [115, 1];
    final out = <(int, int)>[];
    var s = a[0], ay = a[1];
    while (s < end[0] || (s == end[0] && ay < end[1])) {
      final len = ((quran[s - 1] as Map)['a'] as List).length;
      if (ay > len) {
        s++;
        ay = 1;
        if (s > 114) break;
        continue;
      }
      out.add((s, ay));
      ay++;
    }
    return out;
  }
}

/// وجه صفحة المصحف: ورق كريمي، رأس السورة المزخرف، أرقام الآيات، رأس الصفحة والجزء.
class MushafPageFace extends StatelessWidget {
  final int page;
  final List quran;
  final double fontSize;
  final (int, int)? highlight;
  final void Function((int, int))? onTapAyah;
  const MushafPageFace({super.key, required this.page, required this.quran, this.fontSize = 24, this.highlight, this.onTapAyah});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? _paperDark : _paperLight;
    final ink = dark ? _inkDark : _inkLight;
    final ays = PageData.ayahsOf(page, quran);
    final firstSurah = ays.isEmpty ? 1 : ays.first.$1;
    final juz = PageData.juzOf(page);

    // نقسم الآيات إلى مقاطع حسب السورة
    final blocks = <Widget>[];
    var i = 0;
    while (i < ays.length) {
      final s = ays[i].$1;
      if (ays[i].$2 == 1) {
        blocks.add(SurahBanner(name: surahs[s - 1], ink: ink));
        if (s != 1 && s != 9) {
          blocks.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontSize: fontSize + 1, color: ink, height: 1.8)),
          ));
        }
      }
      final spans = <InlineSpan>[];
      while (i < ays.length && ays[i].$1 == s) {
        final (ss, aa) = ays[i];
        final text = ((quran[ss - 1] as Map)['a'] as List)[aa - 1] as String;
        final hl = highlight == (ss, aa);
        spans.add(TextSpan(
          text: '$text ',
          style: hl ? TextStyle(backgroundColor: gold.withValues(alpha: .35)) : null,
        ));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AyahMark(n: aa, ink: ink, size: fontSize * .95),
        ));
        spans.add(const TextSpan(text: ' '));
        i++;
        if (i < ays.length && ays[i].$1 == s && ays[i].$2 == 1) break;
      }
      blocks.add(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: null,
        child: Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Amiri', fontSize: fontSize, height: 2.0, color: ink),
        ),
      ));
    }

    return Container(
      color: paper,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: .8), width: 1.6), borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: .45), width: .8)),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('الجزء ${arabicDigits(juz)}', style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: ink.withValues(alpha: .75))),
              Text('سورة ${surahs[firstSurah - 1]}', style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: ink.withValues(alpha: .75))),
            ]),
            Divider(color: gold.withValues(alpha: .5), height: 10),
            Expanded(
              child: LayoutBuilder(builder: (c, box) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: math.max(300, box.maxWidth),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: blocks),
                  ),
                );
              }),
            ),
            Divider(color: gold.withValues(alpha: .5), height: 10),
            Text(arabicDigits(page), style: TextStyle(fontFamily: 'Amiri', fontSize: 15, color: ink.withValues(alpha: .8))),
            Text('Quran text: Tanzil.net (CC BY 3.0)', style: TextStyle(fontSize: 8, color: ink.withValues(alpha: .45))),
          ]),
        ),
      ),
    );
  }
}

class AyahMark extends StatelessWidget {
  final int n;
  final Color ink;
  final double size;
  const AyahMark({super.key, required this.n, required this.ink, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.25,
      height: size * 1.25,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: 1.4)),
      child: Text(arabicDigits(n), style: TextStyle(fontFamily: 'Amiri', fontSize: size * (n > 99 ? .45 : .58), color: ink, height: 1.0)),
    );
  }
}

class SurahBanner extends StatelessWidget {
  final String name;
  final Color ink;
  const SurahBanner({super.key, required this.name, required this.ink});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: CustomPaint(
        painter: _BannerPainter(),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text('سورة $name', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 24, color: ink)),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(26, 2, s.width - 52, s.height - 4), const Radius.circular(8));
    c.drawRRect(r, Paint()..color = gold.withValues(alpha: .13));
    c.drawRRect(r, Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2);
    c.drawRRect(r.deflate(4), Paint()..color = gold.withValues(alpha: .6)..style = PaintingStyle.stroke..strokeWidth = .9);
    for (final left in [true, false]) {
      final cx = left ? 14.0 : s.width - 14;
      final cy = s.height / 2;
      final p = Path()
        ..moveTo(cx, cy - 14)
        ..lineTo(cx + 12, cy)
        ..lineTo(cx, cy + 14)
        ..lineTo(cx - 12, cy)
        ..close();
      c.drawPath(p, Paint()..color = gold.withValues(alpha: .25));
      c.drawPath(p, Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1.6);
      c.drawCircle(Offset(cx, cy), 3, Paint()..color = gold);
      final lx = left ? 26.0 : s.width - 26;
      c.drawLine(Offset(lx, cy), Offset(left ? 26 + 10 : s.width - 36, cy), Paint()..color = gold..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// قلب الصفحة: صفحة تدور حول حافتها اليمنى مع ظل، والصفحة التالية تظهر تحتها.
class PageFlip extends StatelessWidget {
  final Widget leaving, under;
  final double q; // 0 = الصفحة مفتوحة، 1 = مقلوبة تماما
  const PageFlip({super.key, required this.leaving, required this.under, required this.q});
  @override
  Widget build(BuildContext context) {
    final a = q * math.pi / 2;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(a);
    return Stack(fit: StackFit.expand, children: [
      under,
      Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: (q * 0.28).clamp(0, 1))))),
      if (q < 0.999)
        Transform(
          transform: m,
          alignment: Alignment.centerRight,
          child: Stack(fit: StackFit.expand, children: [
            leaving,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: .08 + .35 * q)]),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class PageReader extends StatefulWidget {
  final int initialPage;
  const PageReader({super.key, this.initialPage = 1});
  @override
  State<PageReader> createState() => _PageReaderState();
}

class _PageReaderState extends State<PageReader> with SingleTickerProviderStateMixin {
  List? quran;
  int page = 1;
  double t = 0; // -1..1
  late AnimationController anim;
  double size = 24;
  final player = AudioPlayer();
  int reciter = 0;
  bool playing = false;
  (int, int)? cur;
  String? err;
  List<(int, int)> queue = [];
  StreamSubscription? s1, s2;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(1, 604);
    size = Store.prefs.getDouble('mushaf_pg_size') ?? 24;
    reciter = Store.prefs.getInt('mushaf_reciter') ?? 0;
    if (reciter >= kAyahReciters.length) reciter = 0;
    anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..addListener(() => setState(() {}));
    () async {
      await PageData.load();
      quran = await QuranText.load();
      if (mounted) setState(() {});
      save();
    }();
    s1 = player.currentIndexStream.listen((i) {
      if (i == null || !mounted || i >= queue.length) return;
      setState(() => cur = queue[i]);
      Store.prefs.setInt('mushaf_last', queue[i].$1);
      Store.prefs.setInt('mushaf_ayah', queue[i].$2 - 1);
    });
    s2 = player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => playing = st.playing && st.processingState != ProcessingState.completed);
      if (st.processingState == ProcessingState.completed) {
        if (page < 604 && queue.isNotEmpty) {
          flipTo(1, then: () => startPage(0));
        } else {
          player.pause();
        }
      }
    });
  }

  @override
  void dispose() {
    s1?.cancel();
    s2?.cancel();
    anim.dispose();
    player.dispose();
    super.dispose();
  }

  void save() {
    Store.prefs.setInt('mushaf_page', page);
    if (quran == null) return;
    final a = PageData.ayahsOf(page, quran!);
    if (a.isNotEmpty) {
      Store.prefs.setInt('mushaf_last', a.first.$1);
      Store.prefs.setInt('mushaf_ayah', a.first.$2 - 1);
    }
  }

  /// يقلب صفحة (dir=1 للأمام، -1 للخلف) بحركة.
  void flipTo(int dir, {VoidCallback? then}) {
    if (anim.isAnimating) return;
    if (page + dir < 1 || page + dir > 604) return;
    final from = t;
    final to = dir.toDouble();
    anim.stop();
    anim.reset();
    final tw = Tween<double>(begin: from, end: to).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut));
    void l() => t = tw.value;
    anim.addListener(l);
    anim.forward().whenComplete(() {
      anim.removeListener(l);
      if (!mounted) return;
      setState(() {
        page += dir;
        t = 0;
      });
      save();
      then?.call();
    });
  }

  void settle(double velocity) {
    if (anim.isAnimating) return;
    var dir = 0;
    if (t > 0.3 || (t > 0.05 && velocity > 600)) dir = 1;
    if (t < -0.3 || (t < -0.05 && velocity < -600)) dir = -1;
    if (page + dir < 1 || page + dir > 604) dir = 0;
    final from = t;
    final to = dir.toDouble();
    anim.stop();
    anim.reset();
    final tw = Tween<double>(begin: from, end: to).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
    void l() => t = tw.value;
    anim.addListener(l);
    anim.forward().whenComplete(() {
      anim.removeListener(l);
      if (!mounted) return;
      setState(() {
        page += dir;
        t = 0;
      });
      if (dir != 0) save();
    });
  }

  Future<void> startPage(int fromIdx) async {
    final q = quran;
    if (q == null) return;
    final (name, folder) = kAyahReciters[reciter];
    setState(() => err = null);
    try {
      queue = PageData.ayahsOf(page, q);
      final items = <AudioSource>[
        for (final (s, a) in queue)
          AudioSource.uri(
            Uri.parse('https://everyayah.com/data/$folder/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3'),
            tag: MediaItem(id: '$folder-$s-$a', title: 'سورة ${surahs[s - 1]} · آية $a', album: name),
          )
      ];
      await player.setAudioSource(ConcatenatingAudioSource(children: items), initialIndex: fromIdx.clamp(0, items.length - 1));
      player.play();
    } catch (e) {
      if (mounted) setState(() => err = 'تعذّر التشغيل، تأكد من الإنترنت');
    }
  }

  Future<void> pickReciter() async {
    final r = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => ListView(children: [
        const Padding(padding: EdgeInsets.all(14), child: Text('اختر القارئ', style: TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold))),
        for (var i = 0; i < kAyahReciters.length; i++)
          ListTile(title: Text(kAyahReciters[i].$1), trailing: i == reciter ? const Icon(Icons.check, color: gold) : null, onTap: () => Navigator.pop(c, i)),
      ]),
    );
    if (r == null || r == reciter) return;
    await Store.prefs.setInt('mushaf_reciter', r);
    setState(() => reciter = r);
    if (playing) await startPage(0);
  }

  Future<void> goTo() async {
    final r = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * .7,
        child: ListView(children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('اذهب إلى سورة', style: TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold))),
          for (var i = 0; i < 114; i++)
            ListTile(
              leading: Text(arabicDigits(i + 1)),
              title: Text('سورة ${surahs[i]}'),
              trailing: Text('ص ${arabicDigits(PageData.pageOf(i + 1, 1))}'),
              onTap: () => Navigator.pop(c, PageData.pageOf(i + 1, 1)),
            ),
        ]),
      ),
    );
    if (r != null) {
      await player.pause();
      setState(() { page = r; t = 0; });
      save();
    }
  }

  Widget face(int p) => MushafPageFace(page: p.clamp(1, 604), quran: quran!, fontSize: size, highlight: cur);

  @override
  Widget build(BuildContext context) {
    final q = quran;
    return Scaffold(
      appBar: AppBar(
        title: Text('صفحة ${arabicDigits(page)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'المصادر والتراخيص',
            onPressed: () => showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('المصادر والتراخيص'),
                content: const Text('نص القرآن وبيانات الصفحات والأجزاء: Tanzil.net، رخصة Creative Commons Attribution 3.0 (النص دون تعديل).\nالصوت: everyayah.com.\nالخط: Amiri (رخصة SIL OFL).\nأصوات الأذان: archive.org (Public Domain Mark).'),
                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('حسنا'))],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.list), tooltip: 'السور', onPressed: q == null ? null : goTo),
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () { setState(() => size = math.max(16, size - 2)); Store.prefs.setDouble('mushaf_pg_size', size); }),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () { setState(() => size = math.min(34, size + 2)); Store.prefs.setDouble('mushaf_pg_size', size); }),
        ],
      ),
      body: q == null
          ? const Center(child: CircularProgressIndicator(color: gold))
          : LayoutBuilder(builder: (c, box) {
              Widget view;
              if (t > 0) {
                view = PageFlip(leaving: face(page), under: face(page + 1), q: t.clamp(0, 1));
              } else if (t < 0) {
                view = PageFlip(leaving: face(page - 1), under: face(page), q: (1 + t).clamp(0, 1));
              } else {
                view = face(page);
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  if (anim.isAnimating) return;
                  setState(() {
                    t = (t + d.delta.dx / box.maxWidth * 1.15).clamp(page > 1 ? -1.0 : 0.0, page < 604 ? 1.0 : 0.0);
                  });
                },
                onHorizontalDragEnd: (d) => settle(d.primaryVelocity ?? 0),
                child: view,
              );
            }),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (err != null) Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            Row(children: [
              Expanded(child: TextButton.icon(onPressed: pickReciter, icon: const Icon(Icons.person, color: gold), label: Text(kAyahReciters[reciter].$1, overflow: TextOverflow.ellipsis))),
              IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'الصفحة السابقة', onPressed: page > 1 ? () => flipTo(-1) : null),
              IconButton(
                iconSize: 44,
                color: gold,
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                onPressed: q == null
                    ? null
                    : () {
                        if (playing) {
                          player.pause();
                        } else if (queue.isEmpty || player.audioSource == null || !PageData.ayahsOf(page, q).contains(cur)) {
                          startPage(0);
                        } else {
                          player.play();
                        }
                      },
              ),
              IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'الصفحة التالية', onPressed: page < 604 ? () => flipTo(1) : null),
            ]),
          ]),
        ),
      ),
    );
  }
}
