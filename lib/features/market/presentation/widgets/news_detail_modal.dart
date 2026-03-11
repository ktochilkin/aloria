import 'dart:ui';

import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/presentation/widgets/news_instrument_card.dart';
import 'package:flutter/material.dart';

/// Показать полную новость в модальном окне
void showNewsDetailModal(BuildContext context, MarketNews news) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Stack(
        children: [
          DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.8,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Индикатор перетаскивания и кнопка закрытия
                    SizedBox(
                      height: 40,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Закрыть',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Контент
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          // Заголовок
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                            child: Text(
                              news.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          // Метаданные новости
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(news.publishedAt),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Карточка инструмента с котировками
                          if (news.symbols.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: NewsInstrumentCard(
                                symbol: news.symbols.first,
                              ),
                            ),
                          // Основной текст
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  news.content,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        height: 1.6,
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Нижний отступ
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Форматирование даты новости
String formatNewsDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} мин назад';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} ч назад';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} дн назад';
  } else {
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

String _formatDate(DateTime date) => formatNewsDate(date);
