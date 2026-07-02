import 'package:aloria/features/market/domain/macro_extras.dart';
import 'package:aloria/features/market/presentation/widgets/macro_card.dart';
import 'package:flutter/material.dart';

/// Дуга экономического цикла: 4 фазы по порядку, текущая подсвечена.
class CycleArc extends StatelessWidget {
  const CycleArc({super.key, required this.currentRegime});

  final String currentRegime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentIdx = cyclePhases.indexWhere((p) => p.regime == currentRegime);

    return Row(
      children: [
        for (var i = 0; i < cyclePhases.length; i++) ...[
          Expanded(
            child: _PhaseNode(
              label: cyclePhases[i].label,
              color: macroRegimeMeta(cyclePhases[i].regime).color,
              active: i == currentIdx,
              passed: currentIdx >= 0 && i < currentIdx,
            ),
          ),
          if (i < cyclePhases.length - 1)
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ],
    );
  }
}

class _PhaseNode extends StatelessWidget {
  const _PhaseNode({
    required this.label,
    required this.color,
    required this.active,
    required this.passed,
  });

  final String label;
  final Color color;
  final bool active;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dotColor = active
        ? color
        : (passed
              ? color.withValues(alpha: 0.45)
              : scheme.surfaceContainerHighest);

    return Column(
      children: [
        Container(
          width: active ? 16 : 12,
          height: active ? 16 : 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: (active || passed)
                ? null
                : Border.all(color: scheme.outline),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: text.labelSmall?.copyWith(
            color: active ? color : scheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
