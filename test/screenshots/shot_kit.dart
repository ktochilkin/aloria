import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Общий набор скриншот-харнесса: загрузка шрифтов (Nunito/Caveat из
/// assets/fonts + MaterialIcons из кэша Flutter SDK) и снятие PNG
/// с RepaintBoundary. Используется блок- и экран-харнессами.
Future<void> loadShotFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  const weights = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  for (final family in ['Nunito', 'Caveat']) {
    final loader = FontLoader(family);
    for (final w in weights) {
      final f = File('assets/fonts/$family-$w.ttf');
      if (!f.existsSync()) continue;
      final bytes = f.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      final bytes = icons.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }

  // Прогрев google_fonts: он регистрирует вариант (семья+вес) асинхронно при
  // первом обращении, и первый тест успевает отрисовать кадр плашками Ahem.
  // Трогаем все используемые варианты и ждём фактической загрузки.
  for (final w in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.nunito(fontWeight: w);
    GoogleFonts.caveat(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}

/// Снимает PNG с RepaintBoundary по ключу в файл [path].
Future<void> snapKey(WidgetTester tester, Key key, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
