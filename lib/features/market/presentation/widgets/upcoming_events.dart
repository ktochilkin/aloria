import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/cycle_events.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/presentation/widgets/cycle_calendar_page.dart';
import 'package:flutter/material.dart';

/// Компактный блок «Ближайшие события» на обзоре. По тапу проваливается в
/// полноэкранный календарь цикла.
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
              for (final e in events) _EventRow(event: e),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final CycleEvent event;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = cycleEventTypeMeta(event.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'день ${event.day}',
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(meta.icon, size: 18, color: meta.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.title,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            event.type,
            style: text.bodySmall?.copyWith(
              color: meta.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
