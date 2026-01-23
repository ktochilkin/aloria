// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:aloria/app_config.dart';
import 'package:aloria/core/env/env.dart';
import 'package:aloria/features/example/data/example_repository.dart';
import 'package:aloria/features/example/data/models/example_item.dart';
import 'package:aloria/features/example/presentation/example_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeExampleRepository implements ExampleRepository {
  @override
  Future<ExampleItem> fetchDetail(String id) async =>
      ExampleItem(id: id, title: 'Item $id', description: 'Detail');

  @override
  Future<List<ExampleItem>> fetchList() async => [
    const ExampleItem(id: '1', title: 'Item 1', description: 'Desc'),
  ];
}

void main() {
  testWidgets('renders example list', (tester) async {
    const config = AppConfig(
      env: AppEnv.dev,
      apiBaseUrl: 'https://example.com',
      wsBaseUrl: 'wss://example.com/ws',
      authBaseUrl: 'https://example.com',
      authApiBaseUrl: 'https://example.com',
      authRedirectUrl: '//example.com/auth/callback/',
      enableLogging: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          exampleRepositoryProvider.overrideWithValue(FakeExampleRepository()),
        ],
        child: const MaterialApp(home: ExampleListPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
  });
}
