import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The three top-level destinations.
///
/// Presented as a floating board seated on two uprights rather than as a full
/// width tab bar: it repeats the shelf motif, keeps the artwork behind it visible,
/// and the selected item is marked by an amber trim line under the label, the same
/// signal used on every card in the app.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const List<_Destination> _destinations = [
    _Destination(path: '/plans', label: 'Plans', icon: LucideIcons.layoutList),
    _Destination(path: '/library', label: 'Library', icon: LucideIcons.boxes),
    _Destination(
      path: '/insights',
      label: 'Insights',
      icon: LucideIcons.chartNoAxesColumn,
    ),
    _Destination(path: '/profile', label: 'You', icon: LucideIcons.userRound),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;
    final String location = GoRouterState.of(context).uri.path;
    final int index = _destinations.indexWhere((d) => location.startsWith(d.path));

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Insets.page, 0, Insets.page, Insets.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.all(Radius.circular(Corners.xxl)),
            border: Border.all(color: palette.hairline),
            boxShadow: Elevations.lifted(palette),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.sm),
            child: Row(
              children: [
                for (int i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _DockItem(
                      destination: _destinations[i],
                      selected: i == (index < 0 ? 0 : index),
                      onTap: () {
                        ref.read(feedbackProvider).tap();
                        context.go(_destinations[i].path);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}

class _DockItem extends StatelessWidget {
  const _DockItem({required this.destination, required this.selected, required this.onTap});

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tint = selected ? palette.textPrimary : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(Corners.lg)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 21, color: tint),
              const SizedBox(height: 5),
              Text(
                destination.label,
                style: AppTypography.overline.copyWith(color: tint, letterSpacing: 0.4),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: Motion.fast,
                height: 2,
                width: selected ? 22 : 0,
                decoration: BoxDecoration(
                  color: palette.shelfEdge,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
