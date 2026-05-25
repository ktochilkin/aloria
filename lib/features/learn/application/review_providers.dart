import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Карточка recall, которую пора повторить (из `/me/reviews/due`).
class DueReview {
  const DueReview({
    required this.lessonId,
    required this.sectionSlug,
    required this.lessonSlug,
    required this.title,
    required this.recallPrompt,
    this.recallAnswer,
  });

  final String lessonId;
  final String sectionSlug;
  final String lessonSlug;
  final String title;
  final String recallPrompt;
  final String? recallAnswer;

  factory DueReview.fromJson(Map<String, dynamic> json) => DueReview(
        lessonId: json['lessonId'] as String? ?? '',
        sectionSlug: json['sectionSlug'] as String? ?? '',
        lessonSlug: json['lessonSlug'] as String? ?? '',
        title: json['title'] as String? ?? '',
        recallPrompt: json['recallPrompt'] as String? ?? '',
        recallAnswer: json['recallAnswer'] as String?,
      );
}

/// Список карточек recall, готовых к повторению прямо сейчас.
final dueReviewsProvider = FutureProvider<List<DueReview>>((ref) async {
  final client = ref.watch(learningApiClientProvider);
  final portfolioId = ref.watch(aloriaPortfolioIdProvider);
  final raw = await client.fetchDueReviews(portfolioId);
  return raw.map(DueReview.fromJson).toList();
});
