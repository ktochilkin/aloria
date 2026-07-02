import 'dart:math' as math;

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

enum _CalView { circle, snake, grid, timeline }

/// Полноэкранный календарь цикла с переключателем оформления (прототип —
/// сравниваем варианты: круг / змейка / сетка / таймлайн).
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
  _CalView _view = _CalView.circle;
  int? _selected;

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
    final selected = _selected ?? today;
    void onSelect(int d) => setState(() => _selected = d);

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь цикла')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Контекст цикла
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  meta.color.withValues(alpha: 0.18),
                  meta.color.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Экономический цикл',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'День $today из $len',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _Pill(label: meta.label, color: meta.color),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Переключатель оформления
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final v in _CalView.values) ...[
                  ChoiceChip(
                    label: Text(_viewLabel(v)),
                    selected: _view == v,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _view = v),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Выбранное оформление
          switch (_view) {
            _CalView.circle => _CircleLayout(
              len: len,
              today: today,
              selected: selected,
              byDay: byDay,
              onSelect: onSelect,
            ),
            _CalView.snake => _SnakeLayout(
              len: len,
              today: today,
              selected: selected,
              byDay: byDay,
              onSelect: onSelect,
            ),
            _CalView.grid => _GridLayout(
              len: len,
              today: today,
              selected: selected,
              byDay: byDay,
              onSelect: onSelect,
            ),
            _CalView.timeline => _TimelineLayout(
              len: len,
              today: today,
              byDay: byDay,
            ),
          },
          // Повестка выбранного дня (для компактных оформлений)
          if (_view != _CalView.timeline) ...[
            const SizedBox(height: 20),
            _Agenda(
              day: selected,
              isToday: selected == today,
              events: byDay[selected] ?? const [],
            ),
          ],
        ],
      ),
    );
  }

  static String _viewLabel(_CalView v) => switch (v) {
    _CalView.circle => 'Круг',
    _CalView.snake => 'Змейка',
    _CalView.grid => 'Сетка',
    _CalView.timeline => 'Таймлайн',
  };
}

// ============================ ВАРИАНТ: КРУГ ===============================

class _CircleLayout extends StatelessWidget {
  const _CircleLayout({
    required this.len,
    required this.today,
    required this.selected,
    required this.byDay,
    required this.onSelect,
  });

  final int len;
  final int today;
  final int selected;
  final Map<int, List<CycleEvent>> byDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, 340.0);
        final center = size / 2;
        final r = center - 26;
        final selEvents = byDay[selected] ?? const [];

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // Центр — выбранный день
              Center(
                child: Container(
                  width: size * 0.4,
                  height: size * 0.4,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'день',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$selected',
                        style: text.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        selEvents.isEmpty
                            ? 'свободно'
                            : '${selEvents.length} событ.',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < len; i++)
                Builder(
                  builder: (context) {
                    final angle = -math.pi / 2 + 2 * math.pi * i / len;
                    final dx = center + r * math.cos(angle);
                    final dy = center + r * math.sin(angle);
                    return Positioned(
                      left: dx - 21,
                      top: dy - 21,
                      child: _DayMarker(
                        size: 42,
                        day: i + 1,
                        isToday: i + 1 == today,
                        isSelected: i + 1 == selected,
                        events: byDay[i + 1] ?? const [],
                        onTap: () => onSelect(i + 1),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// =========================== ВАРИАНТ: ЗМЕЙКА ==============================

class _SnakeLayout extends StatelessWidget {
  const _SnakeLayout({
    required this.len,
    required this.today,
    required this.selected,
    required this.byDay,
    required this.onSelect,
  });

  final int len;
  final int today;
  final int selected;
  final Map<int, List<CycleEvent>> byDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const perRow = 5;
    final rows = <List<int>>[];
    for (var i = 0; i < len; i += perRow) {
      final row = [for (var d = i + 1; d <= math.min(i + perRow, len); d++) d];
      rows.add((i ~/ perRow).isOdd ? row.reversed.toList() : row);
    }

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final d in rows[r])
                  _DayMarker(
                    size: 46,
                    day: d,
                    isToday: d == today,
                    isSelected: d == selected,
                    events: byDay[d] ?? const [],
                    onTap: () => onSelect(d),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============================ ВАРИАНТ: СЕТКА ==============================

class _GridLayout extends StatelessWidget {
  const _GridLayout({
    required this.len,
    required this.today,
    required this.selected,
    required this.byDay,
    required this.onSelect,
  });

  final int len;
  final int today;
  final int selected;
  final Map<int, List<CycleEvent>> byDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (var d = 1; d <= len; d++)
          _DayMarker(
            size: double.infinity,
            day: d,
            isToday: d == today,
            isSelected: d == selected,
            events: byDay[d] ?? const [],
            onTap: () => onSelect(d),
          ),
      ],
    );
  }
}

// ========================== ВАРИАНТ: ТАЙМЛАЙН =============================

class _TimelineLayout extends StatelessWidget {
  const _TimelineLayout({
    required this.len,
    required this.today,
    required this.byDay,
  });

  final int len;
  final int today;
  final Map<int, List<CycleEvent>> byDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var day = 1; day <= len; day++)
          _DayLane(
            day: day,
            events: byDay[day] ?? const [],
            isToday: day == today,
            isLast: day == len,
          ),
      ],
    );
  }
}

class _DayLane extends StatelessWidget {
  const _DayLane({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isLast,
  });

  final int day;
  final List<CycleEvent> events;
  final bool isToday;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _DayMarker(
                size: 40,
                day: day,
                isToday: isToday,
                isSelected: false,
                events: events,
                onTap: () {},
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: scheme.outline.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 18, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isToday)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Pill(label: 'сегодня', color: scheme.primary),
                    ),
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Свободный день',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final e in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EventTile(event: e),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ ОБЩИЕ ЭЛЕМЕНТЫ ==============================

class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.day,
    required this.isToday,
    required this.events,
  });

  final int day;
  final bool isToday;
  final List<CycleEvent> events;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'День $day',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              _Pill(label: 'сегодня', color: scheme.primary),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Text(
            'На этот день событий нет',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EventTile(event: e),
            ),
      ],
    );
  }
}

/// Маркер дня: круглый, с номером и точками типов событий. Используется во всех
/// оформлениях (размер задаётся снаружи; [double.infinity] — заполнить ячейку).
class _DayMarker extends StatelessWidget {
  const _DayMarker({
    required this.size,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final double size;
  final int day;
  final bool isToday;
  final bool isSelected;
  final List<CycleEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasEvents = events.isNotEmpty;

    final Color bg;
    final Color fg;
    final BoxBorder? border;
    if (isSelected) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
      border = null;
    } else if (isToday) {
      bg = scheme.primary.withValues(alpha: 0.10);
      fg = scheme.primary;
      border = Border.all(color: scheme.primary, width: 2);
    } else if (hasEvents) {
      bg = scheme.surface;
      fg = scheme.onSurface;
      border = Border.all(
        color: scheme.primary.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
      border = null;
    }

    final dotTypes = <String>[];
    for (final e in events) {
      if (!dotTypes.contains(e.type)) dotTypes.add(e.type);
      if (dotTypes.length == 3) break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            if (dotTypes.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in dotTypes)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.2),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.onPrimary
                              : cycleEventTypeMeta(t).color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final CycleEvent event;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = cycleEventTypeMeta(event.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, size: 19, color: meta.color),
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
                    color: meta.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: text.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
