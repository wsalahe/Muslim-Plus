import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/main.dart';
import 'package:quran_app/prayer.dart';
import 'package:quran_app/mushaf.dart';
import 'package:quran_app/mushaf_theme.dart';
import 'package:quran_app/features.dart';
import 'package:quran_app/extras.dart';
import 'package:quran_app/l10n.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) { l.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer))); }
  await l.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sdk = '/home/sandbox/sdk/flutter/bin/cache/artifacts/material_fonts';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((c) async => '/tmp/qdocs');
    for (final ch in ['com.ryanheise.just_audio.methods', 'com.ryanheise.audio_session', 'dexterous.com/flutter/local_notifications', 'mp/native', 'flutter_timezone', 'dev.fluttercommunity.plus/connectivity']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(ch), (c) async => null);
    }
    Directory('/tmp/qdocs').createSync(recursive: true);
    await loadFont('Roboto', ['$sdk/Roboto-Regular.ttf', '$sdk/Roboto-Bold.ttf', '$sdk/Roboto-Medium.ttf']);
    await loadFont('MaterialIcons', ['$sdk/MaterialIcons-Regular.otf']);
    await loadFont('Amiri', ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf']);
    await loadFont('AmiriQuran', ['assets/fonts/AmiriQuran-Regular.ttf']);
    langPref.value = Platform.environment['L'] ?? 'ar';
    await Store.init();
  });

  Future<void> shot(WidgetTester t, String name, Widget w) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      theme: buildTheme(false).copyWith(textTheme: buildTheme(false).textTheme.apply(fontFamily: 'Amiri')),
      builder: (c, x) => Directionality(textDirection: isEn ? TextDirection.ltr : TextDirection.rtl, child: x!),
      home: w,
    )));
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/shots/${Platform.environment['L'] ?? 'ar'}_$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('themes', (t) async {
    Directory('/tmp/shots').createSync(recursive: true);
    final q = (await t.runAsync(() async { await PageData.load(); return await QuranText.load(); }))!;
    for (final id in ['ornate', 'green', 'clean', 'amoled', 'emerald']) {
      await Store.prefs.setString('mushaf_theme', id);
      await shot(t, 'th_$id', PageReader(initialPage: 2));
    }
    await Store.prefs.setString('mushaf_theme', 'ornate');
    await shot(t, 'th_picker', MushafThemePage(quran: q));
  });

  testWidgets('shots', (t) async {
    Directory('/tmp/shots').createSync(recursive: true);
    await shot(t, '1_home', const HomeTab());
    await shot(t, '2_adhan', const AdhanTab());
    await shot(t, '3_mushaf_page', const PageReader(initialPage: 2));
    await shot(t, '4_recitations', const RecitersTab());
    await shot(t, '5_settings', const Settings());
  });
}
