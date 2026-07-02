import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/cycle_events.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/presentation/widgets/cycle_calendar_page.dart';
import 'package:flutter/material.dart';

/// Компактный блок «Ближайшие события» на обзоре: человеческие метки времени
/// («сегодня / завтра / через N дн»). По тапу — полный календарь цикла.
class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({
    super.key,
    required this.macro,
    required this.securities,
  });

  final MacroState macro;
  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final events = upcomingCycleEvents(macro, securities);
    if (events.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openCycleCalendar(context, macro, securities),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ближайшие события',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Календарь',
                    style: text.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.primary, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              for (final e in events) _EventRow(event: e, macro: macro),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.macro});

  final CycleEvent event;
  final MacroState macro;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = cycleEventTypeMeta(event.type);
    final dist = cycleDistance(macro, event.day);
    final isToday = dist == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, size: 17, color: meta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  event.type,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isToday
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              humanDayLabel(dist),
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isToday ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
