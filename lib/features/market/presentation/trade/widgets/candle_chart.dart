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
  /// Сколько последних свечей показываем: при большем количестве свечи
  /// становятся нечитаемо тонкими.
  static const int _visibleCount = 20;

  /// Время выбранной свечи. Выделение и панель данных резолвятся в индекс
  /// на каждый кадр (живой поток может заменить сам объект свечи).
  DateTime? _selectedTs;

  /// Видимое окно: только валидные свечи, не больше [_visibleCount] последних.
  /// И painter, и обработка тапа работают с одним этим списком — иначе
  /// индексы разъезжаются.
  List<Candle> get _visible {
    final valid = widget.data.where((c) => c.isValid).toList();
    return valid.length > _visibleCount
        ? valid.sublist(valid.length - _visibleCount)
        : valid;
  }

  /// Индекс выбранной свечи в видимом окне. Поток обновляет текущий бар и
  /// может прислать дубль с тем же временем — берём последнее вхождение,
  /// поэтому выделяется ровно одна свеча.
  int? get _selectedIndex {
    final ts = _selectedTs;
    if (ts == null) return null;
    final i = _visible.lastIndexWhere(
      (c) => c.ts.millisecondsSinceEpoch == ts.millisecondsSinceEpoch,
    );
    return i < 0 ? null : i;
  }

  void _handleTap(TapDownDetails details) {
    final data = _visible;
    if (data.isEmpty) return;

    const paddingLeft = 48.0;
    const paddingRight = 12.0;
    final chartWidth = context.size!.width - paddingLeft - paddingRight;

    final tapX = details.localPosition.dx - paddingLeft;

    // Если нажали вне графика, показываем последнюю свечу
    if (tapX < 0 || tapX > chartWidth) {
      setState(() => _selectedTs = data.last.ts);
      return;
    }

    final candleWidth = chartWidth / data.length;
    final index = (tapX / candleWidth).floor().clamp(0, data.length - 1);
    setState(() => _selectedTs = data[index].ts);
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
    final data = _visible;
    final selectedIndex = _selectedIndex;
    final selected = selectedIndex == null ? null : data[selectedIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: GestureDetector(
            onTapDown: _handleTap,
            child: CustomPaint(
              painter: CandlePainter(
                data: data,
                scheme: widget.scheme,
                selectedIndex: selectedIndex,
              ),
              child: Container(),
            ),
          ),
        ),
        if (selected != null) ...[
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
                      onPressed: () => setState(() => _selectedTs = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CandleDataRow(
                  label: 'Цена на начало периода',
                  value: '${selected.open.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Цена на конец периода',
                  value: '${selected.close.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Максимальная цена',
                  value: '${selected.high.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Минимальная цена',
                  value: '${selected.low.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                  valueColor: AppColors.error,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Количество сделок',
                  value: selected.volume.toString(),
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Время свечи',
                  value: _formatCandleTime(selected.ts),
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
