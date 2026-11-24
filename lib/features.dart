import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  final pages = const [RecitersTab(), MushafTab(), AdhkarTab(), QiblaTab()];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: pages),
        bottomNavigationBar: NavigationBar(
          backgroundColor: navy,
          indicatorColor: gold.withOpacity(.25),
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.headphones), label: 'التلاوات'),
            NavigationDestination(icon: Icon(Icons.menu_book), label: 'المصحف'),
            NavigationDestination(icon: Icon(Icons.favorite_border), label: 'الأذكار'),
            NavigationDestination(icon: Icon(Icons.explore), label: 'القبلة'),
          ],
        ),
      );
}

// ---------------- Mushaf ----------------
class QuranText {
  static List? _data;
  static Future<List> load() async => _data ??= jsonDecode(await rootBundle.loadString('assets/quran.json')) as List;
}

String arabicDigits(int n) => n.toString().split('').map((d) => String.fromCharCode(0x660 + int.parse(d))).join();

class MushafTab extends StatelessWidget {
  const MushafTab({super.key});
  @override
  Widget build(BuildContext context) {
    final last = Store.prefs.getInt('mushaf_last');
    return Scaffold(
      appBar: AppBar(title: const Text('المصحف الشريف', style: TextStyle(fontWeight: FontWeight.bold))),
      body: FutureBuilder<List>(
        future: QuranText.load(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: gold));
          final data = snap.data!;
          return ListView.builder(
            itemCount: data.length + (last != null ? 1 : 0),
            itemBuilder: (c, i) {
              if (last != null && i == 0) {
                return Card(child: ListTile(leading: const Icon(Icons.bookmark, color: gold), title: Text('متابعة القراءة: سورة ${surahs[last - 1]}'), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SurahReader(data[last - 1])))));
              }
              final s = data[i - (last != null ? 1 : 0)];
              final n = s['n'] as int;
              return ListTile(
                leading: CircleAvatar(backgroundColor: navy, child: Text('$n', style: const TextStyle(color: gold, fontSize: 13))),
                title: Text('سورة ${surahs[n - 1]}', style: const TextStyle(fontFamily: 'Amiri', fontSize: 20)),
                subtitle: Text('${(s['a'] as List).length} آية · ${s['t'] == 'Meccan' ? 'مكية' : 'مدنية'}'),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SurahReader(s))),
              );
            },
          );
        },
      ),
    );
  }
}

class SurahReader extends StatefulWidget {
  final Map s;
  const SurahReader(this.s, {super.key});
  @override
  State<SurahReader> createState() => _SurahReaderState();
}

class _SurahReaderState extends State<SurahReader> {
  double size = 28;
  @override
  void initState() {
    super.initState();
    size = Store.prefs.getDouble('mushaf_size') ?? 28;
    Store.prefs.setInt('mushaf_last', widget.s['n']);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.s['n'] as int;
    final ay = (widget.s['a'] as List).cast<String>();
    final spans = <InlineSpan>[];
    for (var i = 0; i < ay.length; i++) {
      spans.add(TextSpan(text: '${ay[i]} '));
      spans.add(TextSpan(text: '\u06DD${arabicDigits(i + 1)} ', style: const TextStyle(color: gold)));
    }
    return Scaffold(
      appBar: AppBar(title: Text('سورة ${surahs[n - 1]}'), actions: [
        IconButton(icon: const Icon(Icons.text_decrease), onPressed: () { setState(() => size = math.max(18, size - 2)); Store.prefs.setDouble('mushaf_size', size); }),
        IconButton(icon: const Icon(Icons.text_increase), onPressed: () { setState(() => size = math.min(48, size + 2)); Store.prefs.setDouble('mushaf_size', size); }),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (n != 1 && n != 9)
          Center(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', style: TextStyle(fontFamily: 'Amiri', fontSize: size + 2, color: gold)))),
        Text.rich(TextSpan(children: spans), textAlign: TextAlign.justify, style: TextStyle(fontFamily: 'Amiri', fontSize: size, height: 2.1)),
        const SizedBox(height: 24),
        const Center(child: Text('النص: المصحف العثماني (Tanzil / alquran.cloud)', style: TextStyle(fontSize: 11, color: Colors.white38))),
      ]),
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
        appBar: AppBar(title: const Text('الأذكار والأدعية', style: TextStyle(fontWeight: FontWeight.bold))),
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
                child: TextField(decoration: InputDecoration(hintText: 'ابحث عن ذكر أو دعاء', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))), onChanged: (v) => setState(() => q = v.trim())),
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
                      subtitle: Text('${(cat['items'] as List).length} ذكر'),
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
        IconButton(icon: const Icon(Icons.restart_alt), tooltip: 'إعادة العد', onPressed: () => setState(() => left = items.map((e) => countOf(e['c'])).toList())),
      ]),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: items.length,
        itemBuilder: (c, i) {
          final done = left[i] == 0;
          return Card(
            color: done ? const Color(0xFF123524) : navy,
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
                    Text(done ? 'تم' : 'اضغط للعد · المتبقي ${arabicDigits(left[i])}', style: const TextStyle(color: gold)),
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
      if (!await Geolocator.isLocationServiceEnabled()) throw 'فعّل الموقع (GPS) من إعدادات الهاتف';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'اسمح للتطبيق بالوصول إلى الموقع لتحديد القبلة';
      final p = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)));
      bearing = qiblaBearing(p.latitude, p.longitude);
      Store.prefs.setDouble('qibla', bearing!);
    } catch (e) {
      msg = e is String ? e : 'تعذّر تحديد الموقع';
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
        appBar: AppBar(title: const Text('اتجاه القبلة', style: TextStyle(fontWeight: FontWeight.bold))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: bearing == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.explore, color: gold, size: 80),
                    const SizedBox(height: 12),
                    const Text('لتحديد القبلة يحتاج التطبيق إلى موقعك (يبقى على جهازك فقط)', textAlign: TextAlign.center),
                    if (msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
                    const SizedBox(height: 16),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), onPressed: busy ? null : locate, child: Text(busy ? 'جاري التحديد...' : 'تحديد القبلة')),
                  ])
                : StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (c, snap) {
                      final h = snap.data?.heading;
                      final angle = h == null ? bearing! : (bearing! - h);
                      final aligned = h != null && ((angle % 360 + 360) % 360 < 4 || (angle % 360 + 360) % 360 > 356);
                      return Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('زاوية القبلة: ${arabicDigits(bearing!.round())}° من الشمال', style: const TextStyle(fontSize: 18, color: gold)),
                        const SizedBox(height: 24),
                        Stack(alignment: Alignment.center, children: [
                          Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: aligned ? Colors.greenAccent : gold, width: 3), color: navy)),
                          Transform.rotate(angle: angle * math.pi / 180, child: Icon(Icons.navigation, size: 190, color: aligned ? Colors.greenAccent : gold)),
                          const Positioned(top: 22, child: Text('🕋', style: TextStyle(fontSize: 22))),
                        ]),
                        const SizedBox(height: 20),
                        Text(h == null ? 'لا يوجد حساس بوصلة: وجّه الهاتف نحو الشمال ثم اتبع الزاوية' : (aligned ? 'أنت تواجه القبلة' : 'أدر الهاتف حتى يشير السهم لأعلى'), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton.icon(onPressed: busy ? null : locate, icon: const Icon(Icons.my_location), label: const Text('تحديث الموقع')),
                        if (msg != null) Text(msg!, style: const TextStyle(color: Colors.redAccent)),
                      ]);
                    },
                  ),
          ),
        ),
      );
}
