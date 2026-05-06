import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/profile/domain/profile_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final progressProvider = FutureProvider<UserProgress>((ref) async {
  final client = ref.watch(learningApiClientProvider);
  final portfolioId = ref.watch(aloriaPortfolioIdProvider);
  return UserProgress.fromJson(await client.fetchProgress(portfolioId));
});

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final client = ref.watch(learningApiClientProvider);
  final portfolioId = ref.watch(aloriaPortfolioIdProvider);
  final raw = await client.fetchAchievements(portfolioId);
  return raw.map(Achievement.fromJson).toList();
});
