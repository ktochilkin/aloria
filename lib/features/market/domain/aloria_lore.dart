import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Справочник мира Алории: сектора, компании, облигации, фонды.
/// Зеркалит вселенную ИИ-режиссёра (Universe.cs). Пока статический мок —
/// позже переедет на aloria-api, когда появится эндпоинт справочника.

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

/// Компания-эмитент с лором и чертами характера.
class CompanyLore {
  const CompanyLore({
    required this.symbol,
    required this.name,
    required this.sectorSlug,
    required this.theme,
    required this.story,
    required this.payout,
    required this.leverage,
    required this.sigma,
  });

  final String symbol;
  final String name;
  final String sectorSlug;

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
];

const aloriaCompanies = <CompanyLore>[
  CompanyLore(
    symbol: 'ALBK',
    name: 'Банк Алория',
    sectorSlug: 'finance',
    theme: 'системный банк',
    story:
        'Старейший банк страны: через него проходит половина платежей Алории. '
        'Кредитует всех — от пекарен до порта, поэтому его отчёт читают как '
        'сводку здоровья всей экономики.',
    payout: 0.50,
    leverage: 0.55,
    sigma: 0.011,
  ),
  CompanyLore(
    symbol: 'INSA',
    name: 'Страж Полис',
    sectorSlug: 'finance',
    theme: 'страхование',
    story:
        'Страхует дома, грузы и урожай. Зарабатывает на спокойных временах: '
        'пока ничего не горит и не тонет, премии капают, а выплат мало.',
    payout: 0.40,
    leverage: 0.30,
    sigma: 0.012,
  ),
  CompanyLore(
    symbol: 'ICEC',
    name: 'Холодок и Ко',
    sectorSlug: 'consumer',
    theme: 'производитель мороженого',
    story:
        'Легенда алорийского лета. Полстраны выросло на пломбире «Холодок», '
        'и каждую жару компания бьёт рекорды продаж — а в холодный сезон '
        'спасается тортами-мороженое.',
    payout: 0.45,
    leverage: 0.25,
    sigma: 0.012,
  ),
  CompanyLore(
    symbol: 'DRNK',
    name: 'ЖивВода',
    sectorSlug: 'consumer',
    theme: 'напитки и вода',
    story:
        'Разливает воду из северных источников Алории и делает лимонады по '
        'старым рецептам. Скучный стабильный бизнес — пить хотят всегда.',
    payout: 0.50,
    leverage: 0.20,
    sigma: 0.009,
  ),
  CompanyLore(
    symbol: 'HOME',
    name: 'ДомоТехника',
    sectorSlug: 'consumer',
    theme: 'бытовая техника',
    story:
        'Собирает холодильники и стиральные машины «для алорийской семьи». '
        'Покупки крупные и нечастые: когда у людей туго с деньгами, новую '
        'плиту откладывают на потом.',
    payout: 0.30,
    leverage: 0.45,
    sigma: 0.013,
  ),
  CompanyLore(
    symbol: 'SHOP',
    name: 'РядомМаркет',
    sectorSlug: 'retail',
    theme: 'магазины у дома',
    story:
        'Сеть «магазинов за углом» в каждом районе. Держится на обороте: '
        'маржа копеечная, зато покупатель заходит каждый день.',
    payout: 0.35,
    leverage: 0.50,
    sigma: 0.012,
  ),
  CompanyLore(
    symbol: 'WEAR',
    name: 'НосиСмело',
    sectorSlug: 'retail',
    theme: 'одежда и обувь',
    story:
        'Модный бренд для молодёжи: яркие коллекции, шумные распродажи. '
        'Продажи скачут вместе с модой — угадали сезон или нет.',
    payout: 0.25,
    leverage: 0.40,
    sigma: 0.016,
  ),
  CompanyLore(
    symbol: 'FAST',
    name: 'ШустроЕд',
    sectorSlug: 'food',
    theme: 'сеть быстрого питания',
    story:
        'Бургерные на каждой площади страны. Фирменный соус «Шустрый» — '
        'государственная тайна похлеще резервов центробанка.',
    payout: 0.40,
    leverage: 0.35,
    sigma: 0.011,
  ),
  CompanyLore(
    symbol: 'BRED',
    name: 'Тёплый Хлеб',
    sectorSlug: 'food',
    theme: 'кафе и пекарни',
    story:
        'Семейные пекарни с круассанами, за которыми стоят очереди с утра. '
        'Маленькая, уютная и на удивление живучая в любой кризис.',
    payout: 0.45,
    leverage: 0.20,
    sigma: 0.010,
  ),
  CompanyLore(
    symbol: 'MOVE',
    name: 'ЕдемБыстро',
    sectorSlug: 'logistics',
    theme: 'доставка и логистика',
    story:
        'Курьеры в зелёных куртках и фуры на всех трассах Алории. Растёт '
        'агрессивно и в долг — ставка по кредитам для неё больной вопрос.',
    payout: 0.20,
    leverage: 0.60,
    sigma: 0.015,
  ),
  CompanyLore(
    symbol: 'PORT',
    name: 'Порт Алория',
    sectorSlug: 'logistics',
    theme: 'морской порт и грузовой хаб',
    story:
        'Морские ворота страны: почти весь импорт и экспорт проходит через '
        'его краны. Полугосударственный гигант со стабильными тарифами.',
    payout: 0.55,
    leverage: 0.45,
    sigma: 0.012,
  ),
  CompanyLore(
    symbol: 'DIGI',
    name: 'ЦифраЛаб',
    sectorSlug: 'tech',
    theme: 'онлайн-сервисы и IT',
    story:
        'Главная IT-компания Алории: почта, карты, облака и такси в одном '
        'приложении. Прибыль почти не раздаёт — всё уходит в новые сервисы.',
    payout: 0.05,
    leverage: 0.15,
    sigma: 0.021,
  ),
  CompanyLore(
    symbol: 'GAME',
    name: 'ИгроСфера',
    sectorSlug: 'tech',
    theme: 'игры и развлечения',
    story:
        'Студия, чей хит «Драконы Алории» играла вся страна. Живёт от релиза '
        'до релиза: удачная игра — праздник, провал — долгая зима.',
    payout: 0.00,
    leverage: 0.10,
    sigma: 0.026,
  ),
  CompanyLore(
    symbol: 'TRVL',
    name: 'Свободный Путь',
    sectorSlug: 'travel',
    theme: 'туризм и отдых',
    story:
        'Туроператор и сеть отелей на южном побережье. Набрала кредитов на '
        'новые курорты — в хорошие годы летает, в плохие считает каждую '
        'монету.',
    payout: 0.30,
    leverage: 0.65,
    sigma: 0.020,
  ),
  CompanyLore(
    symbol: 'NRGA',
    name: 'АлорЭнерго',
    sectorSlug: 'energy',
    theme: 'электросети и генерация',
    story:
        'Держит все провода страны: свет в домах — её работа. Тарифы '
        'регулируются, поэтому сюрпризов мало, а дивиденды регулярные.',
    payout: 0.60,
    leverage: 0.50,
    sigma: 0.010,
  ),
  CompanyLore(
    symbol: 'FUEL',
    name: 'ТопливоПром',
    sectorSlug: 'energy',
    theme: 'добыча и переработка топлива',
    story:
        'Качает и перерабатывает топливо на севере Алории. Когда цены на '
        'сырьё растут, здесь праздник — даже если всей остальной экономике '
        'от этого больно.',
    payout: 0.45,
    leverage: 0.40,
    sigma: 0.018,
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

SectorLore aloriaSectorOf(String slug) => aloriaSectors.firstWhere(
  (s) => s.slug == slug,
  orElse: () => aloriaSectors.first,
);

CompanyLore? aloriaCompanyBySymbol(String symbol) {
  for (final c in aloriaCompanies) {
    if (c.symbol == symbol) return c;
  }
  return null;
}

List<BondLore> aloriaBondsOfIssuer(String? issuerSymbol) =>
    aloriaBonds.where((b) => b.issuerSymbol == issuerSymbol).toList();
