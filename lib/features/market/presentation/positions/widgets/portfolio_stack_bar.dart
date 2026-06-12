import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Горизонтальный стек-бар распределения портфеля по позициям с легендой.
/// Доли считаются от суммарной текущей стоимости; long-tail позиций
/// сворачивается в серый сегмент «Прочие».
class PortfolioStackBar extends StatelessWidget {
  const PortfolioStackBar({super.key, required this.positions});

  /// Открытые позиции (с ненулевым количеством).
  final List<Position> positions;

  // Палитра по спецификации: 6 цветов, серый — для «Прочих» в long-tail.
  static const _palette = AppChartPalette.categorical;
  static const _restColor = AppChartPalette.neutral;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sorted = [...positions]
      ..sort((a, b) => b.currentVolume.abs().compareTo(a.currentVolume.abs()));
    final total = sorted.fold<double>(0, (s, p) => s + p.currentVolume.abs());
    if (total <= 0) return const SizedBox.shrink();

    final topItems = <(Position pos, Color color, double share)>[];
    final useRest = sorted.length > 8;
    final visibleCount = useRest ? _palette.length - 1 : sorted.length;
    for (var i = 0; i < sorted.length && i < visibleCount; i++) {
      final share = sorted[i].currentVolume.abs() / total;
      topItems.add((sorted[i], _palette[i % _palette.length], share));
    }
    final restShare = useRest
        ? sorted
            .skip(visibleCount)
            .fold<double>(0, (s, p) => s + p.currentVolume.abs() / total)
        : 0.0;
    final hasRest = restShare > 0.001;

    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.portfolioDistribution,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Text(
              l.portfolioCount(sorted.length),
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 8,
          child: Row(
            children: [
              for (var i = 0; i < topItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (topItems[i].$3 * 1000).round().clamp(1, 1000),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(color: topItems[i].$2),
                  ),
                ),
              ],
              if (hasRest) ...[
                const SizedBox(width: 2),
                Expanded(
                  flex: (restShare * 1000).round().clamp(1, 1000),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(color: _restColor),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final item in topItems)
              _LegendItem(
                color: item.$2,
                symbol: item.$1.symbol,
                share: item.$3,
              ),
            if (hasRest)
              _LegendItem(
                color: _restColor,
                symbol: 'Прочие',
                share: restShare,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.symbol,
    required this.share,
  });

  final Color color;
  final String symbol;
  final double share;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          symbol,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${(share * 100).round()}%',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
