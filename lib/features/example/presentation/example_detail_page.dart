import 'package:aloria/features/example/application/example_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExampleDetailPage extends ConsumerWidget {
  final String id;
  const ExampleDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItem = ref.watch(exampleDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text('Example $id')),
      body: asyncItem.when(
        data: (item) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(item.description ?? 'No description'),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
