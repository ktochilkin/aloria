import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/market/domain/aloria_lore.dart';
import 'package:aloria/features/market/domain/reference_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Репозиторий справочника мира Алории (aloria-api).
///
/// `GET /api/v1/market/reference` отдаёт каталог целиком: сектора, компании,
/// облигации и фонды. Деривативы в контракте есть, но пока не торгуются —
/// поле парсинг не ломает и в отображении не участвует.
class MarketReferenceRepository {
  MarketReferenceRepository({
    required String baseUrl,
    required bool enableLogging,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 6),
           receiveTimeout: const Duration(seconds: 12),
           sendTimeout: const Duration(seconds: 6),
           headers: const {'Accept': 'application/json'},
         ),
       ) {
    if (enableLogging) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onError: (e, h) {
            appLogger.w('reference ✖ ${e.requestOptions.uri}: ${e.message}');
            h.next(e);
          },
        ),
      );
    }
  }

  final Dio _dio;

  /// Полный каталог справочника.
  Future<ReferenceCatalog> fetchReference() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/market/reference',
      );
      return _parseCatalog(res.data ?? const {});
    } on DioException catch (e) {
      throw e.toTypedError();
    }
  }
}

ReferenceCatalog _parseCatalog(Map<String, dynamic> json) => ReferenceCatalog(
  sectors: _items(json['sectors']).map(_parseSector).toList(growable: false),
  companies: _items(
    json['companies'],
  ).map(_parseCompany).toList(growable: false),
  bonds: _items(json['bonds']).map(_parseBond).toList(growable: false),
  funds: _items(json['funds']).map(_parseFund).toList(growable: false),
);

Iterable<Map<String, dynamic>> _items(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>() : const [];

SectorLore _parseSector(Map<String, dynamic> json) {
  final slug = json['slug'] as String? ?? '';
  return SectorLore(
    slug: slug,
    title: json['title'] as String? ?? slug,
    icon: _sectorIcon(slug),
    description: json['description'] as String? ?? '',
  );
}

/// Иконка сектора — клиентская: берём из статики по slug.
IconData _sectorIcon(String slug) {
  for (final s in aloriaSectors) {
    if (s.slug == slug) return s.icon;
  }
  return Icons.category_rounded;
}

CompanyLore _parseCompany(Map<String, dynamic> json) {
  final symbol = json['symbol'] as String? ?? '';
  return CompanyLore(
    symbol: symbol,
    name: json['name'] as String? ?? '',
    sectorSlug: json['sectorSlug'] as String? ?? '',
    stage: _parseStage(json['stage'], symbol),
    theme: json['theme'] as String? ?? '',
    story: json['story'] as String? ?? '',
    payout: _toDouble(json['payout']),
    leverage: _toDouble(json['leverage']),
    sigma: _toDouble(json['sigma']),
    ceoName: json['ceoName'] as String?,
    ceoSinceDay: (json['ceoSinceDay'] as num?)?.toInt(),
  );
}

/// Стадия без учёта регистра. Старый бэк поля не отдаёт — тогда берём
/// стадию из статического лора по тикеру, а для незнакомых бумаг — mature.
CompanyStage _parseStage(Object? value, String symbol) =>
    companyStageFrom(value) ??
    aloriaCompanyBySymbol(symbol)?.stage ??
    CompanyStage.mature;

BondLore _parseBond(Map<String, dynamic> json) => BondLore(
  symbol: json['symbol'] as String? ?? '',
  name: json['name'] as String? ?? '',
  issuerSymbol: json['issuerSymbol'] as String?,
  quality: _parseQuality(json['quality']),
  couponPerCycle: _toDouble(json['couponPerCycle']),
  couponEveryDays: (json['couponEveryDays'] as num?)?.toInt() ?? 0,
);

FundLore _parseFund(Map<String, dynamic> json) => FundLore(
  symbol: json['symbol'] as String? ?? '',
  name: json['name'] as String? ?? '',
  description: json['description'] as String? ?? '',
);

/// «Gov» / «A» / «Bbb» / «Bb» без учёта регистра; неизвестное качество — bbb.
BondQuality _parseQuality(Object? value) =>
    switch (value is String ? value.toLowerCase() : '') {
      'gov' => BondQuality.gov,
      'a' => BondQuality.a,
      'bb' => BondQuality.bb,
      _ => BondQuality.bbb,
    };

double _toDouble(Object? value) => value is num ? value.toDouble() : 0.0;

final marketReferenceRepositoryProvider = Provider<MarketReferenceRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  return MarketReferenceRepository(
    baseUrl: config.aloriaApiBaseUrl,
    enableLogging: config.enableLogging,
  );
});
