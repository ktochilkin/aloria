
import 'package:aloria/core/theme/app_theme.dart';
import 'package:aloria/features/learn/domain/learning_content_service.dart';
import 'package:aloria/features/learn/presentation/widgets/lesson_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_kit.dart';

/// Скриншот-харнесс учебных блоков: рендерит каждый размещённый в уроках
/// блок в ширину телефона, снимает PNG, затем программно взаимодействует
/// (слайдеры, тапы) и снимает состояние «после». Запуск:
///   flutter test test/screenshots/block_screenshots_test.dart
/// Результат: build/block_shots/<имя>.png и <имя>_after.png.
///
/// Это инструмент дизайн-ревью, а не регрессионный тест: он не сравнивает
/// с эталоном и не падает из-за пикселей.

/// Размещённые в уроках блоки → токен тинта этапа (как в stages.json).
const _deployed = <String, String>{
  // why-market (tint: primary)
  'inflation-erosion': 'primary',
  'compound-growth': 'primary',
  'compound-race': 'primary',
  'scam-flags': 'primary',
  // basics (primary)
  'sort-by-risk': 'primary',
  'phone-vs-garage': 'primary',
  'real-yield': 'primary',
  // first-trade (primary)
  'flow-broker': 'primary',
  'order-builder': 'primary',
  'rubles-paper-flow': 'primary',
  'pnl-live': 'primary',
  // reading-market (primary)
  'orderbook-2col': 'primary',
  'spread-gauge': 'primary',
  'spread-roundtrip': 'primary',
  'candle-anatomy': 'primary',
  'candle-from-trades': 'primary',
  // stocks (success)
  'divgap-chart': 'success',
  // bonds (success)
  'bond-to-rubles': 'success',
  'bond-yield-flip': 'success',
  'nkd-sawtooth': 'success',
  'rating-yield': 'success',
  // portfolio (success)
  'diversification-dice': 'success',
  'if-then-rule': 'success',
  'tax-saldo': 'success',
  // active-trading (secondary)
  'leverage-seesaw': 'secondary',
  'timeline-tplus': 'secondary',
};

const _outDir = 'build/block_shots';

/// Пробует повзаимодействовать с блоком: слайдеры тянет, кнопки тапает.
/// Возвращает true, если хоть что-то сделала.
Future<bool> _interact(WidgetTester tester, Key boundaryKey) async {
  var acted = false;
  final within = find.descendant(
    of: find.byKey(boundaryKey),
    matching: find.byType(Slider),
  );
  for (var i = 0; i < within.evaluate().length && i < 2; i++) {
    await tester.drag(within.at(i), const Offset(70, 0));
    await tester.pump(const Duration(milliseconds: 400));
    acted = true;
  }
  if (!acted) {
    final buttons = find.descendant(
      of: find.byKey(boundaryKey),
      matching: find.byWidgetPredicate(
        (w) => w is InkWell || w is FilledButton || w is OutlinedButton,
      ),
    );
    final count = buttons.evaluate().length;
    for (var i = 0; i < count && i < 2; i++) {
      try {
        await tester.tap(buttons.at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
        acted = true;
      } catch (_) {
        // Кнопка могла исчезнуть после первого тапа — не страшно.
      }
    }
  }
  if (!acted) {
    final gestures = find.descendant(
      of: find.byKey(boundaryKey),
      matching: find.byType(GestureDetector),
    );
    if (gestures.evaluate().isNotEmpty) {
      await tester.tap(gestures.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      acted = true;
    }
  }
  // Дать доиграть анимациям, не полагаясь на pumpAndSettle (бывают циклы).
  // Несколько pump'ов: setState из post-frame колбэков применяется на
  // следующем кадре, и имплицитные анимации стартуют только после него.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
  return acted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadShotFonts);

  for (final entry in _deployed.entries) {
    final name = entry.key;
    final builder = lessonBlockBuilders[name];

    testWidgets('screenshot $name', (tester) async {
      expect(builder, isNotNull, reason: 'блок $name отсутствует в реестре');
      await tester.binding.setSurfaceSize(const Size(430, 3200));
      tester.view.devicePixelRatio = 1.0;

      final tint = LearningContentService.tintFor(entry.value);
      const boundaryKey = ValueKey('shot-boundary');

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Scaffold(
            backgroundColor: AppColorsCanvas.learn,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: Builder(
                    builder: (context) => builder!(context, tint),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Входные анимации блоков (~350мс) + рост графиков (~800мс).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1500));
      await snapKey(tester, boundaryKey, '$_outDir/$name.png');

      final acted = await _interact(tester, boundaryKey);
      if (acted) {
        await snapKey(tester, boundaryKey, '$_outDir/${name}_after.png');
      }

      await tester.binding.setSurfaceSize(null);
    });
  }
}

/// Холст раздела обучения для фона скриншота (как в приложении).
abstract final class AppColorsCanvas {
  static const learn = Color(0xFFFFFFFF);
}
