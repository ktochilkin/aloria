import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/aloria_lore.dart';
import 'package:aloria/features/market/domain/reference_catalog.dart';
import 'package:aloria/features/market/presentation/widgets/company_detail_page.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Тайлы и заголовки справочника мира Алории (вкладка «Компании»).

/// Компактный чип с подписью и опциональной иконкой — сектор, стадия,
/// качество облигации.
class ReferenceChip extends StatelessWidget {
  const ReferenceChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Заголовок раздела справочника: иконка, название, подпись.
class ReferenceSectionHeader extends StatelessWidget {
  const ReferenceSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Тайл компании: аватар, имя, тема, чип стадии и счётчик облигаций.
class CompanyTile extends StatelessWidget {
  const CompanyTile({
    super.key,
    required this.company,
    required this.catalog,
    required this.securities,
  });

  final CompanyLore company;
  final ReferenceCatalog catalog;
  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bonds = catalog.bondsOfIssuer(company.symbol);
    final stage = companyStageMeta(company.stage);
    final label = company.symbol.length > 2
        ? company.symbol.substring(0, 2)
        : company.symbol;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CompanyDetailPage(company: company),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            InstrumentAvatar(symbol: company.symbol, label: label),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${company.symbol} · ${_capitalize(company.theme)}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ReferenceChip(label: stage.label, color: stage.color),
            if (bonds.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  bonds.length == 1
                      ? '1 облигация'
                      : '${bonds.length} облигации',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Тайл облигации: эмитент, купон и чип кредитного качества.
class BondTile extends StatelessWidget {
  const BondTile({
    super.key,
    required this.bond,
    required this.catalog,
    required this.securities,
  });

  final BondLore bond;
  final ReferenceCatalog catalog;
  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = bondQualityMeta(bond.quality);
    final issuer = bond.issuerSymbol == null
        ? 'Государство Алории'
        : catalog.companyBySymbol(bond.issuerSymbol!)?.name ??
              bond.issuerSymbol!;
    final couponPct = (bond.couponPerCycle * 100).toStringAsFixed(1);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openInstrument(context, bond.symbol, securities),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: meta.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bond.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$issuer · купон $couponPct% за цикл',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ReferenceChip(label: meta.label, color: meta.color),
          ],
        ),
      ),
    );
  }
}

/// Тайл фонда.
class FundTile extends StatelessWidget {
  const FundTile({super.key, required this.fund, required this.securities});

  final FundLore fund;
  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openInstrument(context, fund.symbol, securities),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pie_chart_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fund.name} · ${fund.symbol}',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fund.description,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Открывает инструмент, подложив живую котировку, если она уже загружена.
void _openInstrument(
  BuildContext context,
  String symbol,
  List<MarketSecurity> securities,
) {
  MarketSecurity? match;
  for (final s in securities) {
    if (s.symbol == symbol) {
      match = s;
      break;
    }
  }
  context.push('/market/$symbol', extra: match);
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
