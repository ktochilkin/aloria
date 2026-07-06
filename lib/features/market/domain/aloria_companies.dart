import 'package:aloria/features/market/domain/aloria_lore.dart';

/// Компании-эмитенты мира Алории — статический фолбэк справочника.
///
/// Зеркалит вселенную ИИ-режиссёра (Universe.cs): лор-истории и параметры
/// дословно совпадают с бэком. Руководителей (ceoName / ceoSinceDay) в статике
/// нет — их назначает режиссёр, приложение узнаёт имена из reference-каталога.
const aloriaCompanies = <CompanyLore>[
  CompanyLore(
    symbol: 'ALBK',
    name: 'Банк Алория',
    sectorSlug: 'finance',
    stage: CompanyStage.mature,
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
    stage: CompanyStage.mature,
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
    stage: CompanyStage.defensive,
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
    stage: CompanyStage.mature,
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
    stage: CompanyStage.mature,
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
    symbol: 'APTK',
    name: 'Ромашка',
    sectorSlug: 'consumer',
    stage: CompanyStage.defensive,
    theme: 'сеть аптек',
    story:
        'Аптеки «Ромашка» в каждом квартале: лекарства, витамины и советы '
        'провизора тёти Май. Люди болеют и лечатся при любой экономике, '
        'поэтому выручка ровная, как кардиограмма здорового человека.',
    payout: 0.50,
    leverage: 0.25,
    sigma: 0.008,
  ),
  CompanyLore(
    symbol: 'SHOP',
    name: 'РядомМаркет',
    sectorSlug: 'retail',
    stage: CompanyStage.mature,
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
    stage: CompanyStage.growth,
    theme: 'одежда и обувь',
    story:
        'Модный бренд для молодёжи: яркие коллекции, шумные распродажи. '
        'Продажи скачут вместе с модой — угадали сезон или нет.',
    payout: 0.25,
    leverage: 0.40,
    sigma: 0.016,
  ),
  CompanyLore(
    symbol: 'ALZN',
    name: 'АлоЗон',
    sectorSlug: 'retail',
    stage: CompanyStage.growth,
    theme: 'маркетплейс «всё и сразу»',
    story:
        'Маркетплейс, где алорийцы заказывают всё — от носков до насосов. '
        'Растёт бешеными темпами и воюет за каждого курьера с «РядомМаркет»; '
        'прибыль пока тонкая: всё съедают склады и скидки.',
    payout: 0.05,
    leverage: 0.45,
    sigma: 0.019,
  ),
  CompanyLore(
    symbol: 'FAST',
    name: 'ШустроЕд',
    sectorSlug: 'food',
    stage: CompanyStage.mature,
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
    stage: CompanyStage.defensive,
    theme: 'кафе и пекарни',
    story:
        'Семейные пекарни с круассанами, за которыми стоят очереди с утра. '
        'Маленькая, уютная и на удивление живучая в любой кризис.',
    payout: 0.45,
    leverage: 0.20,
    sigma: 0.010,
  ),
  CompanyLore(
    symbol: 'GRNF',
    name: 'АгроДар',
    sectorSlug: 'food',
    stage: CompanyStage.mature,
    theme: 'агрохолдинг: поля и теплицы',
    story:
        'Поля, теплицы и элеваторы по всей южной Алории. Кормит полстраны и '
        'поставляет муку «Тёплому Хлебу». Урожай не отменить кризисом, но '
        'погода — акционер с правом вето.',
    payout: 0.45,
    leverage: 0.35,
    sigma: 0.011,
  ),
  CompanyLore(
    symbol: 'MOVE',
    name: 'ЕдемБыстро',
    sectorSlug: 'logistics',
    stage: CompanyStage.growth,
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
    stage: CompanyStage.mature,
    theme: 'морской порт и грузовой хаб',
    story:
        'Морские ворота страны: почти весь импорт и экспорт проходит через '
        'его краны. Полугосударственный гигант со стабильными тарифами.',
    payout: 0.55,
    leverage: 0.45,
    sigma: 0.012,
  ),
  CompanyLore(
    symbol: 'KICK',
    name: 'Вжух',
    sectorSlug: 'logistics',
    stage: CompanyStage.growth,
    theme: 'прокат самокатов и велосипедов',
    story:
        'Фиолетовые самокаты «Вжух» стоят на каждом углу столицы. Молодая и '
        'дерзкая: сезон хороший — города в восторге, сезон дождей — парк '
        'ржавеет на складах. С «ЕдемБыстро» грызутся за курьерские контракты.',
    payout: 0.00,
    leverage: 0.55,
    sigma: 0.024,
  ),
  CompanyLore(
    symbol: 'DIGI',
    name: 'ЦифраЛаб',
    sectorSlug: 'tech',
    stage: CompanyStage.growth,
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
    stage: CompanyStage.growth,
    theme: 'игры и развлечения',
    story:
        'Студия, чей хит «Драконы Алории» играла вся страна. Живёт от релиза '
        'до релиза: удачная игра — праздник, провал — долгая зима.',
    payout: 0.00,
    leverage: 0.10,
    sigma: 0.026,
  ),
  CompanyLore(
    symbol: 'TLKM',
    name: 'АлорСвязь',
    sectorSlug: 'tech',
    stage: CompanyStage.mature,
    theme: 'сотовая связь и интернет',
    story:
        'Связь и интернет всей Алории: вышки от столицы до северных посёлков. '
        'Скучная, как телефонный справочник, и такая же незаменимая — '
        'абонентская плата капает в любой кризис.',
    payout: 0.65,
    leverage: 0.50,
    sigma: 0.008,
  ),
  CompanyLore(
    symbol: 'TRVL',
    name: 'Свободный Путь',
    sectorSlug: 'travel',
    stage: CompanyStage.growth,
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
    stage: CompanyStage.mature,
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
    stage: CompanyStage.mature,
    theme: 'добыча и переработка топлива',
    story:
        'Качает и перерабатывает топливо на севере Алории. Когда цены на '
        'сырьё растут, здесь праздник — даже если всей остальной экономике '
        'от этого больно.',
    payout: 0.45,
    leverage: 0.40,
    sigma: 0.018,
  ),
  CompanyLore(
    symbol: 'BLDR',
    name: 'СтройГранд',
    sectorSlug: 'realty',
    stage: CompanyStage.growth,
    theme: 'застройщик жилья',
    story:
        'Строит кварталы-муравейники на окраинах столицы. Классический '
        'заложник ключевой ставки: дешёвая ипотека — краны крутятся, дорогая '
        '— котлованы стоят. Кредитов набрано на три квартала вперёд.',
    payout: 0.30,
    leverage: 0.70,
    sigma: 0.017,
  ),
];

/// Компания по тикеру, null — если не нашлась.
CompanyLore? aloriaCompanyBySymbol(String symbol) {
  for (final c in aloriaCompanies) {
    if (c.symbol == symbol) return c;
  }
  return null;
}
