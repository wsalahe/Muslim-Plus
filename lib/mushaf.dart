import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'main.dart';
import 'mushaf_theme.dart';
import 'l10n.dart';
import 'features.dart';


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
class _Grp {
  final int surah;
  final bool starts;
  final List<(int, int, String)> v = [];
  _Grp(this.surah, this.starts);
}

class MushafPageFace extends StatelessWidget {
  final int page;
  final List quran;
  final double fontSize; // الحد الأعلى للخط؛ الصفحة تصغّره تلقائيا لتملأ العرض دون تصغير الكتلة
  final (int, int)? highlight;
  final void Function((int, int))? onTapAyah;
  final MushafTheme? theme;
  const MushafPageFace({super.key, required this.page, required this.quran, this.fontSize = 40, this.highlight, this.onTapAyah, this.theme});

  /// آخر حجم خط مناسب حُسب (يستعمله زرا A+ و A-).
  static double lastFit = 24;

  static const _lh = 2.1;
  static const _bannerH = 46.0 + 12.0;

  List<InlineSpan> _spans(_Grp g, double fs, Color ink, MushafTheme th, {bool measure = false}) {
    final out = <InlineSpan>[];
    for (final (ss, aa, text) in g.v) {
      final hl = !measure && highlight == (ss, aa);
      out.add(TextSpan(
        text: '$text ',
        style: hl ? TextStyle(backgroundColor: th.accent.withValues(alpha: .35)) : null,
        recognizer: (measure || onTapAyah == null) ? null : (TapGestureRecognizer()..onTap = () => onTapAyah!((ss, aa))),
      ));
      if (measure) {
        out.add(const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox()));
      } else {
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(onTap: onTapAyah == null ? null : () => onTapAyah!((ss, aa)), child: AyahMark(n: aa, ink: ink, size: fs * .95, accent: th.accent)),
        ));
      }
      out.add(const TextSpan(text: ' '));
    }
    return out;
  }

  double _height(List<_Grp> gs, double fs, double w) {
    var h = 0.0;
    for (final g in gs) {
      if (g.starts) {
        h += _bannerH;
        if (g.surah != 1 && g.surah != 9) h += (fs + 1) * _lh + 6;
      }
      final tp = TextPainter(
        text: TextSpan(children: _spans(g, fs, Colors.black, MushafTheme.all.first, measure: true), style: TextStyle(fontFamily: 'AmiriQuran', fontFamilyFallback: const ['Amiri'], fontSize: fs, height: _lh)),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      );
      final m = fs * .95 * 1.25;
      tp.setPlaceholderDimensions(List.filled(g.v.length, PlaceholderDimensions(size: Size(m, m), alignment: PlaceholderAlignment.middle)));
      tp.layout(maxWidth: w);
      h += tp.height;
      tp.dispose();
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final th = (theme ?? MushafTheme.byId(MushafTheme.currentId)).resolve(context);
    final paper = th.paper;
    final ink = th.ink;
    final plain = th.kind == FrameKind.plain;
    final ays = PageData.ayahsOf(page, quran);
    final firstSurah = ays.isEmpty ? 1 : ays.first.$1;
    final juz = PageData.juzOf(page);

    final gs = <_Grp>[];
    for (var i = 0; i < ays.length; i++) {
      final (ss, aa) = ays[i];
      if (gs.isEmpty || gs.last.surah != ss || aa == 1) gs.add(_Grp(ss, aa == 1));
      gs.last.v.add((ss, aa, ((quran[ss - 1] as Map)['a'] as List)[aa - 1] as String));
    }

    final hdr = TextStyle(fontFamily: 'Amiri', fontSize: 14, color: plain ? th.accent : ink.withValues(alpha: .75), fontWeight: plain ? FontWeight.bold : FontWeight.normal);
    return Container(
      color: paper,
      child: MushafFrame(
        th: th,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr('الجزء ${arabicDigits(juz)}'), style: hdr),
            Text(tr('سورة ${trs(surahs[firstSurah - 1])}'), style: hdr),
          ]),
          Divider(color: th.accent.withValues(alpha: plain ? .9 : .5), height: 10, thickness: plain ? 2 : 1),
          Expanded(
            child: LayoutBuilder(builder: (c, box) {
              // أكبر خط يملأ العرض كاملا ويتسع للصفحة كلها بلا تصغير للكتلة
              var lo = 12.0, hi = math.max(12.0, fontSize);
              final avail = box.maxHeight / 1.08; // هامش أمان لفروق القياس
              if (_height(gs, hi, box.maxWidth) <= avail) {
                lo = hi;
              } else {
                for (var k = 0; k < 9; k++) {
                  final mid = (lo + hi) / 2;
                  if (_height(gs, mid, box.maxWidth) <= avail) { lo = mid; } else { hi = mid; }
                }
              }
              final fs = lo;
              lastFit = fs;
              final blocks = <Widget>[];
              for (final g in gs) {
                if (g.starts) {
                  blocks.add(SurahBanner(name: trs(surahs[g.surah - 1]), ink: ink, th: th));
                  if (g.surah != 1 && g.surah != 9) {
                    blocks.add(Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontSize: fs + 1, color: ink, height: _lh)),
                    ));
                  }
                }
                blocks.add(Text.rich(
                  TextSpan(children: _spans(g, fs, ink, th)),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'AmiriQuran', fontFamilyFallback: const ['Amiri'], fontSize: fs, height: _lh, color: ink),
                ));
              }
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: blocks),
              );
            }),
          ),
          if (!plain) Divider(color: th.accent.withValues(alpha: .5), height: 10),
          Text(arabicDigits(page), style: TextStyle(fontFamily: 'Amiri', fontSize: 15, color: ink.withValues(alpha: .8))),
        ]),
      ),
    );
  }
}

class AyahMark extends StatelessWidget {
  final int n;
  final Color ink;
  final double size;
  final Color accent;
  const AyahMark({super.key, required this.n, required this.ink, required this.size, this.accent = gold});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.25,
      height: size * 1.25,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 1.4)),
      child: Text(arabicDigits(n), style: TextStyle(fontFamily: 'Amiri', fontSize: size * (n > 99 ? .45 : .58), color: ink, height: 1.0)),
    );
  }
}

class SurahBanner extends StatelessWidget {
  final String name;
  final Color ink;
  final MushafTheme th;
  const SurahBanner({super.key, required this.name, required this.ink, required this.th});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: CustomPaint(
        painter: _BannerPainter(th),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(tr('سورة $name'), style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 24, color: th.solidBanner ? th.bannerInk : ink)),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  final MushafTheme th;
  _BannerPainter(this.th);
  @override
  void paint(Canvas c, Size s) {
    final gold = th.accent;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(26, 2, s.width - 52, s.height - 4), const Radius.circular(8));
    c.drawRRect(r, Paint()..color = th.solidBanner ? th.accent2 : gold.withValues(alpha: .13));
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
  bool shouldRepaint(covariant _BannerPainter old) => old.th.id != th.id;
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
  double size = 40;
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
    size = Store.prefs.getDouble('mushaf_pg_size2') ?? 40;
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
            tag: MediaItem(id: '$folder-$s-$a', title: tr('سورة ${trs(surahs[s - 1])} · آية $a'), album: name),
          )
      ];
      await player.setAudioSource(ConcatenatingAudioSource(children: items), initialIndex: fromIdx.clamp(0, items.length - 1));
      player.play();
    } catch (e) {
      if (mounted) setState(() => err = tr('تعذّر التشغيل، تأكد من الإنترنت'));
    }
  }

  Future<void> pickReciter() async {
    final r = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => ListView(children: [
        Padding(padding: EdgeInsets.all(14), child: Text(tr('اختر القارئ'), style: TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold))),
        for (var i = 0; i < kAyahReciters.length; i++)
          ListTile(title: Text(tr(kAyahReciters[i].$1)), trailing: i == reciter ? const Icon(Icons.check, color: gold) : null, onTap: () => Navigator.pop(c, i)),
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
          Padding(padding: EdgeInsets.all(14), child: Text(tr('اذهب إلى سورة'), style: TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold))),
          for (var i = 0; i < 114; i++)
            ListTile(
              leading: Text(arabicDigits(i + 1)),
              title: Text(tr('سورة ${trs(surahs[i])}')),
              trailing: Text(tr('ص ${arabicDigits(PageData.pageOf(i + 1, 1))}')),
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

  Widget face(int p) => MushafPageFace(page: p.clamp(1, 604), quran: quran!, fontSize: size, highlight: cur, onTapAyah: t == 0 && p == page ? tapAyah : null);

  /// الضغط على آية: تظليلها وتشغيل القارئ منها ثم المتابعة.
  void tapAyah((int, int) ay) {
    final list = PageData.ayahsOf(page, quran!);
    final idx = list.indexOf(ay);
    if (idx < 0) return;
    setState(() => cur = ay);
    startPage(idx);
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: _body(context));

  Widget _body(BuildContext context) {
    final q = quran;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('صفحة ${arabicDigits(page)}')),
        actions: [
          IconButton(icon: const Icon(Icons.list), tooltip: tr('السور'), onPressed: q == null ? null : goTo),
          IconButton(icon: const Icon(Icons.palette_outlined), tooltip: tr('مظهر المصحف'), onPressed: q == null ? null : () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => MushafThemePage(quran: q))); if (mounted) setState(() => size = Store.prefs.getDouble('mushaf_pg_size2') ?? 40); }),
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () { setState(() => size = math.max(14, math.min(size, MushafPageFace.lastFit) - 2)); Store.prefs.setDouble('mushaf_pg_size2', size); }),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () { setState(() => size = math.min(40, math.min(size, MushafPageFace.lastFit) + 2)); Store.prefs.setDouble('mushaf_pg_size2', size); }),
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
              Expanded(child: TextButton.icon(onPressed: pickReciter, icon: const Icon(Icons.person, color: gold), label: Text(tr(kAyahReciters[reciter].$1), overflow: TextOverflow.ellipsis))),
              IconButton(icon: const Icon(Icons.chevron_right), tooltip: tr('الصفحة السابقة'), onPressed: page > 1 ? () => flipTo(-1) : null),
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
              IconButton(icon: const Icon(Icons.chevron_left), tooltip: tr('الصفحة التالية'), onPressed: page < 604 ? () => flipTo(1) : null),
            ]),
          ]),
        ),
      ),
    );
  }
}
