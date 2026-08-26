import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings that each change something the user can see.
///
/// There is no account row, because there is no account. The one notification
/// row is a single local, opt-in daily reminder — never a push notification,
/// and off until the user turns it on and picks a time.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences preferences = ref.watch(preferencesProvider);
    final PreferencesNotifier notifier = ref.read(preferencesProvider.notifier);
    final AppPalette palette = context.palette;

    return AppPage(
      title: 'Settings',
      subtitle: 'Units, appearance, feedback and your data.',
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Measurements'),
            ShelfCard(
              showTrim: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final MeasurementSystem system in MeasurementSystem.values)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: system == MeasurementSystem.values.first
                                  ? Insets.sm
                                  : 0,
                            ),
                            child: _Choice(
                              label: system.label,
                              caption: '${system.lengthUnit} / ${system.weightUnit}',
                              selected: preferences.units == system,
                              onTap: () {
                                ref.read(feedbackProvider).tap();
                                notifier.setUnits(system);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'Everything already saved is converted on the fly, so switching never '
                    'changes your plans.',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Appearance'),
            ShelfCard(
              showTrim: false,
              child: Row(
                children: [
                  for (final AppThemeChoice choice in AppThemeChoice.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: choice == AppThemeChoice.dark ? 0 : Insets.sm,
                        ),
                        child: _Choice(
                          label: switch (choice) {
                            AppThemeChoice.system => 'System',
                            AppThemeChoice.light => 'Light',
                            AppThemeChoice.dark => 'Dark',
                          },
                          caption: switch (choice) {
                            AppThemeChoice.system => 'Follow device',
                            AppThemeChoice.light => 'Daylight',
                            AppThemeChoice.dark => 'Low light',
                          },
                          selected: preferences.theme == choice,
                          onTap: () {
                            ref.read(feedbackProvider).tap();
                            notifier.setTheme(choice);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Feedback while you work'),
            ShelfCard(
              showTrim: false,
              child: Column(
                children: [
                  _Toggle(
                    icon: LucideIcons.volume2,
                    title: 'Interface sounds',
                    subtitle: 'Short clicks when objects land or a warning appears',
                    value: preferences.soundEnabled,
                    onChanged: (value) {
                      notifier.setSoundEnabled(value);
                      if (value) ref.read(feedbackProvider).tap();
                    },
                  ),
                  Divider(height: Insets.xl, color: palette.hairline),
                  _Toggle(
                    icon: LucideIcons.vibrate,
                    title: 'Haptics',
                    subtitle: 'A light tap when something is placed or flagged',
                    value: preferences.hapticsEnabled,
                    onChanged: (value) {
                      notifier.setHapticsEnabled(value);
                      if (value) HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Daily reminder'),
            ShelfCard(
              showTrim: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Toggle(
                    icon: LucideIcons.bellRing,
                    title: 'Remind me once a day',
                    subtitle: 'A single local nudge to check your shelves. Off by default.',
                    value: preferences.dailyReminderEnabled,
                    onChanged: (value) => _setReminderEnabled(context, ref, value),
                  ),
                  if (preferences.dailyReminderEnabled) ...[
                    Divider(height: Insets.xl, color: palette.hairline),
                    _ReminderTimeRow(
                      hour: preferences.dailyReminderHour,
                      minute: preferences.dailyReminderMinute,
                      onPick: (time) => notifier.setDailyReminderTime(
                        hour: time.hour,
                        minute: time.minute,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Your data'),
            ShelfCard(
              showTrim: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.hardDrive, size: 19, color: palette.textSecondary),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          'Plans, objects and your profile are stored on this device. The '
                          'app has no accounts, no analytics and no network requests.',
                          style: AppTypography.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  AppButton(
                    label: 'Reset everything',
                    kind: AppButtonKind.destructive,
                    onPressed: () => _confirmReset(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Legal'),
            ShelfCard(
              showTrim: false,
              padding: const EdgeInsets.all(Insets.md + 2),
              onTap: () => context.push('/legal/privacy'),
              child: const _LinkRow(
                icon: LucideIcons.shieldCheck,
                label: 'Privacy policy',
              ),
            ),
            const SizedBox(height: Insets.sm),
            ShelfCard(
              showTrim: false,
              padding: const EdgeInsets.all(Insets.md + 2),
              onTap: () => context.push('/legal/support'),
              child: const _LinkRow(icon: LucideIcons.circleHelp, label: 'Support and FAQ'),
            ),
            const SizedBox(height: Insets.xl),

            const _VersionLine(),
            const SizedBox(height: Insets.xxxl),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
          'This deletes every plan, every object you added and your profile from this '
          'device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(backupServiceProvider).resetEverything();
    ref.invalidate(structuresProvider);
    ref.invalidate(objectLibraryProvider);
    ref.invalidate(preferencesProvider);
    if (!context.mounted) return;
    context.go('/plans');
  }

  Future<void> _setReminderEnabled(BuildContext context, WidgetRef ref, bool value) async {
    final bool applied = await ref.read(preferencesProvider.notifier).setDailyReminderEnabled(value);
    if (applied || !context.mounted) return;
    // The user declined the OS permission prompt: leave the switch off rather
    // than showing a reminder that will never actually fire.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are turned off for Cluckfall Heights in system settings.',
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: Insets.md, horizontal: Insets.md),
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.surfaceSunken,
          borderRadius: const BorderRadius.all(Radius.circular(Corners.md)),
          border: Border.all(color: selected ? palette.accent : palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.bodyStrong.copyWith(
                color: selected ? palette.accentInk : palette.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              caption,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: selected
                    ? palette.accentInk.withValues(alpha: 0.75)
                    : palette.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Row(
      children: [
        Icon(icon, size: 19, color: palette.textSecondary),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.body.copyWith(color: palette.textPrimary)),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({
    required this.hour,
    required this.minute,
    required this.onPick,
  });

  final int hour;
  final int minute;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final TimeOfDay current = TimeOfDay(hour: hour, minute: minute);

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(Corners.sm)),
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: current,
        );
        if (picked != null) onPick(picked);
      },
      child: Row(
        children: [
          Icon(LucideIcons.clock3, size: 19, color: palette.textSecondary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Time',
              style: AppTypography.body.copyWith(color: palette.textPrimary),
            ),
          ),
          Text(
            current.format(context),
            style: AppTypography.bodyStrong.copyWith(color: palette.accent),
          ),
          const SizedBox(width: Insets.sm),
          Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Row(
      children: [
        Icon(icon, size: 19, color: palette.textSecondary),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Text(label, style: AppTypography.body.copyWith(color: palette.textPrimary)),
        ),
        Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
      ],
    );
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final PackageInfo? info = snapshot.data;
        return Text(
          info == null
              ? 'Cluckfall Heights'
              : 'Cluckfall Heights ${info.version} (${info.buildNumber})',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: palette.textTertiary),
        );
      },
    );
  }
}
