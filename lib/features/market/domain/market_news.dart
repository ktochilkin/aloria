class MarketNews {
  final int id;
  final String title;
  final String content;
  final DateTime publishedAt;
  final List<String> symbols;

  const MarketNews({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedAt,
    required this.symbols,
  });

  factory MarketNews.fromJson(Map<String, dynamic> json) {
    final symbolsRaw = json['symbols'];
    final symbols = switch (symbolsRaw) {
      List list =>
        list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      String str =>
        str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      _ => <String>[],
    };

    final publishedAt = json['publishDate'] as String? ?? '';

    return MarketNews(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['headline'] as String? ?? '',
      content: json['content'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(publishedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      symbols: symbols,
    );
  }
}
