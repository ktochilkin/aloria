import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/cycle_events.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/presentation/widgets/macro_card.dart';
import 'package:flutter/material.dart';

/// Открывает полноэкранный календарь цикла.
void openCycleCalendar(
  BuildContext context,
  MacroState macro,
  List<MarketSecurity> securities,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CycleCalendarPage(macro: macro, securities: securities),
    ),
  );
}

enum _CalView { agenda, days, road, density }

/// Календарь цикла, прототип: 4 варианта оформления на выбор
/// (агенда / карточки дней / дорожка цикла / плотность).
class CycleCalendarPage extends StatefulWidget {
  const CycleCalendarPage({
    super.key,
    required this.macro,
    required this.securities,
  });

  final MacroState macro;
  final List<MarketSecurity> securities;

  @override
  State<CycleCalendarPage> createState() => _CycleCalendarPageState();
}

class _CycleCalendarPageState extends State<CycleCalendarPage> {
  _CalView _view = _CalView.agenda;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = macroRegimeMeta(widget.macro.regime);

    final len = widget.macro.cycleLength <= 0 ? 10 : widget.macro.cycleLength;
    final today = widget.macro.cycleDay;
    final events = buildMockCycleEvents(widget.macro, widget.securities);
    final byDay = <int, List<CycleEvent>>{};
    for (final e in events) {
      (byDay[e.day] ??= []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь цикла')),
      body: Column(
        children: [
          // Контекст цикла + переключатель оформления
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    meta.color.withValues(alpha: 0.16),
                    meta.color.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'День $today из $len',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${events.length} событий в цикле',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      meta.label,
                      style: text.labelMedium?.copyWith(
                        color: meta.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              children: [
                for (final v in _CalView.values) ...[
                  ChoiceChip(
                    label: Text(switch (v) {
                      _CalView.agenda => 'Агенда',
                      _CalView.days => 'Дни',
                      _CalView.road => 'Дорожка',
                      _CalView.density => 'Плотность',
                    }),
                    selected: _view == v,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _view = v),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (_view) {
              _CalView.agenda => _AgendaView(
                len: len,
                today: today,
                byDay: byDay,
              ),
              _CalView.days => _DayCardsView(
                len: len,
                today: today,
                byDay: byDay,
              ),
              _CalView.road => _RoadView(len: len, today: today, byDay: byDay),
              _CalView.density => _DensityView(
                len: len,
                today: today,
                byDay: byDay,
              ),
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════ ВАРИАНТ 1: АГЕНДА ═══════════════════════════
// Классика календарных приложений: вертикальная лента, дни — заголовками,
// прошлое приглушено, «сегодня» подсвечен. Скроллится к сегодня при открытии.

class _AgendaView extends StatelessWidget {
  const _AgendaView({
    required this.len,
    required this.today,
    required this.byDay,
  });

  final int len;
  final int today;
  final Map<int, List<CycleEvent>> byDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final children = <Widget>[];
    for (var day = 1; day <= len; day++) {
      final isToday = day == today;
      final isPast = day < today;
      final events = byDay[day] ?? const <CycleEvent>[];

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday
                      ? scheme.primary
                      : scheme.surfaceContainerHighest.withValues(
                          alpha: isPast ? 0.5 : 1,
                        ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$day',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isToday
                        ? scheme.onPrimary
                        : isPast
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isToday
                    ? 'Сегодня'
                    : isPast
                    ? 'День $day · прошёл'
                    : 'День $day',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isPast
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                      : isToday
                      ? scheme.primary
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(color: scheme.outline.withValues(alpha: 0.25)),
              ),
            ],
          ),
        ),
      );

      if (events.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 60, right: 16, bottom: 4),
            child: Text(
              'событий нет',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      } else {
        for (final e in events) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(left: 44, right: 16, bottom: 2),
              child: Opacity(
                opacity: isPast ? 0.55 : 1,
                child: CycleEventTile(event: e, dense: true),
              ),
            ),
          );
        }
      }
    }

    return ListView(
      controller: ScrollController(
        initialScrollOffset: ((today - 1) * 96.0).clamp(0, 2000),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      children: children,
    );
  }
}

// ═════════════════════ ВАРИАНТ 2: КАРТОЧКИ ДНЕЙ ══════════════════════════
// Горизонтальный PageView: один день — одна крупная карточка, сегодня в
// центре при открытии. Свайп — листание дней.

class _DayCardsView extends StatefulWidget {
  const _DayCardsView({
    required this.len,
    required this.today,
    required this.byDay,
  });

  final int len;
  final int today;
  final Map<int, List<CycleEvent>> byDay;

  @override
  State<_DayCardsView> createState() => _DayCardsViewState();
}

class _DayCardsViewState extends State<_DayCardsView> {
  late final PageController _controller = PageController(
    initialPage: widget.today - 1,
    viewportFraction: 0.86,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return PageView.builder(
      controller: _controller,
      itemCount: widget.len,
      itemBuilder: (context, i) {
        final day = i + 1;
        final isToday = day == widget.today;
        final events = widget.byDay[day] ?? const <CycleEvent>[];

        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 24),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isToday ? scheme.primary : scheme.outline,
                width: isToday ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$day',
                        style: text.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isToday ? scheme.primary : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(
                          isToday ? 'сегодня' : 'день цикла',
                          style: text.bodySmall?.copyWith(
                            color: isToday
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${events.length} соб.',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: events.isEmpty
                      ? Center(
                          child: Text(
                            'Свободный день',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                          itemCount: events.length,
                          itemBuilder: (context, j) =>
                              CycleEventTile(event: events[j]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════ ВАРИАНТ 3: ДОРОЖКА ЦИКЛА ═════════════════════════
// Метро-схема: горизонтальная линия цикла со «станциями»-днями; над станцией
// иконки её событий. Тап по станции — повестка дня снизу.

class _RoadView extends StatefulWidget {
  const _RoadView({
    required this.len,
    required this.today,
    required this.byDay,
  });

  final int len;
  final int today;
  final Map<int, List<CycleEvent>> byDay;

  @override
  State<_RoadView> createState() => _RoadViewState();
}

class _RoadViewState extends State<_RoadView> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected ?? widget.today;
    final events = widget.byDay[selected] ?? const <CycleEvent>[];

    return Column(
      children: [
        SizedBox(
          height: 128,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                for (var day = 1; day <= widget.len; day++) ...[
                  _RoadStation(
                    day: day,
                    isToday: day == widget.today,
                    isSelected: day == selected,
                    isPast: day < widget.today,
                    events: widget.byDay[day] ?? const [],
                    onTap: () => setState(() => _selected = day),
                  ),
                  if (day != widget.len)
                    Container(
                      width: 26,
                      height: 3,
                      margin: const EdgeInsets.only(top: 26),
                      color: day < widget.today
                          ? scheme.primary.withValues(alpha: 0.6)
                          : scheme.outline.withValues(alpha: 0.4),
                    ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                selected == widget.today
                    ? 'Сегодня · день $selected'
                    : 'День $selected',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Text(
                    'На этот день событий нет',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  itemCount: events.length,
                  itemBuilder: (context, i) => CycleEventTile(event: events[i]),
                ),
        ),
      ],
    );
  }
}

class _RoadStation extends StatelessWidget {
  const _RoadStation({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isPast,
    required this.events,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final List<CycleEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final types = <String>[];
    for (final e in events) {
      if (!types.contains(e.type)) types.add(e.type);
      if (types.length == 3) break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in types)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Icon(
                      cycleEventTypeMeta(t).icon,
                      size: 15,
                      color: cycleEventTypeMeta(t).color,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? scheme.primary
                  : isToday
                  ? scheme.primary.withValues(alpha: 0.12)
                  : isPast
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.surfaceContainerHighest,
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: Text(
              '$day',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? scheme.onPrimary
                    : isToday
                    ? scheme.primary
                    : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 16,
            child: isToday
                ? Text(
                    'сегодня',
                    style: text.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════ ВАРИАНТ 4: ПЛОТНОСТЬ ════════════════════════════
// Цикл как 10 столбиков: высота — сколько событий в дне, сегменты столбика
// окрашены по типам. Сразу видно «горячие» дни. Тап — повестка снизу.

class _DensityView extends StatefulWidget {
  const _DensityView({
    required this.len,
    required this.today,
    required this.byDay,
  });

  final int len;
  final int today;
  final Map<int, List<CycleEvent>> byDay;

  @override
  State<_DensityView> createState() => _DensityViewState();
}

class _DensityViewState extends State<_DensityView> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected ?? widget.today;
    final events = widget.byDay[selected] ?? const <CycleEvent>[];
    final maxCount = widget.byDay.values.fold<int>(
      1,
      (m, l) => l.length > m ? l.length : m,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var day = 1; day <= widget.len; day++) ...[
                  Expanded(
                    child: _DensityBar(
                      day: day,
                      isToday: day == widget.today,
                      isSelected: day == selected,
                      events: widget.byDay[day] ?? const [],
                      maxCount: maxCount,
                      onTap: () => setState(() => _selected = day),
                    ),
                  ),
                  if (day != widget.len) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Text(
                selected == widget.today
                    ? 'Сегодня · день $selected'
                    : 'День $selected',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${events.length} событий',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Text(
                    'На этот день событий нет',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  itemCount: events.length,
                  itemBuilder: (context, i) => CycleEventTile(event: events[i]),
                ),
        ),
      ],
    );
  }
}

class _DensityBar extends StatelessWidget {
  const _DensityBar({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.maxCount,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final List<CycleEvent> events;
  final int maxCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const maxBarHeight = 88.0;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (events.isEmpty)
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            )
          else
            Column(
              children: [
                for (final e in events)
                  Container(
                    height: (maxBarHeight / maxCount) - 2,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: cycleEventTypeMeta(
                        e.type,
                      ).color.withValues(alpha: isSelected ? 1 : 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? scheme.primary
                  : isToday
                  ? scheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: Text(
              '$day',
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? scheme.onPrimary
                    : isToday
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════ ОБЩАЯ ПЛИТКА ════════════════════════════════

/// Плитка события (иконка по типу + название + тип) — общая для всех видов.
class CycleEventTile extends StatelessWidget {
  const CycleEventTile({super.key, required this.event, this.dense = false});

  final CycleEvent event;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meta = cycleEventTypeMeta(event.type);
    final size = dense ? 32.0 : 38.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: dense ? 3 : 6),
      child: Row(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, size: dense ? 16 : 19, color: meta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.title,
              style: (dense ? text.bodySmall : text.bodyMedium)?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
              fontSize: dense ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }
}
