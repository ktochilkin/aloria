import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:flutter/material.dart';

/// Цвет тональности новости: биржевые зелёный/красный, нейтраль — мьютед.
Color newsSentimentColor(NewsSentiment s) => switch (s) {
  NewsSentiment.positive => TradeColors.up,
  NewsSentiment.negative => TradeColors.down,
  NewsSentiment.neutral => TradeColors.muted,
};

/// Человекочитаемый тип события.
String newsEventTypeLabel(String type) => switch (type) {
  'earnings' => 'Отчётность',
  'dividend' => 'Дивиденды',
  'guidance' => 'Прогноз',
  'operations' => 'Операции',
  'product' => 'Продукт',
  'macro' => 'Макро',
  'sector' => 'Сектор',
  _ => 'Новость',
};

const _sectorTitles = {
  'finance': 'Финансы',
  'consumer': 'Потребительский',
  'retail': 'Ритейл',
  'food': 'Общепит',
  'logistics': 'Логистика',
  'tech': 'Технологии',
  'travel': 'Туризм',
};

/// Подпись охвата: тикер(ы), сектор или «Экономика» для макро-новости.
String newsScopeLabel(MarketNews n) {
  if (n.scope == 'macro') return 'Экономика';
  if (n.symbols.isNotEmpty) return n.symbols.join(', ');
  if (n.sector != null) return _sectorTitles[n.sector] ?? n.sector!;
  return '';
}

/// Строка-бейдж над заголовком: цветная точка тональности + тип события + охват.
class NewsMetaRow extends StatelessWidget {
  const NewsMetaRow({super.key, required this.news});

  final MarketNews news;

  @override
  Widget build(BuildContext context) {
    final color = newsSentimentColor(news.sentiment);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final scope = newsScopeLabel(news);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          newsEventTypeLabel(news.eventType),
          style: text.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        if (scope.isNotEmpty) ...[
          Text(
            '  ·  ',
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Flexible(
            child: Text(
              scope,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
