import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/example/data/models/example_item.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ExampleRepository {
  Future<List<ExampleItem>> fetchList();
  Future<ExampleItem> fetchDetail(String id);
}

class RemoteExampleRepository implements ExampleRepository {
  final Dio dio;
  RemoteExampleRepository(this.dio);

  @override
  Future<List<ExampleItem>> fetchList() async {
    // Stubbing examples to avoid hitting blocked demo endpoint in web.
    return const [];
  }

  @override
  Future<ExampleItem> fetchDetail(String id) async {
    return ExampleItem(id: id, title: 'Example $id', description: '');
  }
}

final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return RemoteExampleRepository(dio);
});
