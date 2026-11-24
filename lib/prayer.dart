import 'dart:async';
import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'main.dart';
import 'features.dart';
import 'ai.dart';

const tealA = Color(0xFF0E7C7B);
const tealB = Color(0xFF0A4F55);
const mint = Color(0xFF13A78F);

const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const prayerIcons = [Icons.nights_stay_outlined, Icons.wb_sunny_outlined, Icons.wb_twilight, Icons.nightlight_round, Icons.dark_mode_outlined];

class MethodInfo {
  final String id, name, where;
  final CalculationMethod m;
  const MethodInfo(this.id, this.name, this.where, this.m);
}

const kMethods = [
  MethodInfo('umm', 'أم القرى (مكة المكرمة)', 'السعودية', CalculationMethod.umm_al_qura),
  MethodInfo('egy', 'الهيئة المصرية العامة للمساحة', 'مصر', CalculationMethod.egyptian),
  MethodInfo('mwl', 'رابطة العالم الإسلامي', 'أوروبا ودول كثيرة', CalculationMethod.muslim_world_league),
  MethodInfo('khi', 'جامعة العلوم الإسلامية بكراتشي', 'باكستان والهند وبنجلاديش', CalculationMethod.karachi),
  MethodInfo('dxb', 'منطقة الخليج', 'الإمارات', CalculationMethod.dubai),
  MethodInfo('kwt', 'الكويت', 'الكويت', CalculationMethod.kuwait),
  MethodInfo('qat', 'قطر', 'قطر', CalculationMethod.qatar),
  MethodInfo('sgp', 'سنغافورة', 'سنغافورة وماليزيا وإندونيسيا', CalculationMethod.singapore),
  MethodInfo('tur', 'رئاسة الشؤون الدينية (ديانت)', 'تركيا', CalculationMethod.turkey),
  MethodInfo('teh', 'معهد الجيوفيزياء بجامعة طهران', 'إيران', CalculationMethod.tehran),
  MethodInfo('isna', 'الجمعية الإسلامية لأمريكا الشمالية', 'أمريكا وكندا', CalculationMethod.north_america),
  MethodInfo('moon', 'لجنة رؤية الهلال', 'بريطانيا وغيرها', CalculationMethod.moon_sighting_committee),
];

String guessMethod(double lat, double lon) {
  bool box(double a, double b, double c, double d) => lat >= a && lat <= b && lon >= c && lon <= d;
  if (box(28.5, 30.2, 46.5, 48.6)) return 'kwt';
  if (box(24.4, 26.3, 50.6, 51.8)) return 'qat';
  if (box(22.5, 26.2, 51.6, 56.5)) return 'dxb';
  if (box(16, 32.2, 34.5, 55.7)) return 'umm';
  if (box(22, 31.8, 24.7, 34.3)) return 'egy';
  if (box(25, 40, 44, 63.5)) return 'teh';
  if (box(35.8, 42.2, 26, 45)) return 'tur';
  if (box(5, 37, 60, 93)) return 'khi';
  if (box(-11, 7.5, 95, 120)) return 'sgp';
  if (box(15, 72, -170, -50)) return 'isna';
  return 'mwl';
}

String hm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
}

String hmsLeft(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0 && m == 0) return 'أقل من دقيقة';
  return '${h > 0 ? '${arabicDigits(h)} س ' : ''}${arabicDigits(m)} د';
}

String hijriNow() {
  HijriCalendar.setLocal('ar');
  final h = HijriCalendar.now();
  return '${arabicDigits(h.hDay)} ${h.longMonthName} ${arabicDigits(h.hYear)} هـ';
}

class PrayerService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool ready = false;
  static double lat = 30.0444, lon = 31.2357; // القاهرة افتراضيا حتى يتحدد الموقع
  static bool located = false;

  static void loadPrefs() {
    final p = Store.prefs;
    final a = p.getDouble('pt_lat'), b = p.getDouble('pt_lon');
    if (a != null && b != null) { lat = a; lon = b; located = true; }
  }

  static MethodInfo get method {
    final id = Store.prefs.getString('pt_method') ?? guessMethod(lat, lon);
    return kMethods.firstWhere((m) => m.id == id, orElse: () => kMethods[2]);
  }

  static bool get hanafi => Store.prefs.getBool('pt_hanafi') ?? false;
  static bool adhanOn(int i) => Store.prefs.getBool('pt_adhan_$i') ?? true;

  static PrayerTimes timesFor(DateTime day) {
    final params = method.m.getParameters();
    params.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    if (method.id == 'umm') {
      HijriCalendar.setLocal('ar');
      final h = HijriCalendar.fromDate(day);
      if (h.hMonth == 9) params.ishaInterval = 120; // رمضان: العشاء بعد المغرب بساعتين
    }
    return PrayerTimes(Coordinates(lat, lon), DateComponents.from(day), params);
  }

  static List<DateTime> five(PrayerTimes t) => [t.fajr, t.dhuhr, t.asr, t.maghrib, t.isha];

  /// (index, time) للصلاة القادمة
  static (int, DateTime) next() {
    final now = DateTime.now();
    final t = five(timesFor(now));
    for (var i = 0; i < 5; i++) {
      if (t[i].isAfter(now)) return (i, t[i]);
    }
    return (0, timesFor(now.add(const Duration(days: 1))).fajr);
  }

  static Future<bool> locate({bool force = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
      final p = (force ? null : await Geolocator.getLastKnownPosition()) ??
          await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)));
      lat = p.latitude; lon = p.longitude; located = true;
      await Store.prefs.setDouble('pt_lat', lat);
      await Store.prefs.setDouble('pt_lon', lon);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> init() async {
    if (ready) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.createNotificationChannel(const AndroidNotificationChannel('adhan_v1', 'الأذان',
        description: 'أذان عند دخول وقت الصلاة', importance: Importance.max, playSound: true, sound: RawResourceAndroidNotificationSound('adhan')));
    ready = true;
  }

  static NotificationDetails get details => const NotificationDetails(
      android: AndroidNotificationDetails('adhan_v1', 'الأذان',
          channelDescription: 'أذان عند دخول وقت الصلاة',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('adhan'),
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public));

  static Future<void> askPermissions() async {
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
    await a?.requestExactAlarmsPermission();
  }

  static Future<void> test() async {
    await init();
    await plugin.show(999, 'تجربة الأذان', 'هكذا يصلك الأذان عند دخول الوقت', details);
  }

  /// يجدول أذان الأيام الستة القادمة. يُستدعى عند كل فتح للتطبيق وعند تغيير الإعدادات.
  static Future<int> schedule() async {
    await init();
    await plugin.cancelAll();
    final now = DateTime.now();
    var n = 0;
    for (var d = 0; d < 6; d++) {
      final t = five(timesFor(now.add(Duration(days: d))));
      for (var i = 0; i < 5; i++) {
        if (!adhanOn(i) || !t[i].isAfter(now)) continue;
        final when = tz.TZDateTime.from(t[i], tz.UTC);
        for (final mode in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
          try {
            await plugin.zonedSchedule(d * 10 + i, 'حان الآن وقت صلاة ${prayerNames[i]}', 'حسب ${method.name}', when, details,
                androidScheduleMode: mode, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
            n++;
            break;
          } catch (_) {}
        }
      }
    }
    return n;
  }
}

// ---------------- الرئيسية ----------------
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    PrayerService.loadPrefs();
    timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    () async {
      await PrayerService.init();
      if (!PrayerService.located || Store.prefs.getBool('pt_asked') != true) {
        await Store.prefs.setBool('pt_asked', true);
        await PrayerService.askPermissions();
        if (await PrayerService.locate() && mounted) setState(() {});
      }
      await PrayerService.schedule();
    }();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) { if (mounted) setState(() {}); });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final times = PrayerService.five(PrayerService.timesFor(now));
    final (ni, nt) = PrayerService.next();
    final left = nt.difference(now);
    final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final features = <(IconData, String, Widget)>[
      (Icons.headphones, 'التلاوات', const RecitersTab()),
      (Icons.menu_book, 'المصحف', const MushafTab()),
      (Icons.favorite_border, 'الأذكار', const AdhkarTab()),
      (Icons.explore, 'القبلة', const QiblaTab()),
      (Icons.radio_button_checked, 'التسبيح', const TasbihPage()),
      (Icons.access_time, 'الساعة', const ClockPage()),
      (Icons.auto_awesome, 'اسأل', const AiTab()),
      (Icons.notifications_active, 'الأذان والمواقيت', const PrayerSettings()),
    ];
    return Scaffold(
      backgroundColor: tealB,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tealA, tealB])),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 14),
          child: Column(children: [
            Row(children: [
              Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(PrayerService.located ? 'موقعك الحالي · ${PrayerService.method.name}' : 'القاهرة (افتراضي) · ${PrayerService.method.name}', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white70), onPressed: () => open(const Settings())),
            ]),
            Text(hijriNow(), style: const TextStyle(color: gold, fontSize: 15)),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${arabicDigits(h12).padLeft(1)}:${arabicDigits(now.minute).padLeft(2, '٠')}', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
                Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(':${arabicDigits(now.second).padLeft(2, '٠')} ${now.hour < 12 ? 'ص' : 'م'}', style: const TextStyle(color: Colors.white60, fontSize: 18))),
              ]),
            ),
            Text('${prayerNames[ni]} بعد ${hmsLeft(left)}', style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (var i = 0; i < 5; i++)
                Column(children: [
                  Text(prayerNames[i], style: TextStyle(color: i == ni ? gold : Colors.white70, fontSize: 12, fontWeight: i == ni ? FontWeight.bold : FontWeight.normal)),
                  const SizedBox(height: 4),
                  Icon(prayerIcons[i], color: i == ni ? gold : Colors.white70, size: 22),
                  const SizedBox(height: 4),
                  Text(hm(times[i]).split(' ')[0], style: TextStyle(color: i == ni ? gold : Colors.white, fontSize: 12)),
                ]),
            ]),
          ]),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFFF4F1EA), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('كل المميزات', style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 8,
                  childAspectRatio: .85,
                  children: [
                    for (final f in features)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => open(f.$3),
                        child: Column(children: [
                          Container(width: 56, height: 56, decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(16)), child: Icon(f.$1, color: Colors.white, size: 28)),
                          const SizedBox(height: 6),
                          Text(f.$2, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 11.5), maxLines: 2),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: mint),
                    title: const Text('أذكار الصباح والمساء', style: TextStyle(color: Colors.black87)),
                    subtitle: const Text('اضغط للبدء', style: TextStyle(color: Colors.black45)),
                    onTap: () => open(const AdhkarTab()),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------- إعدادات الأذان ----------------
class PrayerSettings extends StatefulWidget {
  const PrayerSettings({super.key});
  @override
  State<PrayerSettings> createState() => _PrayerSettingsState();
}

class _PrayerSettingsState extends State<PrayerSettings> {
  String? msg;
  bool busy = false;

  Future<void> resched() async {
    final n = await PrayerService.schedule();
    if (mounted) setState(() => msg = 'تمت جدولة $n أذان للأيام القادمة');
  }

  @override
  Widget build(BuildContext context) {
    final cur = PrayerService.method;
    final p = Store.prefs;
    final today = PrayerService.five(PrayerService.timesFor(DateTime.now()));
    return Scaffold(
      appBar: AppBar(title: const Text('الأذان والمواقيت')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.my_location, color: gold),
            title: Text(PrayerService.located ? 'تم تحديد موقعك' : 'الموقع غير محدد (القاهرة افتراضيا)'),
            subtitle: const Text('الموقع يبقى على جهازك فقط ويُستخدم لحساب المواقيت'),
            trailing: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: () async {
              setState(() => busy = true);
              await PrayerService.askPermissions();
              final ok = await PrayerService.locate(force: true);
              if (ok && p.getString('pt_method') == null) { /* الطريقة تتبع الموقع تلقائيا */ }
              await PrayerService.schedule();
              if (mounted) setState(() { busy = false; msg = ok ? 'تم تحديث الموقع' : 'تعذّر تحديد الموقع، فعّل GPS واسمح بالإذن'; });
            },
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text('طريقة الحساب (التقويم المعتمد)', style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
        if (p.getString('pt_method') == null) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('مختارة تلقائيا حسب موقعك: ${cur.name}', style: const TextStyle(fontSize: 12, color: Colors.white70))),
        for (final m in kMethods)
          RadioListTile<String>(
            value: m.id,
            groupValue: cur.id,
            activeColor: gold,
            title: Text(m.name),
            subtitle: Text(m.where, style: const TextStyle(fontSize: 12)),
            onChanged: (v) async { await p.setString('pt_method', v!); setState(() {}); await resched(); },
          ),
        SwitchListTile(
          activeColor: gold,
          title: const Text('العصر بالمذهب الحنفي'),
          subtitle: const Text('الظل مثلان بدل مثل واحد'),
          value: PrayerService.hanafi,
          onChanged: (v) async { await p.setBool('pt_hanafi', v); setState(() {}); await resched(); },
        ),
        const Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text('الأذان لكل صلاة', style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
        for (var i = 0; i < 5; i++)
          SwitchListTile(
            activeColor: gold,
            title: Text('${prayerNames[i]}  ·  ${hm(today[i])}'),
            value: PrayerService.adhanOn(i),
            onChanged: (v) async { await p.setBool('pt_adhan_$i', v); setState(() {}); await resched(); },
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 8, children: [
            FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), onPressed: () async { await PrayerService.askPermissions(); await PrayerService.test(); }, child: const Text('تجربة صوت الأذان')),
            OutlinedButton(onPressed: () async { await PrayerService.askPermissions(); await resched(); }, child: const Text('السماح بالإشعارات والمنبهات')),
          ]),
        ),
        if (msg != null) Padding(padding: const EdgeInsets.all(8), child: Text(msg!, style: const TextStyle(color: Colors.white70))),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('إذا لم يصلك الأذان في وقته: اسمح بالإشعارات والمنبهات الدقيقة، واستثنِ التطبيق من توفير البطارية من إعدادات الهاتف. صوت الأذان من تسجيل الحرم المكي (archive.org، ملك عام).', style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
      ]),
    );
  }
}

// ---------------- التسبيح ----------------
class TasbihPage extends StatefulWidget {
  const TasbihPage({super.key});
  @override
  State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage> {
  static const phrases = ['سبحان الله', 'الحمد لله', 'الله أكبر', 'لا إله إلا الله', 'أستغفر الله', 'اللهم صل وسلم على نبينا محمد', 'سبحان الله وبحمده'];
  static const targets = [33, 99, 100, 0];
  int phrase = 0, target = 33, count = 0, total = 0;

  @override
  void initState() {
    super.initState();
    final p = Store.prefs;
    phrase = p.getInt('tz_phrase') ?? 0;
    target = p.getInt('tz_target') ?? 33;
    count = p.getInt('tz_count') ?? 0;
    final day = DateTime.now().toIso8601String().substring(0, 10);
    total = p.getString('tz_day') == day ? (p.getInt('tz_total') ?? 0) : 0;
  }

  void save() {
    final p = Store.prefs;
    p.setInt('tz_phrase', phrase);
    p.setInt('tz_target', target);
    p.setInt('tz_count', count);
    p.setString('tz_day', DateTime.now().toIso8601String().substring(0, 10));
    p.setInt('tz_total', total);
  }

  void tap() {
    setState(() { count++; total++; });
    if (target > 0 && count >= target) {
      HapticFeedback.heavyImpact();
      setState(() => count = 0);
    } else {
      HapticFeedback.selectionClick();
    }
    save();
  }

  @override
  Widget build(BuildContext context) {
    final prog = target == 0 ? 0.0 : count / target;
    return Scaffold(
      appBar: AppBar(title: const Text('التسبيح'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => count = 0); save(); })]),
      body: Column(children: [
        SizedBox(
          height: 56,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
            for (var i = 0; i < phrases.length; i++)
              Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(phrases[i]), selected: i == phrase, selectedColor: gold.withValues(alpha: .3), onSelected: (_) { setState(() { phrase = i; count = 0; }); save(); })),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final t in targets)
            Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(t == 0 ? 'مفتوح' : arabicDigits(t)), selected: t == target, selectedColor: gold.withValues(alpha: .3), onSelected: (_) { setState(() { target = t; count = 0; }); save(); })),
        ]),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(phrases[phrase], style: const TextStyle(fontSize: 26, color: gold, fontFamily: 'Amiri'), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: tap,
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 250, height: 250, child: CircularProgressIndicator(value: target == 0 ? 1 : prog, strokeWidth: 10, color: gold, backgroundColor: Colors.white12)),
                    Container(width: 214, height: 214, decoration: const BoxDecoration(shape: BoxShape.circle, color: mint), alignment: Alignment.center, child: Text(arabicDigits(count), style: const TextStyle(fontSize: 76, color: Colors.white, fontWeight: FontWeight.bold))),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text('إجمالي اليوم: ${arabicDigits(total)}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------- الساعة ----------------
class ClockPage extends StatefulWidget {
  const ClockPage({super.key});
  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  static const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (ni, nt) = PrayerService.next();
    return Scaffold(
      appBar: AppBar(title: const Text('الساعة')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 280, height: 280, child: CustomPaint(painter: ClockPainter(now))),
          const SizedBox(height: 20),
          Text('${arabicDigits(now.hour % 12 == 0 ? 12 : now.hour % 12)}:${arabicDigits(now.minute).padLeft(2, '٠')}:${arabicDigits(now.second).padLeft(2, '٠')} ${now.hour < 12 ? 'ص' : 'م'}', style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${days[now.weekday - 1]} ${arabicDigits(now.day)}/${arabicDigits(now.month)}/${arabicDigits(now.year)}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
          Text(hijriNow(), style: const TextStyle(fontSize: 16, color: gold)),
          const SizedBox(height: 14),
          Text('${prayerNames[ni]} بعد ${hmsLeft(nt.difference(now))}', style: const TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}

class ClockPainter extends CustomPainter {
  final DateTime t;
  ClockPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 4;
    c.drawCircle(ctr, r, Paint()..color = tealA);
    c.drawCircle(ctr, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = gold);
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final big = i % 5 == 0;
      final p1 = ctr + Offset(math.sin(a), -math.cos(a)) * (r - (big ? 16 : 8));
      final p2 = ctr + Offset(math.sin(a), -math.cos(a)) * (r - 3);
      c.drawLine(p1, p2, Paint()..color = big ? Colors.white : Colors.white38..strokeWidth = big ? 3 : 1.2);
    }
    void hand(double ang, double len, double w, Color col) => c.drawLine(ctr, ctr + Offset(math.sin(ang), -math.cos(ang)) * len, Paint()..color = col..strokeWidth = w..strokeCap = StrokeCap.round);
    hand((t.hour % 12 + t.minute / 60) * math.pi / 6, r * .5, 6, Colors.white);
    hand((t.minute + t.second / 60) * math.pi / 30, r * .75, 4, Colors.white);
    hand(t.second * math.pi / 30, r * .85, 2, gold);
    c.drawCircle(ctr, 6, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(ClockPainter o) => o.t != t;
}
