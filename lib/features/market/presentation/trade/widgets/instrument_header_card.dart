import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/presentation/trade/coinbase_theme.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// === Coinbase-форматирование чисел ===

/// Группирует целую часть пробелами: 5614360 → «5 614 360».
String _grpInt(String s) {
  final neg = s.startsWith('-');
  final digits = neg ? s.substring(1) : s;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// Цена: 2 знака после запятой, целая часть с разделителями.
String _fmtPrice(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  return '${_grpInt(parts[0])}.${parts[1]}';
}

/// Число: целое → с разделителями, дробное → 2 знака.
String _fmtNum(double v) {
  if (v == v.roundToDouble()) return _grpInt(v.toInt().toString());
  return _fmtPrice(v);
}

/// Шаг цены: целое как есть, дробное — без хвостовых нулей (0.001, 0.5, 1).
String _fmtStep(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Изменение со знаком: +0.26 / −0.10.
String _fmtSigned(double v) {
  final sign = v > 0 ? '+' : (v < 0 ? '−' : '');
  return '$sign${_fmtPrice(v.abs())}';
}

/// Человеческая метка типа инструмента.
String _typeLabel(String type) {
  switch (type.toUpperCase()) {
    case 'CS':
      return 'Акция';
    case 'PS':
      return 'Преф';
    case 'BOND':
    case 'BONDS':
      return 'Облигация';
    case 'ETF':
      return 'Фонд';
    case 'FUTURES':
    case 'FUT':
      return 'Фьючерс';
    case 'CURRENCY':
      return 'Валюта';
    default:
      return type;
  }
}

/// Богатая «coinbase»-шапка инструмента: аватар, тикер, название компании,
/// крупная моно-цена + изменение (семантика). Подробная сетка статов из
/// котировки по умолчанию свёрнута и разворачивается тапом по «Подробнее».
class InstrumentHeaderCard extends ConsumerStatefulWidget {
  const InstrumentHeaderCard({
    super.key,
    required this.symbol,
    required this.exchange,
    required this.price,
  });

  /// Тикер инструмента.
  final String symbol;

  /// Биржа.
  final String exchange;

  /// Последняя котировка (null, пока не пришла).
  final MarketPrice? price;

  @override
  ConsumerState<InstrumentHeaderCard> createState() =>
      _InstrumentHeaderCardState();
}

class _InstrumentHeaderCardState extends ConsumerState<InstrumentHeaderCard> {
  /// Развёрнута ли подробная сетка статов. По умолчанию скрыта.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final symbol = widget.symbol;
    final exchange = widget.exchange;
    final text = Theme.of(context).textTheme;
    final p = widget.price;
    // Шаг цены — из разовой REST-детали инструмента (в потоке котировок его нет).
    final minStep = ref
        .watch(instrumentDetailProvider((symbol: symbol, exchange: exchange)))
        .valueOrNull
        ?.minStep;
    final cur = p?.currency == 'USD'
        ? '\$'
        : p?.currency == 'EUR'
            ? '€'
            : '₽';
    final change = p?.change;
    final pct = p?.changePercent;
    final up = (change ?? 0) >= 0;
    final changeColor = up ? cbUp : cbDown;
    final isBond = (p?.instrumentType ?? '').toUpperCase().contains('BOND');

    // Сетка статов — только присутствующие значения.
    final stats = <(String, String)>[];
    void addPrice(String label, double? v) {
      if (v != null) stats.add((label, '${_fmtPrice(v)} $cur'));
    }

    addPrice('Открытие', p?.open);
    addPrice('Закр. вчера', p?.prevClose);
    addPrice('Максимум', p?.high);
    addPrice('Минимум', p?.low);
    addPrice('Спрос', p?.bid);
    addPrice('Предложение', p?.ask);
    if (p?.volume != null) stats.add(('Объём', _fmtNum(p!.volume!)));
    if (p?.lotSize != null) {
      stats.add(('В лоте', '${_fmtNum(p!.lotSize!)} шт.'));
    }
    if (minStep != null) stats.add(('Шаг цены', _fmtStep(minStep)));
    if (isBond && p?.yieldValue != null) {
      stats.add(('Доходность', '${_fmtPrice(p!.yieldValue!)} %'));
    }
    if (isBond && p?.faceValue != null) {
      stats.add(('Номинал', '${_fmtPrice(p!.faceValue!)} $cur'));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InstrumentAvatar(
                  symbol: symbol,
                  label: symbol.length > 2 ? symbol.substring(0, 2) : symbol,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              symbol,
                              style: text.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p?.instrumentType != null) ...[
                            const SizedBox(width: 8),
                            _Badge(label: _typeLabel(p!.instrumentType!)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p?.description ?? 'Загрузка…',
                        style: text.bodyMedium?.copyWith(color: cbBody),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  p != null ? '${_fmtPrice(p.price)} $cur' : '—',
                  style: cbMono(size: 34, weight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                if (change != null && pct != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: changeColor,
                          size: 22,
                        ),
                        Text(
                          '${_fmtSigned(change)}  ${_fmtSigned(pct)}%',
                          style: cbMono(size: 14, color: changeColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _expanded ? 'Свернуть' : 'Подробнее об инструменте',
                        style: text.bodyMedium?.copyWith(
                          color: cbBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: cbBody,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                curve: Curves.easeOut,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          for (var i = 0; i < stats.length; i += 2)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i + 2 < stats.length ? 14 : 0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: _StatTile(item: stats[i])),
                                  Expanded(
                                    child: i + 1 < stats.length
                                        ? _StatTile(item: stats[i + 1])
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: cbSurfaceStrong,
        borderRadius: BorderRadius.all(Radius.circular(100)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cbBody,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.item});

  final (String, String) item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.$1,
          style: const TextStyle(fontSize: 13, color: cbMuted),
        ),
        const SizedBox(height: 2),
        Text(item.$2, style: cbMono(size: 15)),
      ],
    );
  }
}
