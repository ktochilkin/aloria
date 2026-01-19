import 'package:aloria/features/example/data/example_repository.dart';
import 'package:aloria/features/example/data/models/example_item.dart';

class GetExampleDetailUseCase {
  final ExampleRepository repo;
  GetExampleDetailUseCase(this.repo);

  Future<ExampleItem> call(String id) => repo.fetchDetail(id);
}
