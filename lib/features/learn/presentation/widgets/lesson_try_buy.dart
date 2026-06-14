import 'package:aloria/features/learn/presentation/widgets/blocks/block_kit.dart';
import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/order_failure.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/trade/widgets/order_failure_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Блок «попробуй прямо сейчас» для первого урока: НАСТОЯЩАЯ рыночная покупка
/// одного лота реального инструмента учебной биржи. Главное обещание урока —
/// «тут можно ошибаться, деньги учебные» — превращается в действие.
class LessonTryBuy extends ConsumerStatefulWidget {
  const LessonTryBuy({super.key, required this.tint});

  final Color tint;

  @override
  ConsumerState<LessonTryBuy> createState() => _LessonTryBuyState();
}

class _LessonTryBuyState extends ConsumerState<LessonTryBuy> {
  bool _buying = false;

  /// Символ купленного инструмента после успешной сделки (null — ещё не куплен).
  String? _bought;

  Future<void> _buy(MarketSecurity sec) async {
    setState(() => _buying = true);
    try {
      final repo = await ref.read(marketDataRepositoryProvider.future);
      await repo.placeOrder(
        TradeOrder(
          symbol: sec.symbol,
          exchange: sec.exchange,
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: 1,
        ),
      );
      if (mounted) {
        setState(() {
          _bought = sec.symbol;
          _buying = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _buying = false);
      // Те же умные объяснения, что и на торговом экране (нехватка средств,
      // сессия закрыта и т.п.) — без сырых ошибок.
      showOrderFailureSheet(
        context,
        failure: OrderFailure.fromException(e),
        symbol: sec.symbol,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final securities = ref.watch(marketSecuritiesProvider);

    return LessonBlockCard(
      tint: widget.tint,
      title: 'Попробуй прямо сейчас',
      subtitle: 'Это настоящая сделка на учебной бирже. '
          'Деньги учебные — терять нечего.',
      child: securities.when(
        data: (list) {
          if (_bought != null) return _doneView(context);
          if (list.isEmpty) {
            return _fallback(
              context,
              'Инструменты ещё не загрузились — попробуй чуть позже '
              'или загляни в раздел «Рынок».',
            );
          }
          return _buyView(context, list.first);
        },
        loading: () => const SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => _fallback(
          context,
          'Не получилось загрузить инструменты. Открой раздел «Рынок» '
          'и купи что угодно вручную — это безопасно.',
        ),
      ),
    );
  }

  Widget _buyView(BuildContext context, MarketSecurity sec) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final priceLabel = sec.lastPrice != null
        ? '${sec.lastPrice!.toStringAsFixed(2)} ₽'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sec.symbol,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (sec.shortName.isNotEmpty && sec.shortName != sec.symbol)
                    Text(
                      sec.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (priceLabel != null)
              BlockChip(text: priceLabel, tint: widget.tint, tone: BlockTone.neutral),
          ],
        ),
        const SizedBox(height: BlockSpacing.m),
        BlockButton(
          tint: widget.tint,
          label: _buying ? 'Покупаю…' : 'Купить ${sec.symbol}',
          icon: Icons.shopping_cart_checkout,
          onPressed: _buying ? null : () => _buy(sec),
        ),
        const SizedBox(height: BlockSpacing.s),
        Text(
          'Один лот по рыночной цене. Нажми — и загляни в Портфель.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _doneView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: BlockChartColors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Готово! Ты купил $_bought',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: BlockSpacing.s),
        Text(
          'Видишь — ничего не сломалось. Это была настоящая сделка, '
          'просто на учебные деньги. Дальше будем разбираться, что именно '
          'произошло на счёте.',
          style: text.bodySmall?.copyWith(
            color: scheme.onSurface,
            height: 1.45,
          ),
        ),
        const SizedBox(height: BlockSpacing.m),
        BlockButton(
          tint: widget.tint,
          label: 'Открыть портфель',
          icon: Icons.account_balance_wallet_outlined,
          onPressed: () => context.go('/positions'),
        ),
      ],
    );
  }

  Widget _fallback(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Text(
      message,
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
    );
  }
}
