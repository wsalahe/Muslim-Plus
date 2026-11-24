import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

const int kAppBuild = 1;
const String kRepo = 'wsalahe/Quran-kareem';
const String kCatalogUrl = 'https://raw.githubusercontent.com/$kRepo/main/catalog.json';
const String kApkUrl = 'https://github.com/$kRepo/releases/download/app-latest/QuranKareem.apk';
const gold = Color(0xFFD4AF37);
const navy = Color(0xFF0F2648);
const navyDark = Color(0xFF081628);

const surahs = ['الفاتحة','البقرة','آل عمران','النساء','المائدة','الأنعام','الأعراف','الأنفال','التوبة','يونس','هود','يوسف','الرعد','إبراهيم','الحجر','النحل','الإسراء','الكهف','مريم','طه','الأنبياء','الحج','المؤمنون','النور','الفرقان','الشعراء','النمل','القصص','العنكبوت','الروم','لقمان','السجدة','الأحزاب','سبأ','فاطر','يس','الصافات','ص','الزمر','غافر','فصلت','الشورى','الزخرف','الدخان','الجاثية','الأحقاف','محمد','الفتح','الحجرات','ق','الذاريات','الطور','النجم','القمر','الرحمن','الواقعة','الحديد','المجادلة','الحشر','الممتحنة','الصف','الجمعة','المنافقون','التغابن','الطلاق','التحريم','الملك','القلم','الحاقة','المعارج','نوح','الجن','المزمل','المدثر','القيامة','الإنسان','المرسلات','النبأ','النازعات','عبس','التكوير','الانفطار','المطففين','الانشقاق','البروج','الطارق','الأعلى','الغاشية','الفجر','البلد','الشمس','الليل','الضحى','الشرح','التين','العلق','القدر','البينة','الزلزلة','العاديات','القارعة','التكاثر','العصر','الهمزة','الفيل','قريش','الماعون','الكوثر','الكافرون','النصر','المسد','الإخلاص','الفلق','الناس'];

String pad(int n) => n.toString().padLeft(3, '0');
String keyOf(Map x) => '${pad(x['n'])}${(x['p'] ?? 0) > 0 ? '_p${x['p']}' : ''}';
String titleOf(Map x) => 'سورة ${surahs[x['n'] - 1]}${(x['p'] ?? 0) > 0 ? ' - جزء ${x['p']}' : ''}';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuranApp());
}

class Store {
  static late Directory dir;
  static late SharedPreferences prefs;
  static Map<String, dynamic> catalog = {};
  static Future<void> init() async {
    dir = await getApplicationDocumentsDirectory();
    prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('catalog');
    if (saved != null) {
      catalog = jsonDecode(saved);
    } else {
      catalog = jsonDecode(await rootBundle.loadString('assets/catalog.json'));
    }
    // asset catalog may be newer after an app update
    final asset = jsonDecode(await rootBundle.loadString('assets/catalog.json'));
    if ((asset['catalog_version'] ?? 0) > (catalog['catalog_version'] ?? 0)) catalog = asset;
  }
  static Future<bool> refresh() async {
    try {
      final r = await http.get(Uri.parse(kCatalogUrl)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return false;
      final remote = jsonDecode(utf8.decode(r.bodyBytes));
      if ((remote['catalog_version'] ?? 0) > (catalog['catalog_version'] ?? 0)) {
        catalog = remote;
        await prefs.setString('catalog', utf8.decode(r.bodyBytes));
        return true;
      }
    } catch (_) {}
    return false;
  }
  static List get sheikhs => (catalog['sheikhs'] ?? []) as List;
  static File fileFor(String sheikhId, Map x) => File('${dir.path}/$sheikhId/${keyOf(x)}.mp4');
  static bool has(String sheikhId, Map x) => fileFor(sheikhId, x).existsSync();
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'القرآن الكريم',
        locale: const Locale('ar'),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: navyDark,
          colorScheme: const ColorScheme.dark(primary: gold, surface: navy),
          appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: gold, centerTitle: true),
          cardTheme: CardTheme(color: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: gold, width: .6))),
        ),
        home: FutureBuilder(
          future: Store.init(),
          builder: (c, s) => s.connectionState == ConnectionState.done ? const Home() : const Splash(),
        ),
      );
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Image.asset('assets/logo.jpg', width: 200))));
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
    Store.refresh().then((changed) { if (changed && mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final list = Store.sheikhs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const Settings())); setState(() {}); })],
      ),
      body: list.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد تلاوات بعد. افتح الإعدادات واضغط "التحقق من التحديثات".', textAlign: TextAlign.center)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (c, i) {
                final s = list[i];
                final n = (s['surahs'] as List).length;
                final d = (s['surahs'] as List).where((x) => Store.has(s['id'], x)).length;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: const Icon(Icons.folder, color: gold, size: 38),
                    title: Text(s['name'], style: const TextStyle(fontSize: 18, color: gold)),
                    subtitle: Text('$n سورة · محمّلة: $d'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => SheikhPage(s))); setState(() {}); },
                  ),
                );
              }),
    );
  }
}

class SheikhPage extends StatefulWidget {
  final Map s;
  const SheikhPage(this.s, {super.key});
  @override
  State<SheikhPage> createState() => _SheikhPageState();
}

class _SheikhPageState extends State<SheikhPage> {
  final Map<String, double> progress = {};
  bool allBusy = false;

  Future<void> download(Map x) async {
    final n = keyOf(x);
    if (progress.containsKey(n)) return;
    setState(() => progress[n] = 0);
    final f = Store.fileFor(widget.s['id'], x);
    try {
      await f.parent.create(recursive: true);
      final req = http.Request('GET', Uri.parse(x['url']));
      final resp = await http.Client().send(req);
      if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';
      final tmp = File('${f.path}.part');
      final sink = tmp.openWrite();
      int got = 0;
      final total = resp.contentLength ?? (x['size'] ?? 1);
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (mounted) setState(() => progress[n] = got / total);
      }
      await sink.close();
      await tmp.rename(f.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر التحميل: تأكد من الإنترنت')));
    }
    if (mounted) setState(() => progress.remove(n));
  }

  Future<void> downloadAll() async {
    setState(() => allBusy = true);
    for (final x in widget.s['surahs']) {
      if (!allBusy || !mounted) break;
      if (!Store.has(widget.s['id'], x)) await download(x);
    }
    if (mounted) setState(() => allBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.s['surahs'] as List;
    return Scaffold(
      appBar: AppBar(title: Text(widget.s['name'], style: const TextStyle(fontSize: 16)), actions: [
        IconButton(
          tooltip: 'تحميل الكل',
          icon: Icon(allBusy ? Icons.stop_circle : Icons.download_for_offline),
          onPressed: () => allBusy ? setState(() => allBusy = false) : downloadAll(),
        )
      ]),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (c, i) {
          final x = list[i];
          final n = x['n'] as int;
          final have = Store.has(widget.s['id'], x);
          final p = progress[keyOf(x)];
          return ListTile(
            leading: CircleAvatar(backgroundColor: navy, child: Text('$n', style: const TextStyle(color: gold))),
            title: Text(titleOf(x)),
            subtitle: p != null ? LinearProgressIndicator(value: p, color: gold) : Text(have ? 'محمّلة · تعمل بدون إنترنت' : 'غير محمّلة'),
            trailing: have
                ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await Store.fileFor(widget.s['id'], x).delete(); setState(() {}); })
                : IconButton(icon: const Icon(Icons.download, color: gold), onPressed: () => download(x)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Player(widget.s, x))).then((_) => setState(() {})),
          );
        },
      ),
    );
  }
}

class Player extends StatefulWidget {
  final Map s, x;
  const Player(this.s, this.x, {super.key});
  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  VideoPlayerController? c;
  bool video = false;
  String? err;

  @override
  void initState() {
    super.initState();
    video = Store.prefs.getBool('video') ?? false;
    _init();
  }

  Future<void> _init() async {
    final f = Store.fileFor(widget.s['id'], widget.x);
    try {
      c = f.existsSync() ? VideoPlayerController.file(f) : VideoPlayerController.networkUrl(Uri.parse(widget.x['url']));
      await c!.initialize();
      c!.addListener(() { if (mounted) setState(() {}); });
      await c!.play();
    } catch (e) {
      err = 'تعذّر التشغيل. حمّل السورة أو تأكد من الإنترنت.';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() { c?.dispose(); super.dispose(); }

  String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ready = c != null && c!.value.isInitialized;
    return Scaffold(
      appBar: AppBar(title: Text(titleOf(widget.x))),
      body: Column(children: [
        Expanded(
          child: Center(
            child: err != null
                ? Text(err!)
                : !ready
                    ? const CircularProgressIndicator(color: gold)
                    : video
                        ? AspectRatio(aspectRatio: c!.value.aspectRatio, child: VideoPlayer(c!))
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/logo.jpg', width: 240)),
                            const SizedBox(height: 20),
                            Text(titleOf(widget.x), style: const TextStyle(fontSize: 26, color: gold)),
                            Text(widget.s['name'], textAlign: TextAlign.center),
                          ]),
          ),
        ),
        if (ready) ...[
          Slider(
            activeColor: gold,
            value: c!.value.position.inMilliseconds.clamp(0, c!.value.duration.inMilliseconds).toDouble(),
            max: c!.value.duration.inMilliseconds.toDouble(),
            onChanged: (v) => c!.seekTo(Duration(milliseconds: v.toInt())),
          ),
          Text('${fmt(c!.value.position)} / ${fmt(c!.value.duration)}'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(iconSize: 34, icon: const Icon(Icons.replay_10), onPressed: () => c!.seekTo(c!.value.position - const Duration(seconds: 10))),
            IconButton(iconSize: 64, color: gold, icon: Icon(c!.value.isPlaying ? Icons.pause_circle : Icons.play_circle), onPressed: () => c!.value.isPlaying ? c!.pause() : c!.play()),
            IconButton(iconSize: 34, icon: const Icon(Icons.forward_10), onPressed: () => c!.seekTo(c!.value.position + const Duration(seconds: 10))),
          ]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('صوت'), icon: Icon(Icons.headphones)), ButtonSegment(value: true, label: Text('فيديو'), icon: Icon(Icons.videocam))],
              selected: {video},
              onSelectionChanged: (v) { Store.prefs.setBool('video', v.first); setState(() => video = v.first); },
            ),
          ),
        ],
        const SizedBox(height: 12),
      ]),
    );
  }
}

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String status = 'اضغط للتحقق من آخر تحديث على GitHub';
  bool busy = false;
  bool appUpdate = false;

  Future<void> check() async {
    setState(() { busy = true; status = 'جاري التحقق...'; });
    try {
      final r = await http.get(Uri.parse(kCatalogUrl)).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      final remote = jsonDecode(utf8.decode(r.bodyBytes));
      final newCat = (remote['catalog_version'] ?? 0) > (Store.catalog['catalog_version'] ?? 0);
      appUpdate = (remote['app_build'] ?? 1) > kAppBuild;
      if (newCat) {
        Store.catalog = remote;
        await Store.prefs.setString('catalog', utf8.decode(r.bodyBytes));
      }
      status = (newCat || appUpdate)
          ? '${newCat ? 'تم تحديث قائمة التلاوات. ' : ''}${appUpdate ? 'يوجد تحديث جديد للتطبيق.' : ''}'
          : 'أنت على آخر إصدار.';
    } catch (e) {
      status = 'تعذّر التحقق. تأكد من الإنترنت.';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            const Icon(Icons.system_update, color: gold, size: 40),
            const SizedBox(height: 8),
            Text(status, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), onPressed: busy ? null : check, child: const Text('التحقق من التحديثات')),
            if (appUpdate) ...[
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => launchUrl(Uri.parse(kApkUrl), mode: LaunchMode.externalApplication), child: const Text('تحميل التحديث الجديد للتطبيق')),
            ],
          ]))),
          const SizedBox(height: 12),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('الإصدار 1.0 · التطبيق يعمل بدون تسجيل دخول. السور المحمّلة تعمل بدون إنترنت.'))),
        ]),
      );
}
