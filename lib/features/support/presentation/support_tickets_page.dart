import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:aloria/features/support/data/support_repository.dart';
import 'package:aloria/features/support/domain/support_ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Экран «Мои обращения»: статусы вопросов в поддержку и ответы.
/// Без чата — ответ приходит на почту, здесь видны статус и текст ответа.
class SupportTicketsPage extends ConsumerWidget {
  const SupportTicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Мои обращения')),
      body: tickets.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: StatePlaceholder(
                icon: Icons.support_agent,
                title: 'Обращений пока нет',
                message:
                    'Если в мире Алории что-то пойдёт не так, отсюда можно '
                    'будет следить за статусом своего вопроса.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(supportTicketsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, i) => _TicketCard(ticket: list[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: StatePlaceholder(
            icon: Icons.cloud_off_outlined,
            title: 'Не получилось загрузить обращения',
            message: 'Проверь соединение и попробуй ещё раз.',
            actionLabel: 'Обновить',
            onAction: () => ref.invalidate(supportTicketsProvider),
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  String _date(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final answered = ticket.isAnswered;
    final statusColor = answered ? AppColors.success : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  answered ? 'Есть ответ' : 'Разбираемся',
                  style: text.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _date(ticket.createdAt),
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (answered && ticket.answer != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ticket.answer!,
                style: text.bodySmall?.copyWith(height: 1.45),
              ),
            ),
          ] else
            Text(
              'Мы изучаем детали. Ответ придёт на почту.',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
