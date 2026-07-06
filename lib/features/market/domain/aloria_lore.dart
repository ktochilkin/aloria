import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

export 'package:aloria/features/market/domain/aloria_companies.dart';

/// Справочник мира Алории: сектора, компании, облигации, фонды.
/// Зеркалит вселенную ИИ-режиссёра (Universe.cs). Статические данные —
/// фолбэк: живой каталог приезжает с aloria-api (reference-эндпоинт).
/// Список компаний вынесен в aloria_companies.dart и реэкспортируется отсюда.

/// Сектор экономики Алории.
class SectorLore {
  const SectorLore({
    required this.slug,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String slug;
  final String title;
  final IconData icon;
  final String description;
}

/// Стадия жизненного цикла компании.
enum CompanyStage { growth, mature, defensive }

/// Компания-эмитент с лором и чертами характера.
class CompanyLore {
  const CompanyLore({
    required this.symbol,
    required this.name,
    required this.sectorSlug,
    required this.stage,
    required this.theme,
    required this.story,
    required this.payout,
    required this.leverage,
    required this.sigma,
    this.ceoName,
    this.ceoSinceDay,
  });

  final String symbol;
  final String name;
  final String sectorSlug;

  /// Стадия компании: растущая / зрелая / защитная.
  final CompanyStage stage;

  /// Чем занимается, коротко.
  final String theme;

  /// Живой лор — пара предложений о компании.
  final String story;

  /// Доля прибыли на дивиденды [0..1].
  final double payout;

  /// Долговая нагрузка [0..1] — чем выше, тем чувствительнее к ставке.
  final double leverage;

  /// Дневная волатильность бумаги (лог).
  final double sigma;

  /// Текущий руководитель. null — бэк ещё не сообщил (в статике всегда null).
  final String? ceoName;

  /// С какого мирового дня руководит. null — неизвестно.
  final int? ceoSinceDay;
}

/// Кредитное качество выпуска облигаций.
enum BondQuality { gov, a, bbb, bb }

/// Выпуск облигации.
class BondLore {
  const BondLore({
    required this.symbol,
    required this.name,
    required this.issuerSymbol,
    required this.quality,
    required this.couponPerCycle,
    required this.couponEveryDays,
  });

  final String symbol;
  final String name;

  /// null — государство Алории.
  final String? issuerSymbol;
  final BondQuality quality;

  /// Купонная ставка за цикл (=«год»), доля: 0.12 = 12%.
  final double couponPerCycle;
  final int couponEveryDays;
}

/// Фонд.
class FundLore {
  const FundLore({
    required this.symbol,
    required this.name,
    required this.description,
  });

  final String symbol;
  final String name;
  final String description;
}

const aloriaSectors = <SectorLore>[
  SectorLore(
    slug: 'finance',
    title: 'Финансы',
    icon: Icons.account_balance_rounded,
    description: 'Банки и страховщики. Рост ставки им чаще на руку.',
  ),
  SectorLore(
    slug: 'consumer',
    title: 'Потребительский',
    icon: Icons.shopping_basket_rounded,
    description: 'Товары на каждый день — спрос устойчивее, чем у других.',
  ),
  SectorLore(
    slug: 'retail',
    title: 'Ритейл',
    icon: Icons.storefront_rounded,
    description: 'Магазины и торговля. Живут настроением покупателей.',
  ),
  SectorLore(
    slug: 'food',
    title: 'Общепит и еда',
    icon: Icons.restaurant_rounded,
    description: 'Кафе и пекарни. Едят даже в рецессию — сектор-тихоня.',
  ),
  SectorLore(
    slug: 'logistics',
    title: 'Логистика',
    icon: Icons.local_shipping_rounded,
    description: 'Доставка и порты. Барометр деловой активности страны.',
  ),
  SectorLore(
    slug: 'tech',
    title: 'Технологии',
    icon: Icons.memory_rounded,
    description: 'IT и игры. Быстро растут, но больнее всех падают.',
  ),
  SectorLore(
    slug: 'travel',
    title: 'Туризм',
    icon: Icons.flight_takeoff_rounded,
    description: 'Отдых и путешествия — первое, на чём экономят в кризис.',
  ),
  SectorLore(
    slug: 'energy',
    title: 'Энергетика',
    icon: Icons.bolt_rounded,
    description: 'Сети и топливо. Инфляция для них часто плюс, не минус.',
  ),
  SectorLore(
    slug: 'realty',
    title: 'Недвижимость',
    icon: Icons.home_work_rounded,
    description:
        'Застройщики и жильё. Главный заложник ключевой ставки: ипотека '
        'дешевеет — сектор летит, дорожает — замирает.',
  ),
];

const aloriaBonds = <BondLore>[
  BondLore(
    symbol: 'GOVB1',
    name: 'Гособлигация Алории 1',
    issuerSymbol: null,
    quality: BondQuality.gov,
    couponPerCycle: 0.070,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'GOVB2',
    name: 'Гособлигация Алории 2',
    issuerSymbol: null,
    quality: BondQuality.gov,
    couponPerCycle: 0.075,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'ALBB1',
    name: 'Банк Алория Б1',
    issuerSymbol: 'ALBK',
    quality: BondQuality.a,
    couponPerCycle: 0.095,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'MOVB1',
    name: 'ЕдемБыстро Б1',
    issuerSymbol: 'MOVE',
    quality: BondQuality.bbb,
    couponPerCycle: 0.120,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'FULB1',
    name: 'ТопливоПром Б1',
    issuerSymbol: 'FUEL',
    quality: BondQuality.bbb,
    couponPerCycle: 0.115,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'TRVB1',
    name: 'Свободный Путь Б1',
    issuerSymbol: 'TRVL',
    quality: BondQuality.bb,
    couponPerCycle: 0.160,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'ALZB1',
    name: 'АлоЗон Б1',
    issuerSymbol: 'ALZN',
    quality: BondQuality.bb,
    couponPerCycle: 0.150,
    couponEveryDays: 2,
  ),
  BondLore(
    symbol: 'BLDB1',
    name: 'СтройГранд Б1',
    issuerSymbol: 'BLDR',
    quality: BondQuality.bbb,
    couponPerCycle: 0.130,
    couponEveryDays: 2,
  ),
];

const aloriaFunds = <FundLore>[
  FundLore(
    symbol: 'ALIN',
    name: 'Индекс Алории',
    description:
        'Пай на все акции страны разом, крупные компании весят больше. '
        'Один инструмент — вся экономика Алории.',
  ),
  FundLore(
    symbol: 'ALBF',
    name: 'Облигации Алории',
    description:
        'Корзина государственных и корпоративных облигаций. Спокойнее '
        'акций, живёт на купонах.',
  ),
];

/// Метаданные кредитного качества: подпись, цвет и человеческое пояснение.
({String label, Color color, String hint}) bondQualityMeta(BondQuality q) =>
    switch (q) {
      BondQuality.gov => (
        label: 'Государственная',
        color: AppColors.primary,
        hint: 'Платит государство Алории — самый надёжный заёмщик страны.',
      ),
      BondQuality.a => (
        label: 'Качество A',
        color: AppColors.success,
        hint: 'Крепкий заёмщик, купон чуть выше государственного.',
      ),
      BondQuality.bbb => (
        label: 'Качество BBB',
        color: AppColors.warning,
        hint: 'Средняя надёжность: купон выше, но и риск заметнее.',
      ),
      BondQuality.bb => (
        label: 'Качество BB',
        color: AppColors.error,
        hint: 'Рискованный выпуск: высокий купон — плата за шанс дефолта.',
      ),
    };

/// Метаданные стадии компании: подпись, цвет и человеческое пояснение.
({String label, Color color, String hint}) companyStageMeta(CompanyStage s) =>
    switch (s) {
      CompanyStage.growth => (
        label: 'Растущая',
        color: AppColors.secondary,
        hint: 'Вкладывает всё в рост, дивиденды редки, движется размашисто.',
      ),
      CompanyStage.mature => (
        label: 'Зрелая',
        color: AppColors.primary,
        hint: 'Устоявшийся бизнес, платит дивиденды.',
      ),
      CompanyStage.defensive => (
        label: 'Защитная',
        color: AppColors.success,
        hint: 'Спрос стабилен в любую фазу цикла.',
      ),
    };

/// «growth» / «mature» / «defensive» без учёта регистра.
/// Неизвестное или отсутствующее значение — null, решает вызывающий.
CompanyStage? companyStageFrom(Object? value) =>
    switch (value is String ? value.toLowerCase() : '') {
      'growth' => CompanyStage.growth,
      'mature' => CompanyStage.mature,
      'defensive' => CompanyStage.defensive,
      _ => null,
    };

SectorLore aloriaSectorOf(String slug) => aloriaSectors.firstWhere(
  (s) => s.slug == slug,
  orElse: () => aloriaSectors.first,
);

List<BondLore> aloriaBondsOfIssuer(String? issuerSymbol) =>
    aloriaBonds.where((b) => b.issuerSymbol == issuerSymbol).toList();
