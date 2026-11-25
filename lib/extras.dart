import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'l10n.dart';
import 'features.dart';
import 'prayer.dart';

// ---------------- الأذان (تبويب) ----------------
class AdhanTab extends StatefulWidget {
  const AdhanTab({super.key});
  @override
  State<AdhanTab> createState() => _AdhanTabState();
}

class _AdhanTabState extends State<AdhanTab> {
  final _pl = AudioPlayer();
  int? _playing;
  String? _err;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _pl.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pl.dispose();
    super.dispose();
  }

  Future<void> pickCustom() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.audio);
      final path = r?.files.single.path;
      if (path == null) return;
      var name = r!.files.single.name;
      final dot = name.lastIndexOf('.');
      if (dot > 0) name = name.substring(0, dot);
      final dir = await getApplicationDocumentsDirectory();
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.mp3';
      final copy = await File(path).copy('${dir.path}/custom_adhan_${DateTime.now().millisecondsSinceEpoch}$ext');
      final ok = await PrayerService.setCustom(copy.path, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? tr('تم اعتماد «$name» كأذان مخصص') : tr('تعذر اعتماد الملف (يتطلب أندرويد ١٠ أو أحدث)'))));
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = tr('تعذر اختيار الملف: $e'));
    }
  }

  Future<void> previewCustom() async {
    final path = PrayerService.customPath;
    if (path == null) return;
    if (_playing == 100) {
      await _pl.stop();
      setState(() => _playing = null);
      return;
    }
    try {
      setState(() { _playing = 100; _err = null; });
      await _pl.setAudioSource(AudioSource.file(path, tag: MediaItem(id: 'adhan-custom', title: tr('أذان · ${PrayerService.customName}'), album: 'Muslim Plus')));
      _pl.play();
    } catch (e) {
      if (mounted) setState(() { _playing = null; _err = tr('تعذّر تشغيل الملف: $e'); });
    }
  }

  Future<void> pickForPrayer(int prayer) async {
    final cur = Store.prefs.getInt('pt_mz_$prayer');
    final r = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * .7,
        child: ListView(children: [
          Padding(padding: const EdgeInsets.all(14), child: Text(tr('أذان صلاة ${trp(prayerNames[prayer])}'), style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold))),
          ListTile(title: Text(tr('الأذان الافتراضي')), trailing: cur == null ? const Icon(Icons.check, color: gold) : null, onTap: () => Navigator.pop(c, -1)),
          if (PrayerService.hasCustom) ListTile(leading: const Icon(Icons.folder_special, color: gold), title: Text(tr('من هاتفي: ${PrayerService.customName}')), trailing: cur == 100 ? const Icon(Icons.check, color: gold) : null, onTap: () => Navigator.pop(c, 100)),
          for (var i = 0; i < kMuezzins.length; i++)
            ListTile(title: Text(tr(kMuezzins[i])), trailing: cur == i ? const Icon(Icons.check, color: gold) : null, onTap: () => Navigator.pop(c, i)),
        ]),
      ),
    );
    if (r == null) return;
    if (r == -1) {
      await Store.prefs.remove('pt_mz_$prayer');
    } else {
      await Store.prefs.setInt('pt_mz_$prayer', r);
    }
    setState(() {});
    await PrayerService.schedule();
  }

  Future<void> preview(int i) async {
    if (_playing == i) {
      await _pl.stop();
      setState(() => _playing = null);
      return;
    }
    final id = (i + 1).toString().padLeft(2, '0');
    try {
      setState(() { _playing = i; _err = null; });
      await _pl.setAudioSource(AudioSource.asset('assets/adhan/a$id.mp3', tag: MediaItem(id: 'adhan-$id', title: tr('أذان · ${tr(kMuezzins[i])}'), album: 'Muslim Plus')));
      await _pl.setVolume(1.0);
      _pl.play();
    } catch (e) {
      if (mounted) setState(() { _playing = null; _err = tr('تعذر تشغيل المقطع: $e'); });
    }
  }

  Future<void> choose(int i) async {
    await Store.prefs.setInt('mz', i);
    setState(() {});
    await PrayerService.askPermissions();
    await PrayerService.schedule();
  }

  @override
  Widget build(BuildContext context) {
    final sel = PrayerService.muezzin;
    final (ni, nt) = PrayerService.next();
    return Scaffold(
      appBar: AppBar(title: Text(tr('الأذان'), style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(icon: const Icon(Icons.tune), tooltip: tr('طريقة الحساب والمواقيت'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerSettings())).then((_) => setState(() {}))),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.access_time_filled, color: gold),
            title: Text(tr('الصلاة القادمة: ${trp(prayerNames[ni])} ${hm(nt)}')),
            subtitle: Text(tr('المؤذن: ${tr(kMuezzins[sel])} · ${PrayerService.method.name}')),
          ),
        ),
        Card(
          child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('أذان من ذاكرة الهاتف'), style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
            Text(PrayerService.hasCustom ? tr('الملف الحالي: ${PrayerService.customName}') : tr('لم تختر ملفا بعد. اختر ملف صوت (mp3 أو m4a أو ogg) من الهاتف.'), style: const TextStyle(fontSize: 13)),
            Wrap(spacing: 8, children: [
              TextButton.icon(icon: const Icon(Icons.folder_open, color: gold), label: Text(tr('اختيار ملف')), onPressed: pickCustom),
              if (PrayerService.hasCustom) TextButton.icon(icon: Icon(_playing == 100 ? Icons.stop_circle : Icons.play_circle_outline, color: gold), label: Text(_playing == 100 ? tr('إيقاف') : tr('استماع')), onPressed: previewCustom),
              if (PrayerService.hasCustom) TextButton.icon(icon: const Icon(Icons.done_all, color: gold), label: Text(tr('لكل الصلوات')), onPressed: () async {
                for (var k = 0; k < 5; k++) { await Store.prefs.setInt('pt_mz_$k', 100); }
                setState(() {});
                await PrayerService.schedule();
              }),
            ]),
            Text(tr('يعمل كصوت إشعار الأذان في الخلفية (أندرويد ١٠ أو أحدث).'), style: TextStyle(fontSize: 11)),
          ])),
        ),
        Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text(tr('الأذان لكل صلاة'), style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
        for (var k = 0; k < 5; k++)
          ListTile(
            leading: Switch(activeColor: gold, value: PrayerService.adhanOn(k), onChanged: (v) async { await Store.prefs.setBool('pt_adhan_$k', v); setState(() {}); await PrayerService.schedule(); }),
            title: Text(trp(prayerNames[k])),
            subtitle: Text(PrayerService.adhanOn(k) ? PrayerService.nameOf(PrayerService.muezzinFor(k)) : tr('الأذان متوقف')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => pickForPrayer(k),
          ),
        Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text(tr('اختر المؤذن الافتراضي (٣٠ مؤذنا)'), style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
        for (var i = 0; i < kMuezzins.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(color: i == sel ? gold.withValues(alpha: .15) : null, borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: i == sel ? gold : navy, child: Text(arabicDigits(i + 1), style: TextStyle(color: i == sel ? Colors.black : gold, fontSize: 12))),
              title: Text(tr(kMuezzins[i])),
              subtitle: i == sel ? Text(tr('الأذان الافتراضي (للصلوات التي لم تخصص لها أذانا)')) : null,
              onTap: () => choose(i),
              trailing: IconButton(
                icon: Icon(_playing == i ? Icons.stop_circle : Icons.play_circle_outline, color: gold),
                tooltip: _playing == i ? tr('إيقاف') : tr('استماع'),
                onPressed: () => preview(i),
              ),
            ),
          ),
        if (_err != null) Padding(padding: const EdgeInsets.all(8), child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
      ]),
    );
  }
}

// ---------------- حاسبة الزكاة ----------------
class ZakatResult {
  final double net, nisab, zakat;
  final bool due;
  ZakatResult(this.net, this.nisab, this.zakat, this.due);
}

/// الزكاة 2.5٪ من صافي المال إذا بلغ النصاب. النصاب 85 جراما ذهبا أو 595 جراما فضة (بسعر يدخله المستخدم).
ZakatResult computeZakat({required double cash, required double goldGrams, required double goldPrice, required double silverGrams, required double silverPrice, required double trade, required double debts, required bool silverNisab}) {
  final net = cash + goldGrams * goldPrice + silverGrams * silverPrice + trade - debts;
  final nisab = silverNisab ? 595 * silverPrice : 85 * goldPrice;
  final due = nisab > 0 && net >= nisab;
  return ZakatResult(net, nisab, due ? net * 0.025 : 0, due);
}

class ZakatPage extends StatefulWidget {
  const ZakatPage({super.key});
  @override
  State<ZakatPage> createState() => _ZakatPageState();
}

class _ZakatPageState extends State<ZakatPage> {
  final c = {for (final k in ['cash', 'goldg', 'goldp', 'silg', 'silp', 'trade', 'debt']) k: TextEditingController(text: Store.prefs.getString('z_$k') ?? '')};
  bool silver = false;
  ZakatResult? res;

  double v(String k) => double.tryParse(c[k]!.text.replaceAll(',', '.').trim().split('').map((d) { final u = d.codeUnitAt(0); return (u >= 0x660 && u <= 0x669) ? String.fromCharCode(u - 0x660 + 48) : d; }).join()) ?? 0;

  void calc() {
    for (final k in c.keys) { Store.prefs.setString('z_$k', c[k]!.text); }
    setState(() => res = computeZakat(cash: v('cash'), goldGrams: v('goldg'), goldPrice: v('goldp'), silverGrams: v('silg'), silverPrice: v('silp'), trade: v('trade'), debts: v('debt'), silverNisab: silver));
  }

  Widget field(String k, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(controller: c[k], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
      );

  String f(double x) => x.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('حاسبة الزكاة'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(tr('أدخل المبالغ بعملتك. أسعار الذهب والفضة تدخلها بنفسك من سعر اليوم.'), style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          field('cash', tr('النقود والمدخرات')),
          field('goldg', tr('الذهب (جرام)')),
          field('goldp', tr('سعر جرام الذهب')),
          field('silg', tr('الفضة (جرام)')),
          field('silp', tr('سعر جرام الفضة')),
          field('trade', tr('عروض التجارة')),
          field('debt', tr('الديون المستحقة عليك')),
          SwitchListTile(
            activeColor: gold,
            title: Text(tr('النصاب بالفضة (٥٩٥ جراما)')),
            subtitle: Text(silver ? tr('النصاب بالفضة (أقل)') : tr('النصاب بالذهب (٨٥ جراما)')),
            value: silver,
            onChanged: (x) => setState(() => silver = x),
          ),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), onPressed: calc, child: Text(tr('احسب الزكاة'))),
          if (res != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Card(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('صافي المال: ${f(res!.net)}')),
                    Text(tr('النصاب: ${res!.nisab > 0 ? f(res!.nisab) : 'أدخل سعر الجرام'}')),
                    const SizedBox(height: 6),
                    Text(res!.due ? tr('الزكاة الواجبة (٢٫٥٪): ${f(res!.zakat)}') : (res!.nisab > 0 ? tr('لم يبلغ النصاب: لا زكاة عليك الآن') : tr('أدخل سعر الذهب أو الفضة لتحديد النصاب')), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: gold)),
                    const SizedBox(height: 6),
                    Text(tr('تشترط الزكاة مرور حول هجري كامل على المال. الحاسبة مساعدة فقط؛ اسأل أهل العلم في مسائلك الخاصة.'), style: TextStyle(fontSize: 11)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

// ---------------- ختمة القرآن ----------------
class KhatmaPage extends StatefulWidget {
  const KhatmaPage({super.key});
  @override
  State<KhatmaPage> createState() => _KhatmaPageState();
}

class _KhatmaPageState extends State<KhatmaPage> {
  Set<int> done = {};
  int days = 30;
  DateTime? start;
  List? data;

  @override
  void initState() {
    super.initState();
    final p = Store.prefs;
    done = (jsonDecode(p.getString('kh_done') ?? '[]') as List).cast<int>().toSet();
    days = p.getInt('kh_days') ?? 30;
    final s = p.getString('kh_start');
    start = s == null ? null : DateTime.tryParse(s);
    QuranText.load().then((d) => mounted ? setState(() => data = d) : null);
  }

  void save() {
    final p = Store.prefs;
    p.setString('kh_done', jsonEncode(done.toList()));
    p.setInt('kh_days', days);
    if (start != null) p.setString('kh_start', start!.toIso8601String());
  }

  int ayahs(int n) => ((data![n - 1]['a'] as List).length);

  @override
  Widget build(BuildContext context) {
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: gold)));
    final total = data!.fold<int>(0, (a, s) => a + (s['a'] as List).length);
    final read = done.fold<int>(0, (a, n) => a + ayahs(n));
    final left = total - read;
    final elapsed = start == null ? 0 : DateTime.now().difference(start!).inDays;
    final daysLeft = (days - elapsed).clamp(1, 9999);
    final wird = (left / daysLeft).ceil();
    return Scaffold(
      appBar: AppBar(title: Text(tr('ختمة القرآن')), actions: [
        IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: tr('ختمة جديدة'),
            onPressed: () { setState(() { done = {}; start = DateTime.now(); }); save(); }),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('أنهيت ${arabicDigits(done.length)} من ١١٤ سورة (${arabicDigits((read * 100 / total).round())}٪)'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: read / total), duration: const Duration(milliseconds: 500), builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: gold, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 10),
              Row(children: [
                Text(tr('أريد الختم خلال ')),
                DropdownButton<int>(value: days, items: [for (final d in [7, 10, 15, 20, 30, 60, 90]) DropdownMenuItem(value: d, child: Text(tr('${arabicDigits(d)} يوما')))], onChanged: (v) { setState(() { days = v!; start ??= DateTime.now(); }); save(); }),
              ]),
              if (start != null) Text(tr('وردك اليومي المتبقي: ${arabicDigits(wird)} آية تقريبا (متبقي ${arabicDigits(daysLeft)} يوما)')),
              if (start == null) Text(tr('اختر المدة ثم علّم السور التي تقرؤها.'), style: TextStyle(fontSize: 12)),
            ]),
          ),
        ),
        for (var n = 1; n <= 114; n++)
          CheckboxListTile(
            activeColor: gold,
            value: done.contains(n),
            title: Text(tr('سورة ${trs(surahs[n - 1])}'), style: const TextStyle(fontFamily: 'Amiri', fontSize: 18)),
            subtitle: Text(tr('${arabicDigits(ayahs(n))} آية')),
            onChanged: (v) { setState(() { v! ? done.add(n) : done.remove(n); start ??= DateTime.now(); }); save(); },
          ),
      ]),
    );
  }
}

// ---------------- التحديث الإجباري (يتحكم فيه المالك فقط عبر catalog.json في مستودعه) ----------------
/// يفرض التحديث إذا كان min_build في catalog.json أكبر من رقم نسخة التطبيق.
bool updateRequired(Map catalog, int myBuild) => ((catalog['min_build'] ?? 0) as num) > myBuild;

/// يحمّل APK من الرابط الثابت (بلا تخزين مؤقت) ثم يفتح مثبّت أندرويد. أندرويد يطلب تأكيد المستخدم دائما.
Future<String?> downloadAndInstallApk(void Function(double?) onProgress) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/MuslimPlus-update.apk');
    if (file.existsSync()) file.deleteSync();
    final client = http.Client();
    final req = http.Request('GET', Uri.parse('$kApkUrl?t=${DateTime.now().millisecondsSinceEpoch}'))..headers['Cache-Control'] = 'no-cache';
    final resp = await client.send(req);
    if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';
    final total = resp.contentLength ?? 0;
    var got = 0;
    final sink = file.openWrite();
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
    client.close();
    if (got < 5 * 1024 * 1024) throw 'incomplete download ($got bytes)';
    onProgress(1);
    final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (r.type != ResultType.done) return tr('تعذّر فتح المثبّت: ${r.message}');
    return null;
  } catch (e) {
    return '${tr('تعذّر التحميل. تأكد من الإنترنت وحاول مرة أخرى.')}';
  }
}

class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool blocked = false;
  bool downloading = false;
  double? progress;
  String? msg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    try {
      final bytes = await fetchCatalogBytes(seconds: 10);
      {
        final remote = jsonDecode(utf8.decode(bytes)) as Map;
        final min = ((remote['min_build'] ?? 0) as num).toInt();
        final p = await SharedPreferences.getInstance();
        await p.setInt('min_build', min);
      }
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    final need = (p.getInt('min_build') ?? 0) > kAppBuild;
    if (mounted && need != blocked) setState(() => blocked = need);
  }

  Future<void> update() async {
    setState(() { downloading = true; progress = 0; msg = null; });
    final err = await downloadAndInstallApk((p) { if (mounted) setState(() => progress = p); });
    if (mounted) setState(() { msg = err ?? tr('اكتمل التحميل. اضغط "تثبيت" في النافذة التي ستظهر. إذا طلب الهاتف السماح بالتثبيت من هذا التطبيق، فعّل الخيار ثم ارجع.'); downloading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (!blocked) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: PopScope(
          canPop: false,
          child: Material(
            color: const Color(0xFF083F44),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.system_update, color: gold, size: 72),
                    const SizedBox(height: 16),
                    Text(tr('تحديث مطلوب'), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(tr('يوجد إصدار جديد من التطبيق. يجب التحديث لمتابعة الاستخدام.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 22),
                    if (downloading || progress != null) LinearProgressIndicator(value: progress, color: gold, backgroundColor: Colors.white24, minHeight: 8),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, minimumSize: const Size(200, 48)),
                      onPressed: downloading ? null : update,
                      icon: const Icon(Icons.download),
                      label: Text(downloading ? tr('جاري التحميل...') : (progress == 1 ? tr('تثبيت التحديث') : tr('تحديث الآن'))),
                    ),
                    if (msg != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(msg!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
