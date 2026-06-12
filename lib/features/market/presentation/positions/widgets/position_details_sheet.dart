import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Открывает шторку со всей детальной информацией по позиции. Кнопка
/// «Торговать инструментом» внутри шторки переключает на ветку «Рынок».
Future<void> showPositionDetails(BuildContext context, Position position) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PositionDetailsSheet(
      position: position,
      onTrade: () {
        Navigator.of(ctx).pop();
        context.go(
          '/market/${position.symbol}',
          extra: MarketSecurity(
            symbol: position.symbol,
            shortName: position.symbol,
            exchange: position.exchange,
          ),
        );
      },
    ),
  );
}

class _PositionDetailsSheet extends StatelessWidget {
  const _PositionDetailsSheet({required this.position, required this.onTrade});

  final Position position;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = position.symbol.length > 2
        ? position.symbol.substring(0, 2)
        : position.symbol;

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
                InstrumentAvatar(
                  symbol: position.symbol,
                  label: label,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    position.symbol,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                  children: [
                    _infoRow(
                      context,
                      label: 'Тикер',
                      value: position.symbol,
                      description: 'Краткое название инструмента на бирже.',
                    ),
                    _infoRow(
                      context,
                      label: 'Количество',
                      value: '${position.quantity} шт.',
                      description: 'Количество ценных бумаг в вашем портфеле.',
                      mono: true,
                    ),
                    _infoRow(
                      context,
                      label: 'Средняя цена',
                      value: '${position.averagePrice} ${position.currency}',
                      description:
                          'Цена покупки (усредненная, если было несколько сделок).',
                      mono: true,
                    ),
                    _infoRow(
                      context,
                      label: 'Текущая стоимость',
                      value: '${position.currentVolume} ${position.currency}',
                      description:
                          'Рыночная стоимость всего пакета бумаг сейчас.',
                      mono: true,
                    ),
                    if (position.unrealisedPl != null)
                      _infoRow(
                        context,
                        label: 'Нереализованная П/У',
                        value:
                            '${position.unrealisedPl! >= 0 ? '+' : ''}${position.unrealisedPl!.toStringAsFixed(2)} ${position.currency}',
                        description:
                            'Текущая доходность позиции (прибыль или убыток).',
                        mono: true,
                      ),
                    _infoRow(
                      context,
                      label: 'Биржа',
                      value: position.exchange,
                      description: 'Торговая площадка, где куплен инструмент.',
                    ),
                  ],
                ),
              ),
            ),
            // RUB — это денежная позиция (кэш), а не торгуемый инструмент,
            // поэтому кнопку перехода в торговлю для неё не показываем.
            if (position.symbol.toUpperCase() != 'RUB') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTrade,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Торговать инструментом'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    required String description,
    bool mono = false,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                      ? monoNum(size: 15, color: scheme.onSurface)
                      : text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
