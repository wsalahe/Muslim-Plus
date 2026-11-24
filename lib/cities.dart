import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'prayer.dart';

class City {
  final String name, cc;
  final List<String> alts;
  final double lat, lon;
  final String key; // نص موحد للبحث
  City(this.name, this.alts, this.cc, this.lat, this.lon) : key = _norm('$name ${alts.join(' ')}');

  /// الاسم العربي إن وُجد.
  String get label {
    final ar = alts.where((a) => RegExp(r'[\u0600-\u06FF]').hasMatch(a));
    return ar.isEmpty ? name : '${ar.first} · $name';
  }
}

String _norm(String s) {
  s = s.toLowerCase();
  s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
  s = s.replaceAll(RegExp('[\u0622\u0623\u0625\u0671]'), '\u0627').replaceAll('\u0629', '\u0647').replaceAll('\u0649', '\u064A');
  s = s.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');
  s = s.replaceAll('ou', 'u').replaceAll('oo', 'u').replaceAll('ee', 'i').replaceAll('kh', 'k').replaceAll('ph', 'f');
  return s;
}

class CityDb {
  static List<City>? _all;

  static Future<List<City>> load() async {
    if (_all != null) return _all!;
    return _all = parse(await rootBundle.loadString('assets/cities.txt'));
  }

  static List<City> parse(String txt) {
    final out = <City>[];
    for (final line in txt.split('\n')) {
      final f = line.split('\t');
      if (f.length < 5) continue;
      out.add(City(f[0], f[1].isEmpty ? <String>[] : f[1].split('|'), f[2], double.parse(f[3]), double.parse(f[4])));
    }
    return out;
  }

  /// بحث: يبدأ بالنص أولا ثم يحتويه. القائمة مرتبة بعدد السكان.
  static List<City> search(List<City> all, String q, {int limit = 8}) {
    final k = _norm(q);
    if (k.length < 2) return [];
    final starts = <City>[], has = <City>[];
    for (final c in all) {
      final i = c.key.indexOf(k);
      if (i < 0) continue;
      if (i == 0 || c.key.startsWith('al$k') || c.key.startsWith('\u0627\u0644$k')) {
        starts.add(c);
      } else {
        has.add(c);
      }
      if (starts.length >= limit) break;
    }
    return [...starts, ...has].take(limit).toList();
  }

  static City? nearest(List<City> all, double lat, double lon, {double maxKm = 200}) {
    City? best;
    var bd = double.infinity;
    for (final c in all) {
      final dLat = (c.lat - lat) * 111.0;
      final dLon = (c.lon - lon) * 111.0 * math.cos(lat * math.pi / 180);
      final d = dLat * dLat + dLon * dLon;
      if (d < bd) {
        bd = d;
        best = c;
      }
    }
    return bd <= maxKm * maxKm ? best : null;
  }
}

/// طريقة الحساب الافتراضية حسب رمز الدولة.
String methodForCountry(String cc) {
  switch (cc) {
    case 'EG': case 'SD': case 'SS': return 'egy';
    case 'SA': case 'YE': return 'umm';
    case 'AE': case 'OM': return 'dxb';
    case 'KW': case 'BH': return 'kwt';
    case 'QA': return 'qat';
    case 'TR': return 'tur';
    case 'IR': return 'teh';
    case 'PK': case 'IN': case 'BD': case 'AF': return 'khi';
    case 'SG': case 'MY': case 'ID': case 'BN': return 'sgp';
    case 'US': case 'CA': return 'isna';
    case 'GB': return 'moon';
    default: return 'mwl';
  }
}

/// بطاقة اختيار المدينة يدويا مع اقتراحات أثناء الكتابة.
class CitySearchCard extends StatefulWidget {
  final VoidCallback onPicked;
  const CitySearchCard({super.key, required this.onPicked});
  @override
  State<CitySearchCard> createState() => _CitySearchCardState();
}

class _CitySearchCardState extends State<CitySearchCard> {
  final ctl = TextEditingController();
  List<City> all = [];
  List<City> hits = [];

  @override
  void initState() {
    super.initState();
    CityDb.load().then((v) { if (mounted) setState(() => all = v); });
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Future<void> pick(City c) async {
    await PrayerService.setManualCity(c);
    ctl.clear();
    setState(() => hits = []);
    widget.onPicked();
  }

  @override
  Widget build(BuildContext context) {
    final cur = Store.prefs.getString('pt_city');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اختيار المدينة يدويا', style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
          if (cur != null) Text('المدينة الحالية: $cur', style: const TextStyle(fontSize: 13)),
          TextField(
            controller: ctl,
            decoration: InputDecoration(hintText: all.isEmpty ? 'جارٍ تحميل قائمة المدن...' : 'اكتب اسم المدينة (عربي أو إنجليزي)', prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() => hits = CityDb.search(all, v)),
          ),
          for (final c in hits) ListTile(dense: true, title: Text(c.label), subtitle: Text('${c.cc} · ${c.lat.toStringAsFixed(2)}, ${c.lon.toStringAsFixed(2)}'), onTap: () => pick(c)),
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('قائمة المدن: GeoNames.org (CC BY 4.0)، مدن يزيد سكانها عن ١٥ ألفا، تعمل بدون إنترنت.', style: TextStyle(fontSize: 10))),
        ]),
      ),
    );
  }
}
