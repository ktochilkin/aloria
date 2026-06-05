import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про цену облигации: качели «ключевая ставка ↔ цена».
/// Пользователь двигает ставку ЦБ, и цена облигации с фиксированным купоном
/// идёт в обратную сторону — коромысло наклоняется. Делает осязаемым правило
/// «ставка вверх — цена вниз».
class LessonRatePriceSeesaw extends StatefulWidget {
  const LessonRatePriceSeesaw({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonRatePriceSeesaw> createState() => _LessonRatePriceSeesawState();
}

class _LessonRatePriceSeesawState extends State<LessonRatePriceSeesaw> {
  // Облигация с фиксированным купоном 8% от номинала 1000.
  static const double _nominal = 1000;
  static const double _couponRate = 0.08;

  double _rate = 0.08; // ключевая ставка, старт = купону → цена у номинала

  // Грубая модель: цена тем ниже, чем выше требуемая доходность.
  double get _price => _nominal * _couponRate / _rate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Наклон коромысла: ставка выше купона → цена вниз (правый край опускается).
    final tilt = ((_rate - _couponRate) * 4).clamp(-0.35, 0.35);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: _Beam(
              tilt: tilt,
              tint: widget.tint,
              leftLabel: 'ставка',
              leftValue: '${(_rate * 100).toStringAsFixed(0)}%',
              rightLabel: 'цена',
              rightValue: '${_price.round()} ₽',
              rightColor: _rate > _couponRate
                  ? AppColors.error
                  : AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.account_balance, size: 16, color: widget.tint),
              const SizedBox(width: 6),
              Text(
                'Ключевая ставка ЦБ',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${(_rate * 100).toStringAsFixed(0)}%',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            value: _rate,
            min: 0.04,
            max: 0.20,
            divisions: 16,
            activeColor: widget.tint,
            onChanged: (v) => setState(() => _rate = v),
          ),
          Text(
            _rate > _couponRate
                ? 'Ставка выше купона → твоя облигация дешевле номинала'
                : _rate < _couponRate
                    ? 'Ставка ниже купона → облигация дороже номинала'
                    : 'Ставка равна купону → цена около номинала',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Коромысло качелей: горизонтальная балка, наклонённая на [tilt] радиан,
/// с грузами-подписями на концах и опорой-треугольником в центре.
class _Beam extends StatelessWidget {
  const _Beam({
    required this.tilt,
    required this.tint,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.rightColor,
  });

  final double tilt;
  final Color tint;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Опора.
        Positioned(
          bottom: 0,
          child: CustomPaint(
            size: const Size(40, 34),
            painter: _PivotPainter(color: tint.withValues(alpha: 0.6)),
          ),
        ),
        // Балка с грузами.
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: AnimatedRotation(
            turns: tilt / (2 * 3.14159),
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Weight(
                  label: leftLabel,
                  value: leftValue,
                  color: tint,
                ),
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                _Weight(
                  label: rightLabel,
                  value: rightValue,
                  color: rightColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Weight extends StatelessWidget {
  const _Weight({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(color: color),
          ),
          Text(
            value,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PivotPainter extends CustomPainter {
  _PivotPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PivotPainter old) => old.color != color;
}
