import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/domain/order_failure.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/positions/top_up_page.dart';
import 'package:aloria/features/support/presentation/support_report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Открывает умное объяснение, почему заявка не прошла (§6.3).
///
/// По категории [OrderFailure.kind] показывает конкретную причину
/// человеческим языком и контекстную помощь: при нехватке средств — свободные
/// деньги и позиции, при системном сбое — «проблему в мире Алории» и кнопку
/// обращения в поддержку.
Future<void> showOrderFailureSheet(
  BuildContext context, {
  required OrderFailure failure,
  required String symbol,
  Map<String, dynamic>? orderContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Ограничиваем высоту, чтобы шторка не растягивалась на весь экран:
    // длинный контент прокручивается внутри, шапка с крестиком всегда видна.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.7,
    ),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _OrderFailureSheet(
      failure: failure,
      symbol: symbol,
      orderContext: orderContext,
    ),
  );
}

class _OrderFailureSheet extends ConsumerWidget {
  const _OrderFailureSheet({
    required this.failure,
    required this.symbol,
    this.orderContext,
  });

  final OrderFailure failure;
  final String symbol;
  final Map<String, dynamic>? orderContext;

  String get _title => switch (failure.kind) {
        OrderFailureKind.insufficientFunds => 'Не хватает свободных денег',
        OrderFailureKind.badPrice => 'Биржа не приняла цену',
        OrderFailureKind.noPrice => 'Не нашлось цены для сделки',
        OrderFailureKind.badQuantity => 'Биржа не приняла количество',
        OrderFailureKind.tradingClosed => 'Торги сейчас не идут',
        OrderFailureKind.shortNotAllowed => 'Этих бумаг нет в портфеле',
        OrderFailureKind.forbidden => 'Это действие сейчас недоступно',
        OrderFailureKind.orderNotFound => 'Заявка уже не активна',
        OrderFailureKind.system => 'Что-то пошло не так в мире Алории',
        OrderFailureKind.unknown => 'Заявка не прошла',
      };

  String get _explanation => switch (failure.kind) {
        OrderFailureKind.insufficientFunds =>
          'На эту покупку не хватает покупательной способности. Это не '
              'поломка: система защищает от сделки, которую нечем оплатить.',
        OrderFailureKind.badPrice =>
          'Биржа принимает цены только внутри допустимого коридора вокруг '
              'текущей цены и только кратные шагу цены. Поставь цену ближе '
              'к рыночной — подсказка «сейчас …» в поле цены поможет.',
        OrderFailureKind.noPrice =>
          'У инструмента сейчас нет цены, по которой могла бы пройти '
              'рыночная заявка — в стакане пусто. Попробуй лимитную заявку '
              'со своей ценой или вернись позже.',
        OrderFailureKind.badQuantity =>
          'Количество в заявке некорректное: например, ноль или не целое '
              'число лотов. Попробуй указать целое количество.',
        OrderFailureKind.tradingClosed =>
          'Торговая сессия по инструменту закрыта или приостановлена. '
              'Заявку можно будет выставить, когда торги возобновятся.',
        OrderFailureKind.shortNotAllowed =>
          'Заявка на продажу больше, чем у тебя есть: продать можно только '
              'бумаги из портфеля. Продажа «в долг» (шорт) в Алории пока '
              'недоступна. Проверь количество и сколько бумаг доступно.',
        OrderFailureKind.forbidden =>
          'Система не разрешила это действие для твоего счёта или этого '
              'типа заявки.',
        OrderFailureKind.orderNotFound =>
          'Заявка, с которой ты работаешь, уже исполнилась или была снята '
              '— изменить или отменить её больше нельзя. Проверь вкладку '
              '«Заявки».',
        OrderFailureKind.system =>
          'Это не твоя ошибка — заявка была корректной, но что-то сломалось '
              'на нашей стороне. Попробуй ещё раз через минуту, а если '
              'повторится — отправь нам детали, мы разберёмся.',
        OrderFailureKind.unknown =>
          'Заявку не приняли. Чаще всего причина — нехватка покупательной '
              'способности, цена вне допустимых границ или закрытая сессия.',
      };

  IconData get _icon => switch (failure.kind) {
        OrderFailureKind.insufficientFunds => Icons.account_balance_wallet_outlined,
        OrderFailureKind.badPrice => Icons.price_change_outlined,
        OrderFailureKind.noPrice => Icons.search_off_outlined,
        OrderFailureKind.badQuantity => Icons.numbers,
        OrderFailureKind.tradingClosed => Icons.nightlight_outlined,
        OrderFailureKind.shortNotAllowed => Icons.block_outlined,
        OrderFailureKind.forbidden => Icons.lock_outline,
        OrderFailureKind.orderNotFound => Icons.search_off_outlined,
        OrderFailureKind.system => Icons.cloud_off_outlined,
        OrderFailureKind.unknown => Icons.info_outline,
      };

  bool get _isSystemLike =>
      failure.kind == OrderFailureKind.system ||
      failure.kind == OrderFailureKind.unknown;

  void _openSupport(BuildContext context) {
    Navigator.of(context).pop();
    showSupportReportSheet(
      context,
      subject: 'Не отправилась заявка по $symbol',
      errorCode: failure.code,
      errorMessage: failure.message,
      extraContext: orderContext,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent =
        failure.kind == OrderFailureKind.system ? AppColors.primary : scheme.error;
    final message = failure.message?.trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _explanation,
                      style: text.bodyMedium?.copyWith(height: 1.5),
                    ),
                    if (failure.kind == OrderFailureKind.insufficientFunds)
                      _FundsHelp(symbol: symbol),
                    if (failure.kind == OrderFailureKind.shortNotAllowed)
                      _OwnedQtyHelp(symbol: symbol),
                    if (message != null && message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Сообщение системы: $message',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (failure.kind == OrderFailureKind.insufficientFunds) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TopUpPage(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('Расширить доступ за знания'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/learn/trading-basics/buying_power');
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Урок «Покупательная способность»'),
                ),
              ),
            ] else if (_isSystemLike) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openSupport(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Отправить детали в поддержку'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Попробую ещё раз'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Понятно'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Контекстная помощь при «продаже в минус»: сколько этой бумаги
/// на самом деле есть в портфеле.
class _OwnedQtyHelp extends ConsumerWidget {
  const _OwnedQtyHelp({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final positions = ref.watch(positionsProvider).valueOrNull;
    if (positions == null) return const SizedBox.shrink();

    final matches = positions
        .where((p) => p.symbol.toUpperCase() == symbol.toUpperCase())
        .toList();
    final qty = matches.isEmpty
        ? 0.0
        : (matches.first.qtyUnits ?? matches.first.quantity);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$symbol в портфеле',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            qty > 0 ? '${qty.toStringAsFixed(0)} шт.' : 'нет',
            style: monoNum(size: 15, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Контекстная помощь при нехватке средств: сколько свободно сейчас и
/// какие позиции можно продать, чтобы освободить деньги.
class _FundsHelp extends ConsumerWidget {
  const _FundsHelp({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(portfolioSummaryProvider).valueOrNull;
    final positions = (ref.watch(positionsProvider).valueOrNull ?? const [])
        .where((p) => p.symbol.toUpperCase() != 'RUB' && p.currentVolume > 0)
        .toList()
      ..sort((a, b) => b.currentVolume.compareTo(a.currentVolume));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Свободно сейчас',
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${summary.buyingPower.toStringAsFixed(2)} ₽',
                  style: monoNum(size: 15, color: scheme.onSurface),
                ),
              ],
            ),
          if (positions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Деньги можно освободить, продав часть бумаг:',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            for (final p in positions.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.symbol, style: text.bodySmall),
                    Text(
                      '≈ ${p.currentVolume.toStringAsFixed(0)} ₽',
                      style: monoNum(
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            'А ещё покупательная способность растёт за пройденные уроки '
            'и тесты — знания здесь и есть деньги.',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
