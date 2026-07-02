import 'package:aloria/features/market/domain/macro_extras.dart';
import 'package:flutter/material.dart';

/// Как обычно реагируют секторы на текущий режим (тенденция, не правило).
class SectorSensitivity extends StatelessWidget {
  const SectorSensitivity({super.key, required this.regime});

  final String regime;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final map = sectorSensitivity[regime] ?? const {};
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Builder(
              builder: (context) {
                final m = sensitivityMeta(e.value);
                return Row(
                  children: [
                    Icon(m.icon, size: 18, color: m.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sectorTitles[e.key] ?? e.key,
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(
                      m.label,
                      style: text.bodySmall?.copyWith(
                        color: m.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Это тенденция, а не правило — реакция конкретной компании может '
          'отличаться, особенно если событие уже учтено в цене.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
