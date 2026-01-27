import 'package:aloria/core/errors/error_types.dart';
import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketNewsRepository {
  MarketNewsRepository(this._dio);

  final Dio _dio;

  static const _newsQuery = r'''
query ($order: [NewsSortInput!], $first: Int, $where: NewsFilterInput) {
  news(order: $order, first: $first, where: $where) {
    nodes {
      id
      headline
      content
      publishDate
      symbols
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
      __typename
    }
    __typename
  }
}
''';

  Future<List<MarketNews>> fetchNews({
    String? symbol,
    List<String>? symbols,
    int limit = 50,
  }) async {
    final symbolsFilter = symbols ?? (symbol != null ? [symbol] : null);

    final variables = <String, dynamic>{
      'order': [
        {'publishDate': 'DESC', 'id': 'DESC'},
      ],
      'first': limit,
      'where': symbolsFilter == null
          ? null
          : {
              'and': [
                {
                  'symbols': {'in': symbolsFilter},
                },
              ],
            },
    };

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/news/graphql',
        data: {'variables': variables, 'query': _newsQuery},
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = res.data ?? const <String, dynamic>{};
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        final message = first is Map<String, dynamic>
            ? first['message'] as String?
            : first?.toString();
        throw AppError.server(message ?? 'news_graphql_error');
      }
      final newsData = (data['data'] as Map?)?['news'] as Map?;
      final nodes = newsData?['nodes'] as List?;
      if (nodes == null) return const [];
      return nodes
          .whereType<Map<String, dynamic>>()
          .map(MarketNews.fromJson)
          .toList();
    } on DioException catch (e) {
      throw e.toTypedError();
    }
  }
}

final marketNewsRepositoryProvider = Provider<MarketNewsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MarketNewsRepository(dio);
});
