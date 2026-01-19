import 'package:aloria/features/market/application/market_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MarketPage extends ConsumerWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSecurities = ref.watch(marketSecuritiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Обзор рынка')),
      body: asyncSecurities.when(
        data: (items) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              final label = item.symbol.length > 2
                  ? item.symbol.substring(0, 2)
                  : item.symbol;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.surface.withValues(alpha: 0.96),
                      scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  // Push to keep back-swipe/back button available on trade page.
                  onTap: () =>
                      context.push('/market/${item.symbol}', extra: item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.16,
                          ),
                          child: Text(
                            label,
                            style: text.labelMedium?.copyWith(
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.symbol, style: text.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                item.shortName,
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
