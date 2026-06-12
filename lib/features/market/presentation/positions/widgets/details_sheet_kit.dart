import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';

/// Открывает стандартную шторку деталей (позиция, заявка, сделка) с
/// одинаковой формой и скруглением.
///
/// Высота ограничена ~двумя третями экрана: длинный список строк
/// прокручивается внутри, а шапка с крестиком и кнопка действия всегда
/// остаются на виду.
Future<void> showDetailsSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.66,
    ),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

/// Каркас шторки деталей: ручка, шапка с аватаром инструмента и заголовком,
/// прокручиваемый список строк и необязательная кнопка действия снизу.
class DetailsSheetShell extends StatelessWidget {
  const DetailsSheetShell({
    super.key,
    required this.symbol,
    required this.title,
    this.subtitle,
    required this.rows,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  /// Тикер инструмента — для аватара.
  final String symbol;

  /// Заголовок шапки (обычно тикер или «Покупка GAZP»).
  final String title;

  /// Подпись под заголовком (например, вид записи: «Лимитная заявка»).
  final String? subtitle;

  /// Строки с деталями (обычно [DetailsInfoRow]).
  final List<Widget> rows;

  /// Подпись кнопки действия снизу (нет — кнопка не показывается).
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = symbol.length > 2 ? symbol.substring(0, 2) : symbol;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                InstrumentAvatar(symbol: symbol, label: label, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(actionIcon ?? Icons.show_chart, size: 18),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Строка деталей: «название — значение» и человеческое пояснение под ними.
class DetailsInfoRow extends StatelessWidget {
  const DetailsInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    this.mono = false,
    this.valueColor,
  });

  final String label;
  final String value;

  /// Пояснение простым языком, что это значение означает.
  final String description;

  /// true — значение моноширинным шрифтом (числа, цены).
  final bool mono;

  /// Цвет значения (например, цвет статуса заявки).
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: mono
                      ? monoNum(size: 14, color: valueColor ?? scheme.onSurface)
                      : text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: valueColor,
                        ),
                ),
              ),
            ],
          ),
          Text(
            description,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Число без хвоста «.0» у целых.
String detailsNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Дата и время в коротком виде: «12.06.2026, 15:42:07».
String detailsDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
