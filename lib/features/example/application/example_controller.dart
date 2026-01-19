import 'package:aloria/features/example/data/example_repository.dart';
import 'package:aloria/features/example/data/models/example_item.dart';
import 'package:aloria/features/example/domain/get_example_detail_use_case.dart';
import 'package:aloria/features/example/domain/get_example_list_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exampleListProvider = FutureProvider<List<ExampleItem>>((ref) {
  final repo = ref.read(exampleRepositoryProvider);
  return GetExampleListUseCase(repo).call();
});

final exampleDetailProvider = FutureProvider.family<ExampleItem, String>((
  ref,
  id,
) {
  final repo = ref.read(exampleRepositoryProvider);
  return GetExampleDetailUseCase(repo).call(id);
});
