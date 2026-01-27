import 'package:flutter/material.dart';

class InstrumentAvatar extends StatelessWidget {
  const InstrumentAvatar({
    super.key,
    required this.symbol,
    required this.label,
    this.size = 44,
  });

  final String symbol;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = 'assets/icons/${symbol.toUpperCase()}.jpg';

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(
            color: scheme.primary.withValues(alpha: 0.16),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
