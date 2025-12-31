import 'package:flutter/material.dart';

/// 显示无动画的菜单
Future<T?> showInstantMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<PopupMenuEntry<T>> items,
  T? initialValue,
  double? elevation,
  Color? shadowColor, // Ignored in simple implementation or used in Material
  Color? surfaceTintColor, // Ignored
  String? semanticLabel,
  ShapeBorder? shape,
  Color? color,
  BoxConstraints? constraints,
  Clip clipBehavior = Clip.none,
}) {
  final NavigatorState navigator = Navigator.of(context);
  return navigator.push(_InstantPopupMenuRoute<T>(
    position: position,
    items: items,
    initialValue: initialValue,
    elevation: elevation,
    semanticLabel: semanticLabel,
    shape: shape,
    color: color,
    capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
    constraints: constraints,
    clipBehavior: clipBehavior,
  ));
}

class _InstantPopupMenuRoute<T> extends PopupRoute<T> {
  _InstantPopupMenuRoute({
    required this.position,
    required this.items,
    this.initialValue,
    this.elevation,
    this.semanticLabel,
    this.shape,
    this.color,
    required this.capturedThemes,
    this.constraints,
    this.clipBehavior = Clip.none,
  });

  final RelativeRect position;
  final List<PopupMenuEntry<T>> items;
  final T? initialValue;
  final double? elevation;
  final String? semanticLabel;
  final ShapeBorder? shape;
  final Color? color;
  final CapturedThemes capturedThemes;
  final BoxConstraints? constraints;
  final Clip clipBehavior;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null; // Transparent barrier

  @override
  String? get barrierLabel => 'Close menu';

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return _InstantPopupMenu<T>(route: this);
  }
}

class _InstantPopupMenu<T> extends StatelessWidget {
  const _InstantPopupMenu({required this.route});

  final _InstantPopupMenuRoute<T> route;

  @override
  Widget build(BuildContext context) {
    // Positioning logic (Simplified)
    // We assume LTRB is provided correctly.
    // For a robust implementation we might need SingleChildLayoutDelegate,
    // but Stack + Positioned is easier for specific "below button" cases.
    
    // Check Theme
    final PopupMenuThemeData popupTheme = PopupMenuTheme.of(context);
    final ShapeBorder? shape = route.shape ?? popupTheme.shape;
    final Color? color = route.color ?? popupTheme.color;
    final double elevation = route.elevation ?? popupTheme.elevation ?? 8.0;

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: route.position.top,
            left: route.position.left > route.position.right ? null : route.position.left,
            right: route.position.left > route.position.right ? route.position.right : null,
            // If right is supplied and logical (e.g. valid rect), use it?
            // RelativeRect.fromLTRB(left, top, right, bottom)
            // Left/Top are distance from Left/Top edge.
            // Right/Bottom are distance from Right/Bottom edge.
            
            child: Material(
              shape: shape,
              color: color,
              elevation: elevation,
              type: MaterialType.card,
              clipBehavior: route.clipBehavior,
              child: ConstrainedBox(
                constraints: route.constraints ?? const BoxConstraints(minWidth: 112.0),
                child: IntrinsicWidth(
                  stepWidth: 56.0,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListBody(
                      children: route.items,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InstantPopupMenuButton<T> extends StatelessWidget {
  const InstantPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.elevation,
    this.padding = const EdgeInsets.all(8.0),
    this.child,
    this.splashRadius,
    this.icon,
    this.iconSize,
    this.offset = Offset.zero,
    this.enabled = true,
    this.shape,
    this.color,
    this.enableFeedback,
    this.constraints,
    this.position = PopupMenuPosition.over,
    this.clipBehavior = Clip.none,
  }) : assert(
            !(child != null && icon != null),
            'You can only pass [icon] or [child], not both.');

  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final double? elevation;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final double? splashRadius;
  final Widget? icon;
  final double? iconSize;
  final Offset offset;
  final bool enabled;
  final ShapeBorder? shape;
  final Color? color;
  final bool? enableFeedback;
  final BoxConstraints? constraints;
  final PopupMenuPosition position;
  final Clip clipBehavior;

  void showButtonMenu(BuildContext context) {
    if (!enabled) return;

    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    
    final RelativeRect relativePosition = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero) + offset,
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showInstantMenu<T>(
      context: context,
      elevation: elevation,
      items: itemBuilder(context),
      initialValue: initialValue,
      position: relativePosition,
      shape: shape,
      color: color,
      constraints: constraints,
      clipBehavior: clipBehavior,
    ).then<void>((T? newValue) {
      if (!context.mounted) return;
      if (newValue == null) {
        onCanceled?.call();
      } else {
        onSelected?.call(newValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool enableFeedback = this.enableFeedback ?? true;

    assert(debugCheckHasMaterialLocalizations(context));

    if (child != null) {
      return InkWell(
        onTap: enabled ? () => showButtonMenu(context) : null,
        canRequestFocus: enabled,
        radius: splashRadius,
        enableFeedback: enableFeedback,
        child: child,
      );
    }

    return IconButton(
      icon: icon ?? Icon(Icons.adaptive.more),
      padding: padding,
      splashRadius: splashRadius,
      iconSize: iconSize,
      tooltip: tooltip,
      onPressed: enabled ? () => showButtonMenu(context) : null,
      enableFeedback: enableFeedback,
    );
  }
}
