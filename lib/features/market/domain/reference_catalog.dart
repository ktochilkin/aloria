import 'package:aloria/features/market/domain/aloria_lore.dart';

/// Каталог справочника мира Алории: сектора, компании, облигации, фонды.
///
/// Источник — aloria-api (`GET /api/v1/market/reference`). При недоступном
/// бэке или пустом каталоге используется статический фолбэк из aloria_lore,
/// поэтому вкладка «Компании» работает всегда.
class ReferenceCatalog {
  const ReferenceCatalog({
    required this.sectors,
    required this.companies,
    required this.bonds,
    required this.funds,
  });

  /// Статический фолбэк — зеркалит вселенную режиссёра из aloria_lore.dart.
  const ReferenceCatalog.fallback()
    : sectors = aloriaSectors,
      companies = aloriaCompanies,
      bonds = aloriaBonds,
      funds = aloriaFunds;

  final List<SectorLore> sectors;
  final List<CompanyLore> companies;
  final List<BondLore> bonds;
  final List<FundLore> funds;

  /// Каталог считается пустым, если бэк не отдал ни одной компании.
  bool get isEmpty => companies.isEmpty;

  /// Компании сектора [slug] в исходном порядке каталога.
  List<CompanyLore> companiesOfSector(String slug) =>
      companies.where((c) => c.sectorSlug == slug).toList(growable: false);

  /// Облигации эмитента [issuerSymbol] (null — государство Алории).
  List<BondLore> bondsOfIssuer(String? issuerSymbol) => bonds
      .where((b) => b.issuerSymbol == issuerSymbol)
      .toList(growable: false);

  /// Компания по тикеру, null — если не нашлась.
  CompanyLore? companyBySymbol(String symbol) {
    for (final c in companies) {
      if (c.symbol == symbol) return c;
    }
    return null;
  }
}
