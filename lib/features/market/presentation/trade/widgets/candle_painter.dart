import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:flutter/material.dart';

/// Painter свечного графика: оси, тики цен/времени, свечи с фитилями и
/// подсветка выбранной свечи.
class CandlePainter extends CustomPainter {
  CandlePainter({
    required this.data,
    required this.scheme,
    this.selectedCandle,
  });

  /// Свечи для отрисовки.
  final List<Candle> data;

  /// Цветовая схема текущей темы.
  final ColorScheme scheme;

  /// Выбранная тапом свеча (подсвечивается).
  final Candle? selectedCandle;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final valid = data.where((c) => c.isValid).toList();
    if (valid.isEmpty) return;

    const paddingLeft = 48.0;
    const paddingRight = 12.0;
    const paddingTop = 8.0;
    const paddingBottom = 24.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final lows = valid.map((c) => c.low).toList();
    final highs = valid.map((c) => c.high).toList();
    final minP = lows.reduce((a, b) => a < b ? a : b);
    final maxP = highs.reduce((a, b) => a > b ? a : b);

    // Добавляем отступы сверху и снизу (10% от диапазона)
    final rawRange = (maxP - minP).abs();
    final padding = rawRange < 1e-9 ? 0.5 : rawRange * 0.1;
    final paddedMin = minP - padding;
    final paddedMax = maxP + padding;
    final range = paddedMax - paddedMin;

    double priceToY(double price) {
      final normalized = (price - paddedMin) / range;
      return paddingTop + chartHeight - normalized * chartHeight;
    }

    final paintWick = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.8)
      ..strokeWidth = 1.4;

    final axisPaint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      fontFamily: 'Nunito',
      fontFamilyFallback: const ['Nunito', 'sans-serif'],
    );

    // Axes
    final xAxisY = paddingTop + chartHeight;
    canvas.drawLine(
      const Offset(paddingLeft, paddingTop),
      Offset(paddingLeft, xAxisY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(paddingLeft, xAxisY),
      Offset(size.width - paddingRight, xAxisY),
      axisPaint,
    );

    // Y ticks (min, mid, max)
    final yTicks = [paddedMin, paddedMin + range / 2, paddedMax];
    for (final value in yTicks) {
      final y = priceToY(value);
      canvas.drawLine(
        Offset(paddingLeft - 4, y),
        Offset(paddingLeft, y),
        axisPaint,
      );
      final textSpan = TextSpan(
        text: value.toStringAsFixed(2),
        style: labelStyle,
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - tp.height / 2));
    }

    // X ticks (start/end time)
    String fmtTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    const firstX = paddingLeft;
    final lastX = paddingLeft + chartWidth;
    final firstLabel = fmtTime(valid.first.ts);
    final lastLabel = fmtTime(valid.last.ts);
    final firstTp = TextPainter(
      text: TextSpan(text: firstLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final lastTp = TextPainter(
      text: TextSpan(text: lastLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    firstTp.paint(canvas, Offset(firstX, xAxisY + 4));
    lastTp.paint(canvas, Offset(lastX - lastTp.width, xAxisY + 4));

    // Candles
    final candleWidth = chartWidth / (valid.length * 1.1);
    final space = candleWidth * 0.1;
    for (var i = 0; i < valid.length; i++) {
      final c = valid[i];
      final x = paddingLeft + i * (candleWidth + space) + candleWidth / 2;

      // Подсветка выбранной свечи
      final isSelected =
          selectedCandle != null &&
          c.ts.millisecondsSinceEpoch ==
              selectedCandle!.ts.millisecondsSinceEpoch;

      if (isSelected) {
        final highlightPaint = Paint()
          ..color = scheme.primary.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(
            x - candleWidth / 2 - 2,
            paddingTop,
            candleWidth + 4,
            chartHeight,
          ),
          highlightPaint,
        );
      }

      // Wick
      canvas.drawLine(
        Offset(x, priceToY(c.high)),
        Offset(x, priceToY(c.low)),
        paintWick,
      );

      final isUp = c.close >= c.open;
      final bodyPaint = Paint()
        ..color = isUp
            ? AppColors.success
            : AppColors.error.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      final top = priceToY(isUp ? c.close : c.open);
      final bottom = priceToY(isUp ? c.open : c.close);
      final rect = Rect.fromLTWH(
        x - candleWidth / 2,
        top,
        candleWidth,
        (bottom - top).abs().clamp(1.0, chartHeight),
      );
      canvas.drawRect(rect, bodyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
