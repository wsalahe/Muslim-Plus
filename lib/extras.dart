import 'dart:convert';
import 'package:flutter/material.dart';
import 'main.dart';
import 'features.dart';
import 'prayer.dart';

// ---------------- الأذان (تبويب) ----------------
class AdhanTab extends StatefulWidget {
  const AdhanTab({super.key});
  @override
  State<AdhanTab> createState() => _AdhanTabState();
}

class _AdhanTabState extends State<AdhanTab> {
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
      appBar: AppBar(title: const Text('الأذان', style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(icon: const Icon(Icons.tune), tooltip: 'طريقة الحساب والمواقيت', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerSettings())).then((_) => setState(() {}))),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.access_time_filled, color: gold),
            title: Text('الصلاة القادمة: ${prayerNames[ni]} ${hm(nt)}'),
            subtitle: Text('المؤذن: ${kMuezzins[sel]} · ${PrayerService.method.name}'),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text('اختر المؤذن (٣٠ مؤذنا)', style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
        for (var i = 0; i < kMuezzins.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(color: i == sel ? gold.withValues(alpha: .15) : null, borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: i == sel ? gold : navy, child: Text(arabicDigits(i + 1), style: TextStyle(color: i == sel ? Colors.black : gold, fontSize: 12))),
              title: Text(kMuezzins[i]),
              subtitle: i == sel ? const Text('المؤذن المختار لكل الصلوات') : null,
              onTap: () => choose(i),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_outline, color: gold),
                tooltip: 'تجربة',
                onPressed: () async { await PrayerService.askPermissions(); await PrayerService.test(i); },
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('زر التشغيل يرسل إشعار تجربة بصوت هذا المؤذن؛ اسحب الإشعار لإيقاف الصوت. الأذان يعمل في الخلفية حتى والتطبيق مغلق. المقاطع نحو ٨٠ ثانية من بداية كل أذان.', style: TextStyle(fontSize: 12)),
        ),
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
        appBar: AppBar(title: const Text('حاسبة الزكاة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('أدخل المبالغ بعملتك. أسعار الذهب والفضة تدخلها بنفسك من سعر اليوم.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          field('cash', 'النقود والمدخرات'),
          field('goldg', 'الذهب (جرام)'),
          field('goldp', 'سعر جرام الذهب'),
          field('silg', 'الفضة (جرام)'),
          field('silp', 'سعر جرام الفضة'),
          field('trade', 'عروض التجارة'),
          field('debt', 'الديون المستحقة عليك'),
          SwitchListTile(
            activeColor: gold,
            title: const Text('النصاب بالفضة (٥٩٥ جراما)'),
            subtitle: Text(silver ? 'النصاب بالفضة (أقل)' : 'النصاب بالذهب (٨٥ جراما)'),
            value: silver,
            onChanged: (x) => setState(() => silver = x),
          ),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black), onPressed: calc, child: const Text('احسب الزكاة')),
          if (res != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Card(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('صافي المال: ${f(res!.net)}'),
                    Text('النصاب: ${res!.nisab > 0 ? f(res!.nisab) : 'أدخل سعر الجرام'}'),
                    const SizedBox(height: 6),
                    Text(res!.due ? 'الزكاة الواجبة (٢٫٥٪): ${f(res!.zakat)}' : (res!.nisab > 0 ? 'لم يبلغ النصاب: لا زكاة عليك الآن' : 'أدخل سعر الذهب أو الفضة لتحديد النصاب'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: gold)),
                    const SizedBox(height: 6),
                    const Text('تشترط الزكاة مرور حول هجري كامل على المال. الحاسبة مساعدة فقط؛ اسأل أهل العلم في مسائلك الخاصة.', style: TextStyle(fontSize: 11)),
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
      appBar: AppBar(title: const Text('ختمة القرآن'), actions: [
        IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'ختمة جديدة',
            onPressed: () { setState(() { done = {}; start = DateTime.now(); }); save(); }),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أنهيت ${arabicDigits(done.length)} من ١١٤ سورة (${arabicDigits((read * 100 / total).round())}٪)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: read / total), duration: const Duration(milliseconds: 500), builder: (c, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: gold, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 10),
              Row(children: [
                const Text('أريد الختم خلال '),
                DropdownButton<int>(value: days, items: [for (final d in [7, 10, 15, 20, 30, 60, 90]) DropdownMenuItem(value: d, child: Text('${arabicDigits(d)} يوما'))], onChanged: (v) { setState(() { days = v!; start ??= DateTime.now(); }); save(); }),
              ]),
              if (start != null) Text('وردك اليومي المتبقي: ${arabicDigits(wird)} آية تقريبا (متبقي ${arabicDigits(daysLeft)} يوما)'),
              if (start == null) const Text('اختر المدة ثم علّم السور التي تقرؤها.', style: TextStyle(fontSize: 12)),
            ]),
          ),
        ),
        for (var n = 1; n <= 114; n++)
          CheckboxListTile(
            activeColor: gold,
            value: done.contains(n),
            title: Text('سورة ${surahs[n - 1]}', style: const TextStyle(fontFamily: 'Amiri', fontSize: 18)),
            subtitle: Text('${arabicDigits(ayahs(n))} آية'),
            onChanged: (v) { setState(() { v! ? done.add(n) : done.remove(n); start ??= DateTime.now(); }); save(); },
          ),
      ]),
    );
  }
}
