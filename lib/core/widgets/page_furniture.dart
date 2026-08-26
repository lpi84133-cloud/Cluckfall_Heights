import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Standard page frame.
///
/// The title is part of the scrolling content rather than a fixed app bar, which
/// gives the display face room to be large on arrival and hands the space back to
/// the content as the user scrolls. A thin amber rule under the header repeats the
/// shelf-edge motif that the cards use.
class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.bottomBar,
    this.scrollable = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool showBack;
  final Widget? bottomBar;

  /// Off for screens that manage their own scrolling, such as the builder.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(Insets.page, Insets.md, Insets.page, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack) ...[
                _CircleAction(
                  icon: LucideIcons.arrowLeft,
                  tooltip: 'Back',
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/plans');
                    }
                  },
                ),
                const SizedBox(width: Insets.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.display.copyWith(color: palette.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final Widget action in actions) ...[
                const SizedBox(width: Insets.sm),
                action,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Insets.xs),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: Insets.md),
          Container(height: 2, width: 44, color: palette.shelfEdge),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header,
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: Insets.xxxl),
                      child: child,
                    )
                  : child,
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class CircleAction extends StatelessWidget {
  const CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) =>
      _CircleAction(icon: icon, tooltip: tooltip, onTap: onTap, tint: tint);
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(icon, size: 19, color: tint ?? palette.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Small caps label that groups the block below it.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppTypography.overline.copyWith(color: context.palette.textSecondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Shown when a list is genuinely empty, always with the action that fills it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: Insets.xxl),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: Corners.card,
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(icon, size: 28, color: palette.textSecondary),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            title,
            style: AppTypography.heading.copyWith(color: palette.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            message,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Insets.xl),
            AppButton(label: actionLabel!, expand: false, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// A labelled measurement, used across the analysis panels.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.caption,
    this.tint,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.overline.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          value,
          style: AppTypography.metric.copyWith(color: tint ?? palette.textPrimary),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ],
    );
  }
}
