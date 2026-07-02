import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/presentation/widgets/news_instrument_card.dart';
import 'package:aloria/features/market/presentation/widgets/news_meta.dart';
import 'package:flutter/material.dart';

/// Полная новость: шторка с тональной шапкой (цвет = sentiment), крупным
/// заголовком, карточкой инструмента и просторным текстом.
void showNewsDetailModal(BuildContext context, MarketNews news) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NewsDetailSheet(news: news),
  );
}

class _NewsDetailSheet extends StatelessWidget {
  const _NewsDetailSheet({required this.news});

  final MarketNews news;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tone = newsSentimentColor(news.sentiment);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Stack(
          children: [
            ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // Тональная шапка
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tone.withValues(alpha: 0.18),
                        tone.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      NewsMetaRow(news: news),
                      const SizedBox(height: 10),
                      Text(
                        news.title,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatNewsDate(news.publishedAt),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Карточка инструмента с котировками
                if (news.symbols.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: NewsInstrumentCard(symbol: news.symbols.first),
                  ),
                // Текст
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                  child: Text(
                    news.content,
                    style: text.bodyLarge?.copyWith(
                      height: 1.6,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
            // Крестик поверх шапки
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: scheme.surface.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Форматирование даты новости («только что», «N мин назад», …).
String formatNewsDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date.toLocal());

  if (difference.inMinutes < 1) return 'только что';
  if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
  if (difference.inHours < 24) return '${difference.inHours} ч назад';
  if (difference.inDays < 7) return '${difference.inDays} дн назад';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
}
