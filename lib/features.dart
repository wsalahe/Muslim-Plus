import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';
import 'l10n.dart';
import 'prayer.dart';
import 'extras.dart';
import 'mushaf.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  final pages = [HomeTab(), AdhanTab(), MushafTab(), AdhkarTab(), QiblaTab()];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: [
            NavigationDestination(icon: Icon(Icons.home), label: tr('الرئيسية')),
            NavigationDestination(icon: Icon(Icons.notifications_active), label: tr('الأذان')),
            NavigationDestination(icon: Icon(Icons.menu_book), label: tr('المصحف')),
            NavigationDestination(icon: Icon(Icons.favorite_border), label: tr('الأذكار')),
            NavigationDestination(icon: Icon(Icons.explore), label: tr('القبلة')),
          ],
        ),
      );
}

// ---------------- Mushaf ----------------
class QuranText {
  static List? _data;
  static Future<List> load() async => _data ??= jsonDecode(await rootBundle.loadString('assets/quran.json')) as List;
}

String arabicDigits(int n) => isEn ? n.toString() : n.toString().split('').map((d) => d == '-' ? d : String.fromCharCode(0x660 + int.parse(d))).join();

class MushafTab extends StatefulWidget {
  const MushafTab({super.key});
  @override
  State<MushafTab> createState() => _MushafTabState();
}

class _MushafTabState extends State<MushafTab> {
  void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) { if (mounted) setState(() {}); });

  @override
  Widget build(BuildContext context) {
    final last = Store.prefs.getInt('mushaf_last');
    final lastAyah = Store.prefs.getInt('mushaf_ayah') ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(tr('المصحف الشريف'), style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List>(
        future: QuranText.load(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: gold));
          final data = snap.data!;
          return ListView.builder(
            itemCount: data.length + (last != null ? 1 : 0),
            itemBuilder: (c, i) {
              if (last != null && i == 0) {
                return Card(child: ListTile(leading: const Icon(Icons.bookmark, color: gold), title: Text(tr('متابعة القراءة: سورة ${trs(surahs[last - 1])} · آية ${arabicDigits(lastAyah + 1)}')), subtitle: Text(tr('مصحف بالصفحات مع قلب الصفحة')), onTap: () async { await PageData.load(); if (mounted) open(PageReader(initialPage: Store.prefs.getInt('mushaf_page') ?? PageData.pageOf(last, lastAyah + 1))); }));
              }
              final s = data[i - (last != null ? 1 : 0)];
              final n = s['n'] as int;
              return ListTile(
                leading: CircleAvatar(backgroundColor: navy, child: Text('$n', style: const TextStyle(color: gold, fontSize: 13))),
                title: Text(tr('سورة ${trs(surahs[n - 1])}'), style: const TextStyle(fontFamily: 'Amiri', fontSize: 20)),
                subtitle: Text(tr('${(s['a'] as List).length} آية · ${s['t'] == 'Meccan' ? 'مكية' : 'مدنية'}')),
                onTap: () async { await PageData.load(); if (mounted) open(PageReader(initialPage: PageData.pageOf(n, 1))); },
              );
            },
          );
        },
      ),
    );
  }
}

const kAyahReciters = [
  ('مشاري العفاسي', 'Alafasy_128kbps'),
  ('محمود خليل الحصري', 'Husary_128kbps'),
  ('محمد صديق المنشاوي (مرتل)', 'Minshawy_Murattal_128kbps'),
  ('محمد صديق المنشاوي (مجود)', 'Minshawy_Mujawwad_192kbps'),
  ('عبد الباسط عبد الصمد (مرتل)', 'Abdul_Basit_Murattal_192kbps'),
  ('عبد الباسط عبد الصمد (مجود)', 'Abdul_Basit_Mujawwad_128kbps'),
  ('عبد الرحمن السديس', 'Abdurrahmaan_As-Sudais_192kbps'),
  ('سعود الشريم', 'Saood_ash-Shuraym_128kbps'),
  ('ماهر المعيقلي', 'MaherAlMuaiqly128kbps'),
  ('علي الحذيفي', 'Hudhaify_128kbps'),
  ('سعد الغامدي', 'Ghamadi_40kbps'),
  ('ياسر الدوسري', 'Yasser_Ad-Dussary_128kbps'),
  ('ناصر القطامي', 'Nasser_Alqatami_128kbps'),
  ('أبو بكر الشاطري', 'Abu_Bakr_Ash-Shaatree_128kbps'),
  ('عبد الله بصفر', 'Abdullah_Basfar_192kbps'),
  ('عبد الله مطرود', 'Abdullah_Matroud_128kbps'),
  ('هاني الرفاعي', 'Hani_Rifai_192kbps'),
  ('صلاح البدير', 'Salah_Al_Budair_128kbps'),
  ('محمد جبريل', 'Muhammad_Jibreel_128kbps'),
  ('محمد أيوب', 'Muhammad_Ayyoub_128kbps'),
  ('محمد الطبلاوي', 'Mohammad_al_Tablaway_128kbps'),
  ('خالد القحطاني', 'Khaalid_Abdullaah_al-Qahtaanee_192kbps'),
  ('أحمد العجمي', 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net'),
  ('علي جابر', 'Ali_Jaber_64kbps'),
  ('فارس عباد', 'Fares_Abbad_64kbps'),
  ('عبد الله الجهني', 'Abdullaah_3awwaad_Al-Juhaynee_128kbps'),
  ('مصطفى إسماعيل', 'Mustafa_Ismail_48kbps'),
  ('أيمن سويد', 'Ayman_Sowaid_64kbps'),
  ('إبراهيم الأخضر', 'Ibrahim_Akhdar_32kbps'),
  ('محسن القاسم', 'Muhsin_Al_Qasim_192kbps'),
];

class SurahReader extends StatefulWidget {
  final Map s;
  final int initialAyah;
  const SurahReader(this.s, {super.key, this.initialAyah = 0});
  @override
  State<SurahReader> createState() => _SurahReaderState();
}

class _SurahReaderState extends State<SurahReader> {
  double size = 28;
  final player = AudioPlayer();
  int reciter = 0;
  int cur = -1;
  bool playing = false;
  String? err;
  late final List<GlobalKey> keys;
  StreamSubscription? s1, s2;
  final scroll = ScrollController();
  int topAyah = 0;

  int get n => widget.s['n'] as int;
  List<String> get ay => (widget.s['a'] as List).cast<String>();

  @override
  void initState() {
    super.initState();
    size = Store.prefs.getDouble('mushaf_size') ?? 28;
    reciter = Store.prefs.getInt('mushaf_reciter') ?? 0;
    if (reciter >= kAyahReciters.length) reciter = 0;
    if (Store.prefs.getInt('mushaf_last') != n) Store.prefs.setInt('mushaf_ayah', 0);
    Store.prefs.setInt('mushaf_last', n);
    topAyah = widget.initialAyah;
    keys = List.generate(ay.length, (_) => GlobalKey());
    s1 = player.currentIndexStream.listen((i) {
      if (i == null || !mounted) return;
      setState(() => cur = i);
      final c = keys[i].currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), alignment: .3);
      Store.prefs.setInt('mushaf_ayah', i);
    });
    if (widget.initialAyah > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = keys[widget.initialAyah.clamp(0, keys.length - 1)].currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: 0.05);
      });
    }
    s2 = player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() => playing = st.playing && st.processingState != ProcessingState.completed);
      if (st.processingState == ProcessingState.completed) player.pause();
    });
  }

  @override
  void dispose() {
    s1?.cancel();
    s2?.cancel();
    Store.prefs.setInt('mushaf_ayah', topAyah);
    scroll.dispose();
    player.dispose();
    super.dispose();
  }

  void trackTop() {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    for (var i = 0; i < keys.length; i++) {
      final ro = keys[i].currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        final y = ro.localToGlobal(Offset.zero).dy;
        if (y + ro.size.height > topInset) {
          topAyah = i;
          Store.prefs.setInt('mushaf_ayah', i);
          Store.prefs.setInt('mushaf_last', n);
          return;
        }
      }
    }
  }

  Future<void> start(int from) async {
    final (name, folder) = kAyahReciters[reciter];
    setState(() => err = null);
    try {
      final items = <AudioSource>[
        for (var i = 0; i < ay.length; i++)
          AudioSource.uri(
            Uri.parse('https://everyayah.com/data/$folder/${n.toString().padLeft(3, '0')}${(i + 1).toString().padLeft(3, '0')}.mp3'),
            tag: MediaItem(id: '$folder-$n-$i', title: tr('سورة ${trs(surahs[n - 1])} · آية ${i + 1}'), album: name),
          )
      ];
      await player.setAudioSource(ConcatenatingAudioSource(children: items), initialIndex: from);
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
    final was = playing;
    final from = cur < 0 ? 0 : cur;
    setState(() => reciter = r);
    if (was || cur >= 0) await start(from);
  }

  @override
  Widget build(BuildContext context) {
    final a = ay;
    return Scaffold(
      appBar: AppBar(title: Text(tr('سورة ${trs(surahs[n - 1])}')), actions: [
        IconButton(icon: const Icon(Icons.done_all), tooltip: tr('تعليم السورة كمقروءة في الختمة'), onPressed: () {
          final d = (jsonDecode(Store.prefs.getString('kh_done') ?? '[]') as List).cast<int>().toSet()..add(n);
          Store.prefs.setString('kh_done', jsonEncode(d.toList()));
          if (Store.prefs.getString('kh_start') == null) Store.prefs.setString('kh_start', DateTime.now().toIso8601String());
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تمت إضافتها إلى ختمتك'))));
        }),
        IconButton(icon: const Icon(Icons.text_decrease), onPressed: () { setState(() => size = math.max(18, size - 2)); Store.prefs.setDouble('mushaf_size', size); }),
        IconButton(icon: const Icon(Icons.text_increase), onPressed: () { setState(() => size = math.min(48, size + 2)); Store.prefs.setDouble('mushaf_size', size); }),
      ]),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (_) { trackTop(); return false; },
        child: SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (n != 1 && n != 9)
              Center(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', style: TextStyle(fontFamily: 'Amiri', fontSize: size + 2, color: gold)))),
            for (var i = 0; i < a.length; i++)
              InkWell(
                key: keys[i],
                onTap: () => start(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: i == cur ? gold.withValues(alpha: .18) : null, borderRadius: BorderRadius.circular(10)),
                  child: Text.rich(
                    TextSpan(children: [TextSpan(text: '${a[i]} '), TextSpan(text: '\u06DD${arabicDigits(i + 1)}', style: const TextStyle(color: gold))]),
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontFamily: 'Amiri', fontSize: size, height: 2.1),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Center(child: Text(tr('النص: المصحف العثماني (Tanzil / alquran.cloud) · الصوت: everyayah.com'), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor))),
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (err != null) Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            Row(children: [
              Expanded(child: TextButton.icon(onPressed: pickReciter, icon: const Icon(Icons.person, color: gold), label: Text(tr(kAyahReciters[reciter].$1), overflow: TextOverflow.ellipsis))),
              IconButton(icon: const Icon(Icons.skip_previous), onPressed: cur > 0 ? player.seekToPrevious : null),
              IconButton(
                iconSize: 44,
                color: gold,
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                onPressed: () {
                  if (playing) {
                    player.pause();
                  } else if (cur < 0 || player.audioSource == null) {
                    start(0);
                  } else {
                    player.play();
                  }
                },
              ),
              IconButton(icon: const Icon(Icons.skip_next), onPressed: cur >= 0 && cur < a.length - 1 ? player.seekToNext : null),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ---------------- Adhkar ----------------
class AdhkarData {
  static List? _data;
  static Future<List> load() async => _data ??= jsonDecode(await rootBundle.loadString('assets/adhkar.json')) as List;
}

int countOf(dynamic c) {
  if (c is int) return c;
  return int.tryParse(c.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
}

class AdhkarTab extends StatefulWidget {
  const AdhkarTab({super.key});
  @override
  State<AdhkarTab> createState() => _AdhkarTabState();
}

class _AdhkarTabState extends State<AdhkarTab> {
  String q = '';
  static const pinned = ['أذكار الصباح والمساء', 'أذكار النوم', 'أذكار الاستيقاظ من النوم', 'الأذكار بعد السلام من الصلاة'];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('الأذكار والأدعية'), style: TextStyle(fontWeight: FontWeight.bold))),
        body: FutureBuilder<List>(
          future: AdhkarData.load(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: gold));
            var cats = List<Map>.from(snap.data!.cast<Map>());
            cats.sort((a, b) {
              final pa = pinned.indexOf(a['name']), pb = pinned.indexOf(b['name']);
              return (pa < 0 ? 999 : pa).compareTo(pb < 0 ? 999 : pb);
            });
            if (q.isNotEmpty) cats = cats.where((x) => (x['name'] as String).contains(q)).toList();
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(decoration: InputDecoration(hintText: tr('ابحث عن ذكر أو دعاء'), prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))), onChanged: (v) => setState(() => q = v.trim())),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: cats.length,
                  itemBuilder: (c, i) {
                    final cat = cats[i];
                    final isPinned = pinned.contains(cat['name']);
                    return ListTile(
                      leading: Icon(isPinned ? Icons.star : Icons.favorite_border, color: gold),
                      title: Text(cat['name']),
                      subtitle: Text(tr('${(cat['items'] as List).length} ذكر')),
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AdhkarPage(cat))),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      );
}

class AdhkarPage extends StatefulWidget {
  final Map cat;
  const AdhkarPage(this.cat, {super.key});
  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  late List<int> left;
  @override
  void initState() {
    super.initState();
    left = (widget.cat['items'] as List).map((e) => countOf(e['c'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.cat['items'] as List;
    return Scaffold(
      appBar: AppBar(title: Text(widget.cat['name'], style: const TextStyle(fontSize: 16)), actions: [
        IconButton(icon: const Icon(Icons.restart_alt), tooltip: tr('إعادة العد'), onPressed: () => setState(() => left = items.map((e) => countOf(e['c'])).toList())),
      ]),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: items.length,
        itemBuilder: (c, i) {
          final done = left[i] == 0;
          return Card(
            color: done ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF123524) : const Color(0xFFD7F0E0)) : Theme.of(context).colorScheme.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () { if (left[i] > 0) { HapticFeedback.selectionClick(); setState(() => left[i]--); } },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(items[i]['t'], style: const TextStyle(fontFamily: 'Amiri', fontSize: 22, height: 1.9)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(done ? Icons.check_circle : Icons.touch_app, color: gold, size: 20),
                    const SizedBox(width: 8),
                    Text(done ? tr('تم') : tr('اضغط للعد · المتبقي ${arabicDigits(left[i])}'), style: const TextStyle(color: gold)),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Qibla ----------------
const kaabaLat = 21.422487, kaabaLon = 39.826206;

double qiblaBearing(double lat, double lon) {
  final p1 = lat * math.pi / 180, p2 = kaabaLat * math.pi / 180;
  final dl = (kaabaLon - lon) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

class QiblaTab extends StatefulWidget {
  const QiblaTab({super.key});
  @override
  State<QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends State<QiblaTab> {
  double? bearing;
  String? msg;
  bool busy = false;

  Future<void> locate() async {
    setState(() { busy = true; msg = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw tr('فعّل الموقع (GPS) من إعدادات الهاتف');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw tr('اسمح للتطبيق بالوصول إلى الموقع لتحديد القبلة');
      final p = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)));
      bearing = qiblaBearing(p.latitude, p.longitude);
      Store.prefs.setDouble('qibla', bearing!);
    } catch (e) {
      msg = e is String ? e : tr('تعذّر تحديد الموقع');
      bearing ??= Store.prefs.getDouble('qibla');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void initState() {
    super.initState();
    bearing = Store.prefs.getDouble('qibla');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('اتجاه القبلة'), style: TextStyle(fontWeight: FontWeight.bold))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: bearing == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.explore, color: gold, size: 80),
                    const SizedBox(height: 12),
                    Text(tr('لتحديد القبلة يحتاج التطبيق إلى موقعك (يبقى على جهازك فقط)'), textAlign: TextAlign.center),
                    if (msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
                    const SizedBox(height: 16),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), onPressed: busy ? null : locate, child: Text(busy ? tr('جاري التحديد...') : tr('تحديد القبلة'))),
                  ])
                : StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (c, snap) {
                      final h = snap.data?.heading;
                      final angle = h == null ? bearing! : (bearing! - h);
                      final aligned = h != null && ((angle % 360 + 360) % 360 < 4 || (angle % 360 + 360) % 360 > 356);
                      return Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(tr('زاوية القبلة: ${arabicDigits(bearing!.round())}° من الشمال'), style: const TextStyle(fontSize: 18, color: gold)),
                        const SizedBox(height: 24),
                        Stack(alignment: Alignment.center, children: [
                          Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: aligned ? Colors.greenAccent : gold, width: 3), color: Theme.of(context).colorScheme.surface)),
                          Transform.rotate(angle: angle * math.pi / 180, child: Icon(Icons.navigation, size: 190, color: aligned ? Colors.greenAccent : gold)),
                          const Positioned(top: 22, child: Text('🕋', style: TextStyle(fontSize: 22))),
                        ]),
                        const SizedBox(height: 20),
                        Text(h == null ? tr('لا يوجد حساس بوصلة: وجّه الهاتف نحو الشمال ثم اتبع الزاوية') : (aligned ? tr('أنت تواجه القبلة') : tr('أدر الهاتف حتى يشير السهم لأعلى')), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton.icon(onPressed: busy ? null : locate, icon: const Icon(Icons.my_location), label: Text(tr('تحديث الموقع'))),
                        if (msg != null) Text(msg!, style: const TextStyle(color: Colors.redAccent)),
                      ]);
                    },
                  ),
          ),
        ),
      );
}
