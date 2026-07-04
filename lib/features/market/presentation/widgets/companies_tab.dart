import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/aloria_lore.dart';
import 'package:aloria/features/market/presentation/widgets/company_detail_page.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Вкладка «Компании»: справочник мира Алории — кто есть на бирже,
/// чем занимается и какие облигации выпустил.
class CompaniesTab extends ConsumerWidget {
  const CompaniesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securities =
        ref.watch(marketSecuritiesProvider).valueOrNull ?? const [];

    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(child: _WorldIntroCard()),
        ),
        for (final sector in aloriaSectors) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            sliver: SliverToBoxAdapter(child: _SectorHeader(sector: sector)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: [
                for (final company in aloriaCompanies.where(
                  (c) => c.sectorSlug == sector.slug,
                ))
                  _CompanyTile(company: company, securities: securities),
              ],
            ),
          ),
        ],
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 4),
          sliver: SliverToBoxAdapter(
            child: _SimpleHeader(
              icon: Icons.receipt_long_rounded,
              title: 'Облигации',
              subtitle: 'Государство и компании занимают в долг под купоны',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: [
              for (final bond in aloriaBonds)
                _BondTile(bond: bond, securities: securities),
            ],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 4),
          sliver: SliverToBoxAdapter(
            child: _SimpleHeader(
              icon: Icons.pie_chart_rounded,
              title: 'Фонды',
              subtitle: 'Готовые корзины — весь рынок одним паем',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              for (final fund in aloriaFunds)
                _FundTile(fund: fund, securities: securities),
            ],
          ),
        ),
      ],
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

class _WorldIntroCard extends StatelessWidget {
  const _WorldIntroCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Мир Алории',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Алория — вымышленная страна со своей биржей TEREX. На ней '
            'торгуются ${aloriaCompanies.length} компаний из '
            '${aloriaSectors.length} секторов, облигации государства и '
            'компаний и два фонда. У каждой компании свой характер: кто-то '
            'щедро платит дивиденды, кто-то живёт в долг и вздрагивает от '
            'каждой новости.',
            style: text.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectorHeader extends StatelessWidget {
  const _SectorHeader({required this.sector});

  final SectorLore sector;

  @override
  Widget build(BuildContext context) {
    return _SimpleHeader(
      icon: sector.icon,
      title: sector.title,
      subtitle: sector.description,
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  const _SimpleHeader({
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

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({required this.company, required this.securities});

  final CompanyLore company;
  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bonds = aloriaBondsOfIssuer(company.symbol);
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
            if (bonds.isNotEmpty) ...[
              const SizedBox(width: 8),
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

class _BondTile extends StatelessWidget {
  const _BondTile({required this.bond, required this.securities});

  final BondLore bond;
  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = bondQualityMeta(bond.quality);
    final issuer = bond.issuerSymbol == null
        ? 'Государство Алории'
        : aloriaCompanyBySymbol(bond.issuerSymbol!)?.name ?? bond.issuerSymbol!;
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                meta.label,
                style: text.labelSmall?.copyWith(
                  color: meta.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundTile extends StatelessWidget {
  const _FundTile({required this.fund, required this.securities});

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

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
