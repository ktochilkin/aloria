import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Шапка раздела «Обучение», которая при скролле тает: фон уходит в
/// прозрачность, заголовок исчезает — контент проступает под ней. Кнопки
/// (leading/actions) остаются видимыми и нажимаемыми. Использовать с
/// `Scaffold(extendBodyBehindAppBar: true)` и верхним отступом списка через
/// [fadingHeaderTopInset].
class FadingHeader extends StatelessWidget implements PreferredSizeWidget {
  const FadingHeader({
    super.key,
    required this.fade,
    this.title,
    this.leading,
    this.actions,
    this.baseColor,
    this.alwaysTransparent = false,
  });

  /// Прогресс затухания 0..1 (0 — вверху, 1 — шапка уехала).
  final ValueListenable<double> fade;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;

  /// Базовый цвет фона шапки (по умолчанию — фон Scaffold).
  final Color? baseColor;

  /// Фон всегда прозрачный (для экранов, где заголовок — крупный титул в
  /// контенте, а шапка только держит кнопки). Подложки иконок всё равно
  /// проявляются при скролле.
  final bool alwaysTransparent;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = baseColor ?? Theme.of(context).scaffoldBackgroundColor;
    return ValueListenableBuilder<double>(
      valueListenable: fade,
      builder: (context, t, _) {
        final visible = (1 - t).clamp(0.0, 1.0);
        return AppBar(
          backgroundColor:
              alwaysTransparent ? Colors.transparent : bg.withValues(alpha: visible),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: leading == null ? null : _anchor(leading!, t, scheme),
          title:
              title == null ? null : Opacity(opacity: visible, child: title),
          actions: actions == null
              ? null
              : [for (final a in actions!) _anchor(a, t, scheme)],
        );
      },
    );
  }

  /// По мере исчезновения фона шапки под иконкой проявляется круглая подложка
  /// с лёгкой тенью — кнопка остаётся «кнопкой», а не висит в воздухе.
  Widget _anchor(Widget child, double t, ColorScheme scheme) {
    if (t <= 0.01) return child;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface.withValues(alpha: t),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t * 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Прогресс затухания по вертикальному скроллу: полное затухание за ~одну
/// высоту тулбара. Возвращает `false`, чтобы уведомление шло дальше.
bool updateHeaderFade(ValueNotifier<double> fade, ScrollNotification n) {
  if (n.metrics.axis == Axis.vertical) {
    fade.value = (n.metrics.pixels / kToolbarHeight).clamp(0.0, 1.0);
  }
  return false;
}

/// Верхний отступ списка под прозрачной шапкой при `extendBodyBehindAppBar`:
/// ровно статус-бар + высота тулбара. Берём `viewPadding.top` (физический
/// статус-бар), а НЕ `padding.top`: при extendBodyBehindAppBar Scaffold сам
/// добавляет в `padding.top` высоту шапки, и `+ kToolbarHeight` задвоил бы её
/// (особенно заметно внутри shell с нижней навигацией).
double fadingHeaderTopInset(BuildContext context) =>
    MediaQuery.of(context).viewPadding.top + kToolbarHeight;
