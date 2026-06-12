import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_stack_bar.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hero-карточка портфеля: оценка, кнопка пополнения, сводка
/// «в позициях / покупательная способность / П-У» и стек-бар распределения.
class PortfolioHero extends StatelessWidget {
  const PortfolioHero({
    super.key,
    required this.summary,
    required this.positions,
    required this.onTopUp,
  });

  /// Сводка портфеля (оценка, покупательная способность).
  final AsyncValue<PortfolioSummary> summary;

  /// Позиции портфеля.
  final AsyncValue<List<Position>> positions;

  /// Открыть экран пополнения (расширения доступа).
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final positionsList = positions.maybeWhen(
      data: (l) => l.where((p) => p.quantity != 0).toList(),
      orElse: () => const <Position>[],
    );

    final summaryValue = summary.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );

    final positionsTotal = positionsList.fold<double>(
      0,
      (s, p) => s + p.currentVolume.abs(),
    );
    final totalPl = positionsList.fold<double>(
      0,
      (s, p) => s + (p.unrealisedPl ?? 0),
    );
    final hasPl = positionsList.any((p) => p.unrealisedPl != null);
    final plPercent = positionsTotal > 0
        ? (totalPl / positionsTotal) * 100
        : 0.0;

    final buyingPower = summaryValue?.buyingPower ?? 0;
    final liquidationValue =
        summaryValue?.liquidationValue ?? buyingPower + positionsTotal;

    final currencySymbol = summaryValue?.currency == 'USD'
        ? '\$'
        : summaryValue?.currency == 'EUR'
            ? '€'
            : '₽';

    final isLoading = summary.isLoading && summaryValue == null;
    final hasError = summary.hasError && summaryValue == null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Диагональный sheen: едва заметный перелив угол-в-угол —
          // коралл сверху-слева, чистый центр, синий снизу-справа.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.12),
                      Colors.transparent,
                      AppColors.primary.withValues(alpha: 0.09),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            AppLocalizations.of(context)!.portfolioEvaluationCaption,
            style: text.bodySmall?.copyWith(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            const _HeroLoading()
          else if (hasError)
            Text(
              'Нет данных',
              style: text.bodyLarge?.copyWith(color: scheme.error),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      maxLines: 1,
                      text: TextSpan(
                        style: GoogleFonts.nunito(
                          color: scheme.onSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: -0.8,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        children: [
                          TextSpan(text: _formatMoney(liquidationValue)),
                          TextSpan(
                            text: ' $currencySymbol',
                            style: GoogleFonts.nunito(
                              color: scheme.onSurfaceVariant,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _TopUpPill(onTap: onTopUp),
              ],
            ),
          const SizedBox(height: 14),
          const _HeroDivider(),
          const SizedBox(height: 12),
          _PortfolioSummaryRow(
            inPositions: positionsTotal,
            buyingPower: buyingPower,
            plPercent: hasPl ? plPercent : null,
            plPositive: totalPl >= 0,
            currencySymbol: currencySymbol,
          ),
          if (positionsList.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _HeroDivider(),
            const SizedBox(height: 14),
            PortfolioStackBar(positions: positionsList),
          ] else if (summaryValue != null && buyingPower > 0) ...[
            const SizedBox(height: 14),
            const _HeroDivider(),
            const SizedBox(height: 14),
            Text(
              'Нет открытых позиций · перейти к обзору рынка',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLoading extends StatelessWidget {
  const _HeroLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 32,
          width: 180,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.palette.heroBorder);
  }
}

class _TopUpPill extends StatelessWidget {
  const _TopUpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.portfolioTopUp,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioSummaryRow extends StatelessWidget {
  const _PortfolioSummaryRow({
    required this.inPositions,
    required this.buyingPower,
    required this.plPercent,
    required this.plPositive,
    required this.currencySymbol,
  });

  final double inPositions;
  final double buyingPower;
  final double? plPercent;
  final bool plPositive;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plColor = plPositive ? AppColors.success : AppColors.error;
    final plText = plPercent == null
        ? '—'
        : '${plPositive ? '+' : '−'}${plPercent!.abs().toStringAsFixed(2)}%';

    final l = AppLocalizations.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryColumn(
              caption: l.portfolioInPositions,
              value: '${_formatMoneyCompact(inPositions)} $currencySymbol',
              valueColor: scheme.onSurface,
            ),
          ),
          const _ColumnDivider(),
          Expanded(
            child: _SummaryColumn(
              caption: l.portfolioBuyingPower,
              value: '${_formatMoneyCompact(buyingPower)} $currencySymbol',
              valueColor: AppColors.primary,
            ),
          ),
          const _ColumnDivider(),
          Expanded(
            child: _SummaryColumn(
              caption: l.portfolioPnl,
              value: plText,
              valueColor: plPercent == null ? scheme.onSurface : plColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.caption,
    required this.value,
    required this.valueColor,
  });

  final String caption;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          caption,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: valueColor,
            fontWeight: FontWeight.w600,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ColumnDivider extends StatelessWidget {
  const _ColumnDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.palette.heroBorder,
    );
  }
}

String _formatMoney(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final neg = intPart.startsWith('-');
  final abs = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
    buf.write(abs[i]);
  }
  return '${neg ? '−' : ''}$buf,${parts[1]}';
}

String _formatMoneyCompact(double v) {
  final intPart = v.truncate().toString();
  final neg = intPart.startsWith('-');
  final abs = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
    buf.write(abs[i]);
  }
  return '${neg ? '−' : ''}$buf';
}
