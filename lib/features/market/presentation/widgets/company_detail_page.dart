import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/aloria_lore.dart';
import 'package:aloria/features/market/domain/macro_extras.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:aloria/features/market/presentation/widgets/reference_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Страница компании из справочника: лор, характер, облигации и то,
/// как её сектор обычно реагирует на фазы цикла.
class CompanyDetailPage extends ConsumerWidget {
  const CompanyDetailPage({super.key, required this.company});

  final CompanyLore company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sector = aloriaSectorOf(company.sectorSlug);
    final stage = companyStageMeta(company.stage);
    final bonds = aloriaBondsOfIssuer(company.symbol);
    final label = company.symbol.length > 2
        ? company.symbol.substring(0, 2)
        : company.symbol;

    return Scaffold(
      appBar: AppBar(title: Text(company.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              InstrumentAvatar(symbol: company.symbol, label: label, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          company.symbol,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        ReferenceChip(
                          icon: sector.icon,
                          label: sector.title,
                          color: scheme.primary,
                        ),
                        ReferenceChip(label: stage.label, color: stage.color),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(company.story, style: text.bodyLarge?.copyWith(height: 1.5)),
          const SizedBox(height: 18),
          Text(
            'Характер компании',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _TraitRow(
            icon: Icons.timeline_rounded,
            title: '${stage.label} компания',
            subtitle: stage.hint,
          ),
          _TraitRow(
            icon: Icons.payments_rounded,
            title: _dividendTrait(company.payout).title,
            subtitle: _dividendTrait(company.payout).hint,
          ),
          _TraitRow(
            icon: Icons.account_balance_rounded,
            title: _debtTrait(company.leverage).title,
            subtitle: _debtTrait(company.leverage).hint,
          ),
          _TraitRow(
            icon: Icons.show_chart_rounded,
            title: _volTrait(company.sigma).title,
            subtitle: _volTrait(company.sigma).hint,
          ),
          if (company.ceoName != null)
            _TraitRow(
              icon: Icons.person_rounded,
              title: company.ceoSinceDay != null
                  ? 'Руководитель: ${company.ceoName} '
                        '· с дня ${company.ceoSinceDay}'
                  : 'Руководитель: ${company.ceoName}',
              subtitle: 'Назначения и отставки выходят в новостях Алории.',
            ),
          const SizedBox(height: 10),
          const _HiddenTraitsHint(),
          if (bonds.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Облигации компании',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (final bond in bonds) _BondRow(bond: bond),
          ],
          const SizedBox(height: 18),
          Text(
            'Сектор «${sector.title}» и фазы цикла',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Это тенденция, не правило: конкретная новость может развернуть '
            'цену против «типичной» реакции.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final phase in cyclePhases)
            _PhaseRow(
              phaseLabel: phase.label,
              sensitivity:
                  sectorSensitivity[phase.regime]?[company.sectorSlug] ?? 0,
            ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () {
              final securities =
                  ref.read(marketSecuritiesProvider).valueOrNull ??
                  const <MarketSecurity>[];
              MarketSecurity? match;
              for (final s in securities) {
                if (s.symbol == company.symbol) {
                  match = s;
                  break;
                }
              }
              context.push('/market/${company.symbol}', extra: match);
            },
            icon: const Icon(Icons.candlestick_chart_rounded),
            label: Text('Открыть ${company.symbol} на бирже'),
          ),
        ],
      ),
    );
  }

  ({String title, String hint}) _dividendTrait(double payout) =>
      switch (payout) {
        >= 0.4 => (
          title: 'Щедрые дивиденды',
          hint: 'Отдаёт акционерам заметную долю прибыли каждый цикл.',
        ),
        >= 0.15 => (
          title: 'Умеренные дивиденды',
          hint: 'Делится частью прибыли, остальное вкладывает в развитие.',
        ),
        _ => (
          title: 'Почти без дивидендов',
          hint: 'Прибыль уходит в рост бизнеса, а не в выплаты.',
        ),
      };

  ({String title, String hint}) _debtTrait(double leverage) =>
      switch (leverage) {
        >= 0.5 => (
          title: 'Высокая долговая нагрузка',
          hint: 'Много кредитов: рост ключевой ставки бьёт по ней сильнее.',
        ),
        >= 0.3 => (
          title: 'Умеренный долг',
          hint: 'Кредиты есть, но изменения ставки переживает спокойнее.',
        ),
        _ => (
          title: 'Низкий долг',
          hint: 'Почти не зависит от кредитов и ключевой ставки напрямую.',
        ),
      };

  ({String title, String hint}) _volTrait(double sigma) => switch (sigma) {
    >= 0.018 => (
      title: 'Подвижная бумага',
      hint: 'Цена ходит широко даже без больших новостей.',
    ),
    <= 0.010 => (
      title: 'Спокойная бумага',
      hint: 'Двигается плавно, резкие скачки — редкость.',
    ),
    _ => (
      title: 'Обычная подвижность',
      hint: 'Волатильность средняя по рынку Алории.',
    ),
  };
}

class _TraitRow extends StatelessWidget {
  const _TraitRow({
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// Обучающая подсказка о скрытых чертах компании: устойчивость к кризисам
/// и качество управления в карточке не публикуются — их видно только по
/// поведению бумаги и новостям.
class _HiddenTraitsHint extends StatelessWidget {
  const _HiddenTraitsHint();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'У компании есть и скрытые черты — устойчивость к кризисам и '
              'качество управления. Их не пишут в карточке: смотри, как '
              'бумага проходит кризисы, сбываются ли прогнозы по отчётам, '
              'и следи за новостями о руководстве.',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BondRow extends StatelessWidget {
  const _BondRow({required this.bond});

  final BondLore bond;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = bondQualityMeta(bond.quality);
    final couponPct = (bond.couponPerCycle * 100).toStringAsFixed(1);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/market/${bond.symbol}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.receipt_long_rounded, size: 20, color: meta.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bond.name} · купон $couponPct% за цикл',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${meta.label}. ${meta.hint}',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.phaseLabel, required this.sensitivity});

  final String phaseLabel;
  final int sensitivity;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meta = sensitivityMeta(sensitivity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              phaseLabel,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(meta.icon, size: 18, color: meta.color),
          const SizedBox(width: 6),
          Text(
            meta.label,
            style: text.bodySmall?.copyWith(
              color: meta.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
