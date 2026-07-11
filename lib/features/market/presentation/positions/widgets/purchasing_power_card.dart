import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_macro_repository.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/purchasing_power.dart';
import 'package:aloria/features/market/presentation/positions/widgets/details_sheet_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Компактная строка под hero-карточкой портфеля: рост цен со старта ученика.
/// По тапу — шторка «Деньги и инфляция» с покупательной способностью и
/// реальной доходностью. Прототип: расчёт на мок-данных (см. purchasing_power).
class PurchasingPowerCard extends ConsumerWidget {
  const PurchasingPowerCard({super.key, required this.summary});

  final AsyncValue<PortfolioSummary> summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final macro = ref.watch(macroStateProvider).valueOrNull;
    if (macro == null) return const SizedBox.shrink();

    final info = buildMockPurchasingPower(macro, summary.valueOrNull);
    final realNegative = info.realReturnPct < 0;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSheet(context, info),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Цены выросли на ${info.priceGrowthPct.toStringAsFixed(1)}% '
                      'с твоего старта',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Портфель в реальном выражении: '
                      '${signedPct(info.realReturnPct)}',
                      style: text.bodySmall?.copyWith(
                        color: realNegative
                            ? AppColors.error
                            : AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, PurchasingPowerInfo info) {
    showDetailsSheet(context, (_) => _PurchasingPowerSheet(info: info));
  }
}

/// Шторка «Деньги и инфляция»: три числа, каждое с человеческим пояснением.
class _PurchasingPowerSheet extends StatelessWidget {
  const _PurchasingPowerSheet({required this.info});

  final PurchasingPowerInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: (bottomInset - 18).clamp(8.0, 40.0)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 21,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Деньги и инфляция',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Со старта прошло ${info.cyclesSinceStart} цикла '
                            '(«${info.cyclesSinceStart} года» Алории)',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DetailsInfoRow(
                  label: 'Цены в Алории выросли',
                  value: '+${info.priceGrowthPct.toStringAsFixed(1)}%',
                  valueColor: AppColors.warning,
                  mono: true,
                  description:
                      'Накопленная инфляция с момента, когда ты начал(а). '
                      'То, что стоило 100 ₽, теперь стоит '
                      '${(100 * (1 + info.priceGrowthPct / 100)).toStringAsFixed(0)} ₽.',
                ),
                DetailsInfoRow(
                  label: 'Свободные деньги покупают меньше',
                  value: '−${info.cashLossPct.toStringAsFixed(1)}%',
                  valueColor: AppColors.error,
                  mono: true,
                  description: info.freeCash > 0
                      ? 'Твои свободные ${_fmtMoney(info.freeCash)} ₽ сегодня '
                            'покупают столько же, сколько тогда покупали '
                            '${_fmtMoney(info.freeCashThen)} ₽. Деньги, которые '
                            'просто лежат, каждый цикл покупают чуть меньше.'
                      : 'Деньги, которые просто лежат, каждый цикл покупают '
                            'чуть меньше — это и есть инфляция в действии.',
                ),
                DetailsInfoRow(
                  label: 'Портфель: номинально / реально',
                  value:
                      '${signedPct(info.nominalReturnPct)} / '
                      '${signedPct(info.realReturnPct)}',
                  valueColor: info.realReturnPct < 0
                      ? AppColors.error
                      : AppColors.success,
                  mono: true,
                  description:
                      'Номинальная доходность — рост в рублях. Реальная — '
                      'с поправкой на выросшие цены: именно она показывает, '
                      'стал(а) ли ты богаче. Обгонять инфляцию — одна из '
                      'главных задач инвестора.',
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Активы могут расти быстрее цен — а могут и не '
                          'успевать. Смотри на реальную доходность, а не '
                          'только на плюс в рублях.',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Прототип: цифры демонстрационные',
                    style: text.bodySmall?.copyWith(
                      color: scheme.outline,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Целые рубли с разбиением тысяч пробелами: 12 345.
String _fmtMoney(double v) {
  final abs = v.abs().truncate().toString();
  final buf = StringBuffer(v < 0 ? '−' : '');
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
    buf.write(abs[i]);
  }
  return buf.toString();
}
