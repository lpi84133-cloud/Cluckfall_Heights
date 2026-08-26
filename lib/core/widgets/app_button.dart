import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

enum AppButtonKind {
  /// Amber fill. One per screen, for the action that moves the task forward.
  primary,

  /// Outlined. Secondary actions that are still safe.
  secondary,

  /// No fill, no border. Tertiary actions and inline links.
  quiet,

  /// Outlined in the unstable colour. Delete and reset.
  destructive,
}

class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.expand = true,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;

  /// Stretch to the available width. Off for buttons sitting in a row.
  final bool expand;

  /// Shows a spinner and blocks input while real work is running.
  final bool busy;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool enabled = widget.onPressed != null && !widget.busy;

    final (Color background, Color foreground, Color? border) = switch (widget.kind) {
      AppButtonKind.primary => (palette.accent, palette.accentInk, null),
      AppButtonKind.secondary => (Colors.transparent, palette.textPrimary, palette.hairline),
      AppButtonKind.quiet => (Colors.transparent, palette.textSecondary, null),
      AppButtonKind.destructive => (Colors.transparent, palette.unstable, palette.unstable),
    };

    final Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 18, color: foreground),
        if (widget.busy || widget.icon != null) const SizedBox(width: Insets.sm),
        Text(
          widget.label,
          style: AppTypography.button.copyWith(color: foreground),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          // A small settle on press, matching the physical feel of the artwork.
          scale: _pressed ? 0.975 : 1,
          duration: Motion.fast,
          curve: Motion.enter,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: Motion.fast,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: Corners.button,
                border: border == null ? null : Border.all(color: border, width: 1.4),
                boxShadow: widget.kind == AppButtonKind.primary && enabled
                    ? Elevations.card(palette)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.xl,
                  vertical: Insets.md + 3,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
