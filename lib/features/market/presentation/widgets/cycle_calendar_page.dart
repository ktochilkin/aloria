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

enum _CalView { feed, matrix, poster, week }

/// Календарь цикла, прототип v3: Лента / Матрица / Афиша / Неделя.
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
  _CalView _view = _CalView.feed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = macroRegimeMeta(widget.macro.regime);

    final len = widget.macro.cycleLength <= 0 ? 10 : widget.macro.cycleLength;
    final events = buildMockCycleEvents(widget.macro, widget.securities);
    final byDist = <int, List<CycleEvent>>{};
    for (final e in events) {
      (byDist[cycleDistance(widget.macro, e.day)] ??= []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь цикла')),
      body: Column(
        children: [
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
                          'День ${widget.macro.cycleDay} из $len',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${events.length} событий впереди',
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
                      _CalView.feed => 'Лента',
                      _CalView.matrix => 'Матрица',
                      _CalView.poster => 'Афиша',
                      _CalView.week => 'Неделя',
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
              _CalView.feed => _FeedView(byDist: byDist, len: len),
              _CalView.matrix => _MatrixView(
                byDist: byDist,
                len: len,
                today: widget.macro.cycleDay,
              ),
              _CalView.poster => _PosterView(byDist: byDist),
              _CalView.week => _WeekView(
                byDist: byDist,
                len: len,
                today: widget.macro.cycleDay,
              ),
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════ ВАРИАНТ 1: ЛЕНТА ═════════════════════════════
// Поток событий по близости с человеческими заголовками «Сегодня / Завтра /
// Через N дней». Пустых дней в ленте просто нет — только то, что будет.

class _FeedView extends StatelessWidget {
  const _FeedView({required this.byDist, required this.len});

  final Map<int, List<CycleEvent>> byDist;
  final int len;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final children = <Widget>[];
    for (var dist = 0; dist < len; dist++) {
      final events = byDist[dist];
      if (events == null || events.isEmpty) continue;
      final isToday = dist == 0;

      children.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16, children.isEmpty ? 8 : 22, 16, 8),
          child: Row(
            children: [
              Text(
                _capitalize(humanDayLabel(dist)),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isToday ? scheme.primary : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(color: scheme.outline.withValues(alpha: 0.25)),
              ),
              const SizedBox(width: 10),
              Text(
                '${events.length}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );

      for (final e in events) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CycleEventTile(event: e),
          ),
        );
      }
    }

    if (children.isEmpty) {
      return Center(
        child: Text(
          'Впереди тихо — событий нет',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: children,
    );
  }
}

// ═════════════════════════ ВАРИАНТ 2: МАТРИЦА ════════════════════════════
// Расписание типы × дни: каждая строка — тип события со своей иконкой,
// колонки — дни цикла. Видно и ритм («купоны каждые 2 дня»), и плотность.

class _MatrixView extends StatefulWidget {
  const _MatrixView({
    required this.byDist,
    required this.len,
    required this.today,
  });

  final Map<int, List<CycleEvent>> byDist;
  final int len;
  final int today;

  @override
  State<_MatrixView> createState() => _MatrixViewState();
}

class _MatrixViewState extends State<_MatrixView> {
  int _selectedDist = 0;

  static const _typeOrder = [
    'Отчётность',
    'Дивиденды',
    'Купон',
    'Ставка',
    'Погашение',
    'Экспирация',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final presentTypes = _typeOrder
        .where(
          (t) => widget.byDist.values.any((l) => l.any((e) => e.type == t)),
        )
        .toList();
    final selectedEvents = widget.byDist[_selectedDist] ?? const <CycleEvent>[];

    Widget cell(int dist, String type) {
      final count = (widget.byDist[dist] ?? const <CycleEvent>[])
          .where((e) => e.type == type)
          .length;
      final meta = cycleEventTypeMeta(type);
      return Expanded(
        child: Center(
          child: count == 0
              ? Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outline.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                )
              : Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: count > 1
                      ? Text(
                          '$count',
                          style: text.labelSmall?.copyWith(
                            color: meta.color,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : Icon(meta.icon, size: 13, color: meta.color),
                ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              // Заголовок: дни как колонки (тап — выбрать день)
              Row(
                children: [
                  const SizedBox(width: 96),
                  for (var dist = 0; dist < widget.len; dist++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDist = dist),
                        child: Container(
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: dist == _selectedDist
                                ? scheme.primary
                                : dist == 0
                                ? scheme.primary.withValues(alpha: 0.10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dist == 0 ? '•' : '+$dist',
                            style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: dist == _selectedDist
                                  ? scheme.onPrimary
                                  : dist == 0
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (final type in presentTypes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Row(
                          children: [
                            Icon(
                              cycleEventTypeMeta(type).icon,
                              size: 14,
                              color: cycleEventTypeMeta(type).color,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                type,
                                style: text.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var dist = 0; dist < widget.len; dist++)
                        cell(dist, type),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '• — сегодня · +N — через N дней · тапни колонку',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Text(
                _capitalize(humanDayLabel(_selectedDist)),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${selectedEvents.length} событий',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: selectedEvents.isEmpty
              ? Center(
                  child: Text(
                    'В этот день событий нет',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, i) =>
                      CycleEventTile(event: selectedEvents[i]),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════ ВАРИАНТ 3: АФИША ═════════════════════════════
// Крупные карточки-события, отсортированные по близости: «Завтра · Отчёт
// ЦифраЛаб». Листается вертикально по две в ряд — как афиша недели.

class _PosterView extends StatelessWidget {
  const _PosterView({required this.byDist});

  final Map<int, List<CycleEvent>> byDist;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final flat = <(int, CycleEvent)>[];
    final dists = byDist.keys.toList()..sort();
    for (final d in dists) {
      for (final e in byDist[d]!) {
        flat.add((d, e));
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: flat.length,
      itemBuilder: (context, i) {
        final (dist, e) = flat[i];
        final meta = cycleEventTypeMeta(e.type);
        final isToday = dist == 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isToday ? meta.color : scheme.outline,
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, size: 16, color: meta.color),
                  ),
                  const Spacer(),
                  Text(
                    humanDayLabel(dist),
                    style: text.labelSmall?.copyWith(
                      color: isToday ? meta.color : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                e.title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                e.type,
                style: text.labelSmall?.copyWith(
                  color: meta.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════ ВАРИАНТ 4: НЕДЕЛЯ ═════════════════════════════
// Сетка дней 2×5 с содержимым: в ячейке видно, ЧТО за события (иконка+тикер),
// а не просто точки. Тап — полная повестка дня снизу.

class _WeekView extends StatefulWidget {
  const _WeekView({
    required this.byDist,
    required this.len,
    required this.today,
  });

  final Map<int, List<CycleEvent>> byDist;
  final int len;
  final int today;

  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView> {
  int _selectedDist = 0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final selectedEvents = widget.byDist[_selectedDist] ?? const <CycleEvent>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.62,
            ),
            itemCount: widget.len,
            itemBuilder: (context, dist) {
              final events = widget.byDist[dist] ?? const <CycleEvent>[];
              final isSelected = dist == _selectedDist;
              final isToday = dist == 0;
              final dayNum = (widget.today - 1 + dist) % widget.len + 1;

              return GestureDetector(
                onTap: () => setState(() => _selectedDist = dist),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.10)
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : isToday
                          ? scheme.primary.withValues(alpha: 0.5)
                          : scheme.outline.withValues(alpha: 0.6),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$dayNum',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isToday ? scheme.primary : null,
                            ),
                          ),
                          const Spacer(),
                          if (isToday)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        dist == 0
                            ? 'сегодня'
                            : dist == 1
                            ? 'завтра'
                            : '+$dist дн',
                        style: text.labelSmall?.copyWith(
                          fontSize: 9.5,
                          color: isToday
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final e in events.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(
                                cycleEventTypeMeta(e.type).icon,
                                size: 10,
                                color: cycleEventTypeMeta(e.type).color,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  _shortTitle(e),
                                  style: text.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (events.length > 3)
                        Text(
                          '+${events.length - 3}',
                          style: text.labelSmall?.copyWith(
                            fontSize: 9,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                _capitalize(humanDayLabel(_selectedDist)),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${selectedEvents.length} событий',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: selectedEvents.isEmpty
              ? Center(
                  child: Text(
                    'В этот день событий нет',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, i) =>
                      CycleEventTile(event: selectedEvents[i]),
                ),
        ),
      ],
    );
  }

  static String _shortTitle(CycleEvent e) {
    // Из «Отчёт DIGI» оставляем хвост — тикер/суть.
    final parts = e.title.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : e.title;
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

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
