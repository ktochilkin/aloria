/// Тональность новости.
enum NewsSentiment { positive, negative, neutral }

/// Новость экономического мира Aloria (из aloria-api `/api/v1/market/news`).
class MarketNews {
  final String id;
  final String title;
  final String content;
  final DateTime publishedAt;
  final List<String> symbols;

  /// Тональность — для цветового акцента в UI.
  final NewsSentiment sentiment;

  /// Тип события: earnings | dividend | guidance | operations | product | macro.
  final String eventType;

  /// Охват: macro | sector | company.
  final String scope;

  /// Slug основного затронутого сектора (null для макро-новостей).
  final String? sector;

  const MarketNews({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedAt,
    required this.symbols,
    this.sentiment = NewsSentiment.neutral,
    this.eventType = 'operations',
    this.scope = 'company',
    this.sector,
  });

  factory MarketNews.fromJson(Map<String, dynamic> json) {
    final symbolsRaw = json['symbols'];
    final symbols = switch (symbolsRaw) {
      final List<dynamic> list =>
        list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      final String str =>
        str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      _ => <String>[],
    };

    final publishedAt = json['publishDate'] as String? ?? '';

    return MarketNews(
      id: json['id']?.toString() ?? '',
      title: json['headline'] as String? ?? '',
      content: json['content'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(publishedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      symbols: symbols,
      sentiment: _sentimentFromString(json['sentiment'] as String?),
      eventType: json['eventType'] as String? ?? 'operations',
      scope: json['scope'] as String? ?? 'company',
      sector: json['sector'] as String?,
    );
  }

  static NewsSentiment _sentimentFromString(String? raw) => switch (raw) {
    'positive' => NewsSentiment.positive,
    'negative' => NewsSentiment.negative,
    _ => NewsSentiment.neutral,
  };
}
