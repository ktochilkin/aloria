import 'package:aloria/features/example/data/example_repository.dart';
import 'package:aloria/features/example/data/models/example_item.dart';

class GetExampleListUseCase {
  final ExampleRepository repo;
  GetExampleListUseCase(this.repo);

  Future<List<ExampleItem>> call() => repo.fetchList();
}
