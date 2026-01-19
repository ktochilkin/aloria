import 'package:aloria/features/example/application/example_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExampleListPage extends ConsumerWidget {
  const ExampleListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(exampleListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Examples')),
      body: asyncItems.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(items[i].title),
            subtitle: Text(items[i].description ?? ''),
            onTap: () => context.go('/examples/${items[i].id}'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
