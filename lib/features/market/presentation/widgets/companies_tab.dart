import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/application/market_reference_provider.dart';
import 'package:aloria/features/market/domain/aloria_lore.dart';
import 'package:aloria/features/market/domain/reference_catalog.dart';
import 'package:aloria/features/market/presentation/widgets/reference_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Вкладка «Компании»: справочник мира Алории — кто есть на бирже,
/// чем занимается и какие облигации выпустил.
class CompaniesTab extends ConsumerWidget {
  const CompaniesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securities =
        ref.watch(marketSecuritiesProvider).valueOrNull ?? const [];
    // Пока каталог грузится (или бэк недоступен) — статический фолбэк,
    // чтобы вкладка не мигала скелетоном.
    final catalog =
        ref.watch(marketReferenceProvider).valueOrNull ??
        const ReferenceCatalog.fallback();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(child: _WorldIntroCard(catalog: catalog)),
        ),
        for (final sector in catalog.sectors) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            sliver: SliverToBoxAdapter(child: _SectorHeader(sector: sector)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: [
                for (final company in catalog.companiesOfSector(sector.slug))
                  CompanyTile(
                    company: company,
                    catalog: catalog,
                    securities: securities,
                  ),
              ],
            ),
          ),
        ],
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 4),
          sliver: SliverToBoxAdapter(
            child: ReferenceSectionHeader(
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
              for (final bond in catalog.bonds)
                BondTile(bond: bond, catalog: catalog, securities: securities),
            ],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 4),
          sliver: SliverToBoxAdapter(
            child: ReferenceSectionHeader(
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
              for (final fund in catalog.funds)
                FundTile(fund: fund, securities: securities),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorldIntroCard extends StatelessWidget {
  const _WorldIntroCard({required this.catalog});

  final ReferenceCatalog catalog;

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
            'торгуются ${catalog.companies.length} компаний из '
            '${catalog.sectors.length} секторов, облигации государства и '
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
    return ReferenceSectionHeader(
      icon: sector.icon,
      title: sector.title,
      subtitle: sector.description,
    );
  }
}
