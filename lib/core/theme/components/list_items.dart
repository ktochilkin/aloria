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
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface.withValues(alpha: 0.96),
              scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: gap,
                  thickness: 1,
                  color: scheme.outline.withValues(alpha: 0.55),
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
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool isThreeLine;

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
    return ListTile(
      leading: leading,
      title: Text(title, style: titleStyle?.copyWith(color: color)),
      subtitle: subtitleContent,
      trailing: trailing,
      onTap: onTap,
      isThreeLine: isThreeLine,
      tileColor: Colors.transparent,
      hoverColor: scheme.primary.withValues(alpha: 0.05),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    );
  }
}
