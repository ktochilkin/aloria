import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Кандидаты визуального направления для дизайн-системы блоков —
/// все три в семействе «светлый премиум-финтех», различаются «характером»:
/// воздух / чёткость / тёплый акцент. Один и тот же интерактивный контент
/// (слайдер ставки → график и число вживую, кнопка переигровки), чтобы
/// сравнение было честным. Витрина — урок lab/02-style-directions.
enum StyleVariant { airy, crisp, warm }

/// Вариант A — «Воздух»: белая карточка, мягкая большая тень, без рамки,
/// крупный радиус, много паддинга, акцент дозированно.
class StyleDirectionAiry extends StatelessWidget {
  const StyleDirectionAiry({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) =>
      _StyleDemo(tint: tint, variant: StyleVariant.airy);
}

/// Вариант B — «Чёткий»: белая карточка, тонкая рамка + лёгкая тень,
/// компактнее, ощущение data-надёжности (Mercury / Wealthfront).
class StyleDirectionCrisp extends StatelessWidget {
  const StyleDirectionCrisp({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) =>
      _StyleDemo(tint: tint, variant: StyleVariant.crisp);
}

/// Вариант C — «Тёплый акцент»: карточка с лёгкой акцент-подложкой,
/// мягкая тень, акцент используется щедрее (заливка графика, чип-плашка).
class StyleDirectionWarm extends StatelessWidget {
  const StyleDirectionWarm({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) =>
      _StyleDemo(tint: tint, variant: StyleVariant.warm);
}

class _StyleDemo extends StatefulWidget {
  const _StyleDemo({required this.tint, required this.variant});

  final Color tint;
  final StyleVariant variant;

  @override
  State<_StyleDemo> createState() => _StyleDemoState();
}

class _StyleDemoState extends State<_StyleDemo> {
  static const int _years = 20;
  static const double _start = 1000;

  double _rate = 0.10;
  bool _revealed = true;

  List<double> get _series => List.generate(
        _years + 1,
        (y) => _start * _powd(1 + _rate, y),
      );

  void _replay() {
    HapticFeedback.lightImpact();
    setState(() => _revealed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = _Spec.of(widget.variant, scheme, widget.tint);
    final series = _series;
    final last = series.last;

    return Container(
      decoration: BoxDecoration(
        color: spec.cardColor,
        borderRadius: BorderRadius.circular(spec.radius),
        border: spec.border,
        boxShadow: spec.shadow,
      ),
      padding: EdgeInsets.all(spec.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _variantPill(spec),
          SizedBox(height: spec.gap),
          _header(spec),
          SizedBox(height: spec.gap),
          AspectRatio(
            aspectRatio: 1.95,
            child: _chart(spec, series),
          ),
          SizedBox(height: spec.gap),
          _resultRow(spec, last),
          SizedBox(height: spec.gap),
          _slider(spec),
          SizedBox(height: spec.gap * 0.75),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _replay,
              style: FilledButton.styleFrom(
                backgroundColor: widget.tint,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: spec.buttonV),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(spec.radius * 0.7),
                ),
              ),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Проиграть заново'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(
          begin: 0.06,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _variantPill(_Spec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        spec.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: widget.tint,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _header(_Spec spec) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сложный процент',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          '1000 ₽, реинвест каждый год, $_years лет',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _chart(_Spec spec, List<double> series) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final spots = [
      for (var y = 0; y <= _years; y++)
        FlSpot(y.toDouble(), _revealed ? series[y] : _start),
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _years.toDouble(),
        minY: 0,
        maxY: series.last * 1.08,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (v, meta) => Text(
                '${v.toInt()}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: widget.tint,
            barWidth: spec.lineWidth,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.tint.withValues(alpha: spec.fillAlpha),
                  widget.tint.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _resultRow(_Spec spec, double last) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final multiple = last / _start;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'через $_years лет',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                '${_money(last)} ₽',
                style: text.titleMedium?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: widget.tint,
                ),
              ),
            ],
          ),
        ),
        _chip(spec, '×${multiple.toStringAsFixed(1)}'),
      ],
    );
  }

  Widget _chip(_Spec spec, String label) {
    final text = Theme.of(context).textTheme;
    final style = text.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: spec.chipFg,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: spec.chipBg,
        borderRadius: BorderRadius.circular(spec.chipRadius),
        border: spec.chipBorder,
      ),
      child: Text(label, style: style),
    );
  }

  Widget _slider(_Spec spec) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ставка',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              '${(_rate * 100).round()}% годовых',
              style: text.labelMedium?.copyWith(
                color: widget.tint,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.tint,
            thumbColor: widget.tint,
            overlayColor: widget.tint.withValues(alpha: 0.12),
            inactiveTrackColor: scheme.outlineVariant.withValues(alpha: 0.5),
            trackHeight: 4,
          ),
          child: Slider(
            value: _rate,
            min: 0.04,
            max: 0.16,
            divisions: 12,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _rate = v);
            },
          ),
        ),
      ],
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

/// Разрешённые визуальные параметры одного варианта — вычисляются из темы
/// и акцента в момент сборки. Это «сырьё» для будущих токенов block_kit.
class _Spec {
  const _Spec({
    required this.label,
    required this.cardColor,
    required this.radius,
    required this.padding,
    required this.gap,
    required this.shadow,
    required this.border,
    required this.lineWidth,
    required this.fillAlpha,
    required this.buttonV,
    required this.chipBg,
    required this.chipFg,
    required this.chipRadius,
    required this.chipBorder,
  });

  final String label;
  final Color cardColor;
  final double radius;
  final double padding;
  final double gap;
  final List<BoxShadow> shadow;
  final Border? border;
  final double lineWidth;
  final double fillAlpha;
  final double buttonV;
  final Color chipBg;
  final Color chipFg;
  final double chipRadius;
  final Border? chipBorder;

  factory _Spec.of(StyleVariant v, ColorScheme scheme, Color tint) {
    final isDark = scheme.brightness == Brightness.dark;
    // На тёмной теме тени читаются плохо — гасим, оставляя различие в карточке.
    double sh(double a) => isDark ? a * 0.0 : a;

    switch (v) {
      case StyleVariant.airy:
        return _Spec(
          label: 'A · Воздух',
          cardColor: scheme.surface,
          radius: 20,
          padding: 20,
          gap: 16,
          shadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: sh(0.06)),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
          border: isDark
              ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4))
              : null,
          lineWidth: 3,
          fillAlpha: 0.18,
          buttonV: 14,
          chipBg: tint.withValues(alpha: 0.12),
          chipFg: tint,
          chipRadius: 12,
          chipBorder: null,
        );
      case StyleVariant.crisp:
        return _Spec(
          label: 'B · Чёткий',
          cardColor: scheme.surface,
          radius: 14,
          padding: 16,
          gap: 13,
          shadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: sh(0.04)),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          lineWidth: 2.5,
          fillAlpha: 0.10,
          buttonV: 12,
          chipBg: Colors.transparent,
          chipFg: tint,
          chipRadius: 8,
          chipBorder: Border.all(color: tint.withValues(alpha: 0.5)),
        );
      case StyleVariant.warm:
        return _Spec(
          label: 'C · Тёплый акцент',
          cardColor: Color.alphaBlend(
            tint.withValues(alpha: isDark ? 0.10 : 0.05),
            scheme.surface,
          ),
          radius: 18,
          padding: 18,
          gap: 15,
          shadow: [
            BoxShadow(
              color: tint.withValues(alpha: sh(0.12)),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
          border: null,
          lineWidth: 3.5,
          fillAlpha: 0.26,
          buttonV: 14,
          chipBg: tint,
          chipFg: Colors.white,
          chipRadius: 12,
          chipBorder: null,
        );
    }
  }
}
