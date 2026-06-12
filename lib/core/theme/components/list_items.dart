import 'package:flutter/material.dart';

class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.gap = 8,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // База Coinbase: белая карта, hairline-граница вместо тени, радиус 24.
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: gap,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  indent: 16,
                  endIndent: 16,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.isThreeLine = false,
    this.topAlignTrailing = false,
    this.contentPadding = const EdgeInsets.symmetric(
      vertical: 8,
      horizontal: 12,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool isThreeLine;
  final bool topAlignTrailing;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.bodyLarge;
    final subtitleStyle = theme.textTheme.bodySmall;
    final color = destructive ? scheme.error : scheme.onSurface;
    final subtitleContent =
        subtitleWidget ??
        (subtitle == null
            ? null
            : Text(
                subtitle!,
                style: subtitleStyle?.copyWith(color: scheme.onSurfaceVariant),
              ));
    final trailingContent = topAlignTrailing && trailing != null
        ? Align(alignment: Alignment.topRight, child: trailing)
        : trailing;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      hoverColor: scheme.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: contentPadding,
        child: Row(
          crossAxisAlignment: topAlignTrailing
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleContent != null) ...[
                    const SizedBox(height: 4),
                    subtitleContent,
                  ],
                ],
              ),
            ),
            if (trailingContent != null) ...[
              const SizedBox(width: 12),
              trailingContent,
            ],
          ],
        ),
      ),
    );
  }
}
