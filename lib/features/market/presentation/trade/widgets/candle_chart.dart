import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/presentation/trade/widgets/candle_painter.dart';
import 'package:flutter/material.dart';

/// Свечной график с выбором свечи тапом и панелью данных выбранной свечи.
class CandleChart extends StatefulWidget {
  const CandleChart({super.key, required this.data, required this.scheme});

  /// Свечи для отрисовки.
  final List<Candle> data;

  /// Цветовая схема текущей темы.
  final ColorScheme scheme;

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> {
  Candle? _selectedCandle;

  @override
  void didUpdateWidget(CandleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если свеча была выбрана, обновляем её данные при изменении widget.data
    if (_selectedCandle != null) {
      final updatedCandle = widget.data.firstWhere(
        (c) =>
            c.ts.millisecondsSinceEpoch ==
            _selectedCandle!.ts.millisecondsSinceEpoch,
        orElse: () => _selectedCandle!,
      );
      if (updatedCandle != _selectedCandle) {
        setState(() {
          _selectedCandle = updatedCandle;
        });
      }
    }
  }

  void _handleTap(TapDownDetails details) {
    if (widget.data.isEmpty) return;

    const paddingLeft = 48.0;
    const paddingRight = 12.0;
    final chartWidth = context.size!.width - paddingLeft - paddingRight;

    final tapX = details.localPosition.dx - paddingLeft;

    // Если нажали вне графика, показываем последнюю свечу
    if (tapX < 0 || tapX > chartWidth) {
      setState(() {
        _selectedCandle = widget.data.last;
      });
      return;
    }

    final candleWidth = chartWidth / widget.data.length;
    final index = (tapX / candleWidth).floor();

    if (index >= 0 && index < widget.data.length) {
      setState(() {
        _selectedCandle = widget.data[index];
      });
    }
  }

  String _formatCandleTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: GestureDetector(
            onTapDown: _handleTap,
            child: CustomPaint(
              painter: CandlePainter(
                data: widget.data,
                scheme: widget.scheme,
                selectedCandle: _selectedCandle,
              ),
              child: Container(),
            ),
          ),
        ),
        if (_selectedCandle != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Данные свечи',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: widget.scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _selectedCandle = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CandleDataRow(
                  label: 'Цена на начало периода',
                  value: '${_selectedCandle!.open.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Цена на конец периода',
                  value: '${_selectedCandle!.close.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Максимальная цена',
                  value: '${_selectedCandle!.high.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Минимальная цена',
                  value: '${_selectedCandle!.low.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                  valueColor: AppColors.error,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Количество сделок',
                  value: _selectedCandle!.volume.toString(),
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Время свечи',
                  value: _formatCandleTime(_selectedCandle!.ts),
                  scheme: widget.scheme,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CandleDataRow extends StatelessWidget {
  const _CandleDataRow({
    required this.label,
    required this.value,
    required this.scheme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
