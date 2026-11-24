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
import 'extras.dart';

const tealA = Color(0xFF0E7C7B);
const tealB = Color(0xFF0A4F55);
const mint = Color(0xFF13A78F);

const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
const prayerIcons = [Icons.nights_stay_outlined, Icons.wb_sunny_outlined, Icons.wb_twilight, Icons.nightlight_round, Icons.dark_mode_outlined];

const kMuezzins = [
  'أحمد العمادي',
  'ماجد الحمداني',
  'مشاري العفاسي (الفجر)',
  'مختار الحاج سليمان',
  'ناصر القطامي',
  'عبد المجيد السريحي',
  'عبد الملك الملا (مكة)',
  'عبد الملك النعمان',
  'فيصل عبد الملك النعمان',
  'عبد المطلب نجدي',
  'كامل نجدي',
  'عبد الرحمن خاشقجي',
  'عبد العزيز بخاري',
  'عصام بخاري',
  'عمر يوسف كمال',
  'ماجد حكيم',
  'محمد ماجد حكيم',
  'حسن عبد الستار',
  'حسين رجب',
  'حسين عفيفي',
  'سامي ديولي',
  'عبد الباسط (القاهرة)',
  'الحصري (القاهرة)',
  'محمد البنا (القاهرة)',
  'الشعيشع (القاهرة)',
  'ناجي قزاز (المسجد الأقصى)',
  'يوسف إسلام',
  'زياد باتيل',
  'الحرم المكي (الفجر)',
  'الحرم المكي',
];

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
    await a?.deleteNotificationChannel('adhan_v1');
    for (var i = 0; i < kMuezzins.length; i++) {
      final id = (i + 1).toString().padLeft(2, '0');
      await a?.createNotificationChannel(AndroidNotificationChannel('adhan_m$id', 'الأذان · ${kMuezzins[i]}',
          description: 'أذان عند دخول وقت الصلاة', importance: Importance.max, playSound: true, sound: RawResourceAndroidNotificationSound('a$id')));
    }
    final cu = customUri;
    if (cu != null) {
      await a?.createNotificationChannel(AndroidNotificationChannel('adhan_c$customVer', 'الأذان · $customName',
          description: 'أذان بملف من الجهاز', importance: Importance.max, playSound: true, sound: UriAndroidNotificationSound(cu)));
    }
    ready = true;
  }

  // ---- أذان مخصص من ذاكرة الهاتف ----
  static const nat = MethodChannel('mp/native');
  static String? get customUri => Store.prefs.getString('cs_uri');
  static int get customVer => Store.prefs.getInt('cs_ver') ?? 0;
  static String get customName => Store.prefs.getString('cs_name') ?? 'أذان مخصص';
  static String? get customPath => Store.prefs.getString('cs_path');
  static bool get hasCustom => customUri != null && customUri!.isNotEmpty;
  static const customId = 100;

  /// يسجل ملفا صوتيا كأذان مخصص. القناة لا يمكن تغيير صوتها بعد إنشائها، لذلك تُنشأ قناة جديدة لكل ملف.
  static Future<bool> setCustom(String path, String name) async {
    await init();
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final uri = await nat.invokeMethod<String>('registerSound', {'path': path, 'name': name, 'old': customUri});
    if (uri == null || uri.isEmpty) return false;
    await a?.deleteNotificationChannel('adhan_c$customVer');
    final ver = customVer + 1;
    await Store.prefs.setString('cs_uri', uri);
    await Store.prefs.setInt('cs_ver', ver);
    await Store.prefs.setString('cs_name', name);
    await Store.prefs.setString('cs_path', path);
    await a?.createNotificationChannel(AndroidNotificationChannel('adhan_c$ver', 'الأذان · $name',
        description: 'أذان بملف من الجهاز', importance: Importance.max, playSound: true, sound: UriAndroidNotificationSound(uri)));
    return true;
  }

  static String nameOf(int m) => m == customId ? customName : kMuezzins[m.clamp(0, kMuezzins.length - 1)];

  /// أذان الصلاة رقم i: اختيارها الخاص أو الأذان العام.
  static int muezzinFor(int i) {
    final v = Store.prefs.getInt('pt_mz_$i');
    if (v == null) return muezzin;
    if (v == customId && !hasCustom) return muezzin;
    return v;
  }

  static Future<bool> ensurePermissions(BuildContext context, {bool force = false}) async {
    final p = Store.prefs;
    if (!force && p.getBool('perm_prompt_v1') == true) return true;
    await p.setBool('perm_prompt_v1', true);
    await init();
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    Future<bool> ask(String title, String body, String ok) async =>
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لاحقا')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
            ],
          ),
        ) ??
        false;
    if (!(await a?.areNotificationsEnabled() ?? true)) {
      if (!context.mounted) return false;
      if (await ask('السماح بالإشعارات', 'لكي يصلك الأذان في وقته يحتاج التطبيق إذن الإشعارات. اضغط «سماح» ثم وافق في النافذة التي ستظهر.', 'سماح')) {
        await a?.requestNotificationsPermission();
        if (!(await a?.areNotificationsEnabled() ?? true)) {
          if (!context.mounted) return false;
          if (await ask('الإشعارات ما زالت مغلقة', 'الإذن مرفوض. افتح إعدادات الإشعارات للتطبيق وفعّلها يدويا.', 'فتح الإعدادات')) {
            await nat.invokeMethod('openSettings', {'kind': 'notif'});
          }
        }
      }
    }
    if (!(await a?.canScheduleExactNotifications() ?? true)) {
      if (!context.mounted) return false;
      if (await ask('المنبهات والتذكيرات', 'لضبط الأذان على الثانية يلزم السماح بـ«المنبهات والتذكيرات». ستفتح لك صفحة الإعدادات: فعّل الخيار للتطبيق.', 'فتح الإعدادات')) {
        await nat.invokeMethod('openSettings', {'kind': 'exact'});
      }
    }
    final ign = await nat.invokeMethod<bool>('isIgnoringBattery') ?? true;
    if (!ign) {
      if (!context.mounted) return false;
      if (await ask('توفير البطارية', 'بعض الهواتف توقف التطبيقات في الخلفية فيتأخر الأذان أو لا يصل. اسمح للتطبيق بتجاهل تحسين البطارية.', 'سماح')) {
        await nat.invokeMethod('openSettings', {'kind': 'battery'});
      }
    }
    return true;
  }

  static int get muezzin => (Store.prefs.getInt('mz') ?? 0).clamp(0, kMuezzins.length - 1);

  static NotificationDetails detailsFor(int m) {
    if (m == customId && hasCustom) {
      return NotificationDetails(
          android: AndroidNotificationDetails('adhan_c$customVer', 'الأذان · $customName',
              channelDescription: 'أذان بملف من الجهاز',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: UriAndroidNotificationSound(customUri!),
              category: AndroidNotificationCategory.alarm,
              autoCancel: true,
              visibility: NotificationVisibility.public));
    }
    m = m.clamp(0, kMuezzins.length - 1);
    final id = (m + 1).toString().padLeft(2, '0');
    return NotificationDetails(
        android: AndroidNotificationDetails('adhan_m$id', 'الأذان · ${kMuezzins[m]}',
            channelDescription: 'أذان عند دخول وقت الصلاة',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('a$id'),
            category: AndroidNotificationCategory.alarm,
            autoCancel: true,
            ongoing: false,
            visibility: NotificationVisibility.public));
  }

  static Future<void> askPermissions() async {
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
    await a?.requestExactAlarmsPermission();
  }

  /// حالة الإشعارات: (مفعلة, تنبيه دقيق مسموح, عدد المجدول)
  static Future<(bool, bool, int)> status() async {
    await init();
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final en = await a?.areNotificationsEnabled() ?? false;
    final ex = await a?.canScheduleExactNotifications() ?? false;
    final pend = (await plugin.pendingNotificationRequests()).length;
    return (en, ex, pend);
  }

  /// يجدول إشعار أذان بعد ١٥ ثانية ليختبر مسار الجدولة الحقيقي (التطبيق يمكن إغلاقه).
  static Future<bool> testScheduled([int? m]) async {
    await init();
    final mm = m ?? muezzin;
    final when = tz.TZDateTime.from(DateTime.now().add(const Duration(seconds: 15)), tz.UTC);
    for (final mode in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
      try {
        await plugin.zonedSchedule(998, 'تجربة مجدولة · ${nameOf(mm)}', 'هكذا سيصلك الأذان في وقته', when, detailsFor(mm),
            androidScheduleMode: mode, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
        return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> test([int? m]) async {
    await init();
    final mm = m ?? muezzin;
    await plugin.cancel(999);
    await plugin.show(999, 'تجربة الأذان · ${nameOf(mm)}', 'اسحب الإشعار لإيقاف الصوت', detailsFor(mm));
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
            await plugin.zonedSchedule(d * 10 + i, 'حان الآن وقت صلاة ${prayerNames[i]}', '${nameOf(muezzinFor(i))} · ${method.name}', when, detailsFor(muezzinFor(i)),
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
      if (mounted) await PrayerService.ensurePermissions(context);
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
    final pt = PrayerService.timesFor(now);
    final (ni, nt) = PrayerService.next();
    final left = nt.difference(now);
    final surf = Theme.of(context).colorScheme.surface;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final night = now.isBefore(pt.fajr) ? PrayerService.timesFor(now.subtract(const Duration(days: 1))) : pt;
    final sunna = SunnahTimes(night);
    String two(int v) => arabicDigits(v).padLeft(2, '٠');
    final cd = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    const colors = [Color(0xFF5C6BC0), Color(0xFFFFB300), Color(0xFF29B6F6), Color(0xFFFF7043), Color(0xFF7E57C2)];
    final features = <(IconData, String, Color, Widget)>[
      (Icons.menu_book, 'المصحف', const Color(0xFF2E9E5B), const MushafTab()),
      (Icons.favorite, 'الأذكار', const Color(0xFF1E88E5), const AdhkarTab()),
      (Icons.radio_button_checked, 'السبحة', const Color(0xFF6A1B9A), const TasbihPage()),
      (Icons.explore, 'القبلة', const Color(0xFF26A69A), const QiblaTab()),
      (Icons.back_hand, 'الأدعية', const Color(0xFF0288D1), const AdhkarTab()),
      (Icons.calculate, 'حاسبة الزكاة', const Color(0xFFF9A825), const ZakatPage()),
      (Icons.flag, 'الختمة', const Color(0xFFEF6C00), const KhatmaPage()),
      (Icons.headphones, 'التلاوات', const Color(0xFF00897B), const RecitersTab()),
      (Icons.access_time, 'الساعة', const Color(0xFF5E35B1), const ClockPage()),
      (Icons.auto_awesome, 'اسأل', const Color(0xFFD81B60), const AiTab()),
      (Icons.notifications_active, 'الأذان', const Color(0xFFE53935), const PrayerSettings()),
      (Icons.settings, 'الإعدادات', const Color(0xFF546E7A), const Settings()),
    ];
    Widget pill(String label, DateTime t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: mint.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
          child: Text('$label : ${hm(t)}', style: TextStyle(color: onSurf, fontSize: 13, fontWeight: FontWeight.w600)),
        );
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          SizedBox(
            height: 300 + MediaQuery.of(context).padding.top,
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: SkyPainter(now))),
              Padding(
                padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 6, 12, 0),
                child: Column(children: [
                  Row(children: [
                    IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => open(const Settings())),
                    const Spacer(),
                    Text(hijriNow(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  Text('${prayerNames[ni]} بعد', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  Directionality(textDirection: TextDirection.ltr, child: Text(cd, style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w300, letterSpacing: 1))),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(18)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on, color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(PrayerService.located ? 'موقعك الحالي · ${PrayerService.method.name}' : 'القاهرة (افتراضي) · ${PrayerService.method.name}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          Container(
            color: surf,
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                for (final e in [(0, 'الفجر', pt.fajr, Icons.nights_stay), (-1, 'الشروق', pt.sunrise, Icons.wb_twilight), (1, 'الظهر', pt.dhuhr, Icons.wb_sunny), (2, 'العصر', pt.asr, Icons.cloud), (3, 'المغرب', pt.maghrib, Icons.wb_twilight), (4, 'العشاء', pt.isha, Icons.nightlight_round)])
                  Builder(builder: (c) {
                    final isNext = e.$1 == ni;
                    final col = e.$1 < 0 ? Colors.orange : colors[e.$1];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(color: isNext ? col.withValues(alpha: .15) : null, borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Text(e.$2, style: TextStyle(fontSize: 12, color: onSurf, fontWeight: isNext ? FontWeight.bold : FontWeight.normal)),
                        const SizedBox(height: 4),
                        Icon(e.$4, color: col, size: 26),
                        const SizedBox(height: 4),
                        Text(hm(e.$3).split(' ')[0], style: TextStyle(fontSize: 12, color: onSurf)),
                        Text(e.$3.hour < 12 ? 'ص' : 'م', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                      ]),
                    );
                  }),
              ]),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [pill('منتصف الليل', sunna.middleOfTheNight), pill('الثلث الأخير', sunna.lastThirdOfTheNight)]),
            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 20),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 6,
              childAspectRatio: .88,
              children: [
                for (var fi = 0; fi < features.length; fi++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + fi * 60),
                    curve: Curves.easeOut,
                    builder: (c, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => open(features[fi].$4),
                      child: Column(children: [
                        Container(width: 58, height: 58, decoration: BoxDecoration(color: features[fi].$3.withValues(alpha: .16), shape: BoxShape.circle, border: Border.all(color: features[fi].$3, width: 2)), child: Icon(features[fi].$1, color: features[fi].$3, size: 28)),
                        const SizedBox(height: 6),
                        Text(features[fi].$2, textAlign: TextAlign.center, style: TextStyle(color: onSurf, fontSize: 11.5, fontWeight: FontWeight.w600), maxLines: 2),
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

/// رسم أصلي: سماء الغروب ومسجد بقبة ومئذنتين (بدون أي شعارات أو رسومات مأخوذة من تطبيقات أخرى)
class SkyPainter extends CustomPainter {
  final DateTime t;
  SkyPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final dayPhase = t.hour >= 6 && t.hour < 17;
    final top = dayPhase ? const Color(0xFF3B8ED0) : const Color(0xFF3B2A6B);
    final mid = dayPhase ? const Color(0xFF8CC5EE) : const Color(0xFFB0507A);
    final low = dayPhase ? const Color(0xFFFFE3B0) : const Color(0xFFFFA45B);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, mid, low]).createShader(Rect.fromLTWH(0, 0, w, h)));
    // شمس/قمر
    c.drawCircle(Offset(w * .36, h * .58), 26, Paint()..color = (dayPhase ? Colors.yellow : const Color(0xFFFFF3C4)).withValues(alpha: .85));
    // سحب
    final cl = Paint()..color = Colors.white.withValues(alpha: .35);
    for (final o in [Offset(w * .72, h * .36), Offset(w * .3, h * .3)]) {
      c.drawOval(Rect.fromCenter(center: o, width: 70, height: 18), cl);
      c.drawOval(Rect.fromCenter(center: o + const Offset(18, -8), width: 40, height: 16), cl);
    }
    // تلال
    final hill = Path()..moveTo(0, h)..lineTo(0, h * .86)..quadraticBezierTo(w * .25, h * .76, w * .5, h * .86)..quadraticBezierTo(w * .8, h * .78, w, h * .86)..lineTo(w, h)..close();
    c.drawPath(hill, Paint()..color = const Color(0xFF2F6B5B));
    // المسجد
    final base = h * .9;
    final cx = w / 2;
    final wall = Paint()..color = const Color(0xFFF4EAD8);
    final dark = Paint()..color = const Color(0xFF4B3F8F);
    c.drawRect(Rect.fromLTRB(cx - 120, base - 50, cx + 120, base), wall);
    // قبة مركزية
    final dome = Path()..moveTo(cx - 50, base - 50)..quadraticBezierTo(cx - 50, base - 120, cx, base - 128)..quadraticBezierTo(cx + 50, base - 120, cx + 50, base - 50)..close();
    c.drawPath(dome, Paint()..color = const Color(0xFF29A7D9));
    c.drawRect(Rect.fromLTRB(cx - 50, base - 56, cx + 50, base - 46), wall);
    c.drawLine(Offset(cx, base - 128), Offset(cx, base - 144), Paint()..color = const Color(0xFFFFD54F)..strokeWidth = 2.5);
    c.drawCircle(Offset(cx, base - 146), 3.5, Paint()..color = const Color(0xFFFFD54F));
    // مئذنتان
    for (final sx in [cx - 150, cx + 150]) {
      c.drawRect(Rect.fromLTRB(sx - 11, base - 130, sx + 11, base), wall);
      c.drawRect(Rect.fromLTRB(sx - 15, base - 100, sx + 15, base - 92), Paint()..color = const Color(0xFFD9C9A8));
      final cap = Path()..moveTo(sx - 12, base - 130)..lineTo(sx, base - 160)..lineTo(sx + 12, base - 130)..close();
      c.drawPath(cap, Paint()..color = const Color(0xFF29A7D9));
      c.drawCircle(Offset(sx, base - 163), 3, Paint()..color = const Color(0xFFFFD54F));
    }
    // أقواس ونوافذ
    for (var i = -3; i <= 3; i++) {
      if (i == 0) continue;
      final x = cx + i * 30.0;
      final arch = Path()..moveTo(x - 9, base)..lineTo(x - 9, base - 24)..quadraticBezierTo(x, base - 40, x + 9, base - 24)..lineTo(x + 9, base)..close();
      c.drawPath(arch, dark);
    }
    final door = Path()..moveTo(cx - 14, base)..lineTo(cx - 14, base - 30)..quadraticBezierTo(cx, base - 50, cx + 14, base - 30)..lineTo(cx + 14, base)..close();
    c.drawPath(door, dark);
    // شجرتان
    for (final tx in [w * .08, w * .92]) {
      c.drawRect(Rect.fromLTWH(tx - 2, base - 22, 4, 24), Paint()..color = const Color(0xFF5D4037));
      c.drawCircle(Offset(tx, base - 32), 16, Paint()..color = const Color(0xFF1F7A4D));
    }
    c.drawRect(Rect.fromLTWH(0, base, w, h - base), Paint()..color = const Color(0xFF245F4C));
  }

  @override
  bool shouldRepaint(SkyPainter o) => o.t.hour != t.hour;
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
        if (p.getString('pt_method') == null) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('مختارة تلقائيا حسب موقعك: ${cur.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
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
        if (msg != null) Padding(padding: const EdgeInsets.all(8), child: Text(msg!, style: TextStyle(color: Theme.of(context).hintColor))),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('إذا لم يصلك الأذان في وقته: اسمح بالإشعارات والمنبهات الدقيقة، واستثنِ التطبيق من توفير البطارية من إعدادات الهاتف. صوت الأذان: تسجيل المسجد النبوي (archive.org).', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
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
      HapticFeedback.lightImpact();
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
                    Container(width: 214, height: 214, decoration: const BoxDecoration(shape: BoxShape.circle, color: mint), alignment: Alignment.center, child: AnimatedScale(scale: 1.0 + (count % 2) * .06, duration: const Duration(milliseconds: 90), child: Text(arabicDigits(count), style: const TextStyle(fontSize: 76, color: Colors.white, fontWeight: FontWeight.bold)))),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text('إجمالي اليوم: ${arabicDigits(total)}', style: TextStyle(color: Theme.of(context).hintColor)),
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
          Text('${arabicDigits(now.hour % 12 == 0 ? 12 : now.hour % 12)}:${arabicDigits(now.minute).padLeft(2, '٠')}:${arabicDigits(now.second).padLeft(2, '٠')} ${now.hour < 12 ? 'ص' : 'م'}', style: TextStyle(fontSize: 34, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${days[now.weekday - 1]} ${arabicDigits(now.day)}/${arabicDigits(now.month)}/${arabicDigits(now.year)}', style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor)),
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
