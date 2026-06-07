import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Витрина основ дизайн-системы блоков: токены (свотчи, шкалы, тень) и
/// примитивы block_kit в деле. Урок lab/03-foundations. То, что крутим перед
/// раскаткой на 44 блока.

/// Канонический интерактивный блок, собранный ЦЕЛИКОМ из block_kit —
/// доказательство, что кит даёт «тёплый акцент» без ручной вёрстки.
class KitCanonicalBlock extends StatefulWidget {
  const KitCanonicalBlock({super.key, required this.tint});

  final Color tint;

  @override
  State<KitCanonicalBlock> createState() => _KitCanonicalBlockState();
}

class _KitCanonicalBlockState extends State<KitCanonicalBlock> {
  static const int _years = 20;
  static const double _start = 1000;

  double _rate = 0.10;
  bool _revealed = true;

  List<double> get _series =>
      List.generate(_years + 1, (y) => _start * _powd(1 + _rate, y));

  void _replay() {
    setState(() => _revealed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint;
    final series = _series;
    final last = series.last;
    final spots = [
      for (var y = 0; y <= _years; y++)
        FlSpot(y.toDouble(), _revealed ? series[y] : _start),
    ];

    return LessonBlockCard(
      tint: tint,
      title: 'Сложный процент',
      subtitle: '1000 ₽, реинвест каждый год, $_years лет',
      footer: BlockButton(
        tint: tint,
        label: 'Проиграть заново',
        icon: Icons.replay,
        onPressed: _replay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.95,
            child: LineChart(
              blockLineChart(
                context: context,
                tint: tint,
                spots: spots,
                minX: 0,
                maxX: _years.toDouble(),
                minY: 0,
                maxY: series.last * 1.08,
                bottomInterval: 5,
              ),
              duration: BlockMotion.chart,
              curve: BlockMotion.curve,
            ),
          ),
          const SizedBox(height: BlockSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: BlockMetric(
                  label: 'через $_years лет',
                  value: '${_money(last)} ₽',
                  color: tint,
                ),
              ),
              BlockChip(text: '×${(last / _start).toStringAsFixed(1)}', tint: tint),
            ],
          ),
          const SizedBox(height: BlockSpacing.l),
          BlockSlider(
            tint: tint,
            label: 'ставка',
            valueLabel: '${(_rate * 100).round()}% годовых',
            value: _rate,
            min: 0.04,
            max: 0.16,
            divisions: 12,
            onChanged: (v) => setState(() => _rate = v),
          ),
        ],
      ),
    );
  }
}

/// Свотчи акцента/семантики, шкала отступов, радиусы и образец тени.
class KitTokens extends StatelessWidget {
  const KitTokens({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(bottom: BlockSpacing.s),
          child: Text(s,
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
        );

    return LessonBlockCard(
      tint: tint,
      title: 'Токены',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label('Цвет'),
          Wrap(spacing: BlockSpacing.m, runSpacing: BlockSpacing.m, children: [
            _swatch(context, tint, 'accent'),
            _swatch(context, BlockChartColors.success, 'success'),
            _swatch(context, BlockChartColors.error, 'error'),
            _swatch(context, BlockTint.cardSurface(scheme), 'surface',
                border: true),
            _swatch(context, scheme.onSurface, 'onSurface'),
          ]),
          const SizedBox(height: BlockSpacing.l),
          label('Отступы · 4 / 8 / 12 / 16 / 24'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _spaceBar(tint, BlockSpacing.xs),
              _spaceBar(tint, BlockSpacing.s),
              _spaceBar(tint, BlockSpacing.m),
              _spaceBar(tint, BlockSpacing.l),
              _spaceBar(tint, BlockSpacing.xl),
            ],
          ),
          const SizedBox(height: BlockSpacing.l),
          label('Радиусы · inner 12 / card 18'),
          Row(children: [
            _radiusBox(context, BlockRadii.inner, '12'),
            const SizedBox(width: BlockSpacing.m),
            _radiusBox(context, BlockRadii.card, '18'),
          ]),
          const SizedBox(height: BlockSpacing.l),
          label('Тень карточки (мягкая, нейтральная)'),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BlockRadii.cardBr,
              boxShadow: BlockShadow.card(scheme.brightness),
            ),
            alignment: Alignment.center,
            child: Text('blur 24 · spread -6 · y 12 · black@8%',
                style: text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _swatch(BuildContext context, Color color, String name,
      {bool border = false}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BlockRadii.innerBr,
            border: border
                ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6))
                : null,
          ),
        ),
        const SizedBox(height: BlockSpacing.xs),
        Text(name, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _spaceBar(Color tint, double size) => Padding(
        padding: const EdgeInsets.only(right: BlockSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: size, height: 28, color: tint.withValues(alpha: 0.7)),
            const SizedBox(height: BlockSpacing.xs),
            Text('${size.toInt()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _radiusBox(BuildContext context, double radius, String n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 48,
      decoration: BoxDecoration(
        color: BlockTint.soft(tint),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(n,
          style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
    );
  }
}

/// Мелкие примитивы: чипы всех тонов, метрика, крупное число, легенда.
class KitBits extends StatelessWidget {
  const KitBits({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return LessonBlockCard(
      tint: tint,
      title: 'Примитивы',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: BlockSpacing.s, runSpacing: BlockSpacing.s, children: [
            BlockChip(text: '×17', tint: tint),
            BlockChip(text: '+12%', tint: tint, tone: BlockTone.success),
            BlockChip(text: '−8%', tint: tint, tone: BlockTone.error),
            BlockChip(text: 'нейтрально', tint: tint, tone: BlockTone.neutral),
          ]),
          const SizedBox(height: BlockSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: BlockMetric(
                    label: 'покупательная способность',
                    value: '125 000 ₽',
                    color: tint),
              ),
              NumberAccent(value: '×17', label: 'за 30 лет', tint: tint),
            ],
          ),
          const SizedBox(height: BlockSpacing.l),
          BlockLegend(items: [
            (tint, 'сложный процент'),
            (BlockChartColors.neutral(Theme.of(context).colorScheme),
                'простое сложение'),
          ]),
        ],
      ),
    );
  }
}

double _powd(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}

String _money(double v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
