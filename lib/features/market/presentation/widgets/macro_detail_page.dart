import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/widgets/cycle_arc.dart';
import 'package:aloria/features/market/presentation/widgets/macro_card.dart';
import 'package:aloria/features/market/presentation/widgets/sector_sensitivity.dart';
import 'package:flutter/material.dart';

/// Экран с пояснением текущего макросостояния: режим цикла, ставка, инфляция,
/// где мы в цикле. Без шапки — заголовок несёт сама секция режима, закрытие —
/// плавающий крестик или свайп контента вниз. Тон — учебный, без прогнозов.
class MacroDetailPage extends StatefulWidget {
  const MacroDetailPage({super.key, required this.state});

  final MacroState state;

  @override
  State<MacroDetailPage> createState() => _MacroDetailPageState();
}

class _MacroDetailPageState extends State<MacroDetailPage> {
  /// Закрываем, как только список оттянут ниже верхнего края дальше порога —
  /// сразу, не дожидаясь конца скролла (иначе пружина успевает вернуть pixels к
  /// нулю). Само закрытие играет плавный обратный морф OpenContainer.
  bool _dismissed = false;
  static const _dismissThreshold = 40.0;

  bool _onScroll(ScrollNotification n) {
    if (!_dismissed && n.metrics.pixels <= -_dismissThreshold) {
      _dismissed = true;
      Navigator.of(context).maybePop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta = macroRegimeMeta(state.regime);
    final topPad = MediaQuery.paddingOf(context).top;
    final progress = state.cycleLength > 0
        ? state.cycleDay.clamp(0, state.cycleLength) / state.cycleLength
        : 0.0;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.zero,
              children: [
                // Шапка с акцентом на цвет режима (уходит под статус-бар)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        meta.color.withValues(alpha: 0.22),
                        meta.color.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Макроэкономика',
                        style: text.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: meta.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            meta.label,
                            style: text.headlineSmall?.copyWith(
                              color: meta.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Экономический цикл',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'день ${state.cycleDay} из ${state.cycleLength}',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: meta.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Дуга цикла
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CycleArc(currentRegime: state.regime),
                ),
                const SizedBox(height: 20),
                // Метрики
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.percent_rounded,
                          label: 'Ключевая ставка',
                          value: '${_fmt(state.keyRate)}%',
                          color: meta.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.trending_up_rounded,
                          label: 'Инфляция',
                          value: '${_fmt(state.inflation)}%',
                          color: meta.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Пояснения
                _ExplainBlock(
                  icon: Icons.public_rounded,
                  color: meta.color,
                  title: 'Что значит «${meta.label.toLowerCase()}»',
                  body: _regimeExplanation(state.regime),
                ),
                _ExplainBlock(
                  icon: Icons.percent_rounded,
                  color: meta.color,
                  title: 'Ключевая ставка',
                  body:
                      'Стоимость денег в экономике. Когда она высокая, кредиты дороже, '
                      'а облигации с фиксированным купоном обычно дешевеют; когда низкая — '
                      'наоборот. На разные секторы ставка влияет по-разному: банки могут '
                      'выигрывать, а закредитованные компании — страдать.',
                ),
                _ExplainBlock(
                  icon: Icons.trending_up_rounded,
                  color: meta.color,
                  title: 'Инфляция',
                  body:
                      'Скорость роста цен. Высокая инфляция обесценивает будущие доходы '
                      'и подталкивает регулятора повышать ставку, что меняет условия для '
                      'всего рынка.',
                ),
                _ExplainBlock(
                  icon: Icons.calendar_month_rounded,
                  color: meta.color,
                  title: 'Экономический цикл',
                  body:
                      'Цикл в Aloria сжат: ${state.cycleLength} дней проходят как условный '
                      '«год». К дням цикла привязаны отчётности компаний, дивиденды и '
                      'купоны — их можно предвосхищать, а не ждать месяцами.',
                ),
                const SizedBox(height: 8),
                // Секторы в этом режиме
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Секторы в этом режиме',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SectorSensitivity(regime: state.regime),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Это ориентиры, а не прогноз. Рынок реагирует на ожидания: '
                            'если хорошая новость уже учтена в цене, она может и не '
                            'поднять её — а иногда даже опустить.',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Плавающий крестик
            Positioned(
              top: topPad + 6,
              right: 10,
              child: Material(
                color: scheme.surface.withValues(alpha: 0.65),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

  static String _regimeExplanation(String regime) => switch (regime) {
    'expansion' =>
      'Экономика растёт: спрос, прибыли компаний и занятость повышаются. Обычно '
          'это поддерживает акции — но многое уже может быть заложено в ценах.',
    'peak' =>
      'Рост на пике: экономика работает на пределе, инфляция и ставки склонны '
          'расти. Риск разворота повышен, рынок становится чувствительнее к плохим '
          'новостям.',
    'recession' =>
      'Экономика сжимается: спрос и прибыли падают. Циклические секторы (туризм, '
          'ритейл) обычно страдают сильнее защитных (еда, вода).',
    'recovery' =>
      'Экономика выходит из спада: показатели начинают улучшаться, ставку часто '
          'снижают. Аппетит к риску постепенно возвращается.',
    _ =>
      'Текущий режим экономики. Следи за тем, как на него реагируют разные '
          'секторы — реакция бывает неочевидной.',
  };
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(value, style: monoNum(size: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ExplainBlock extends StatelessWidget {
  const _ExplainBlock({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: text.bodyMedium?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
