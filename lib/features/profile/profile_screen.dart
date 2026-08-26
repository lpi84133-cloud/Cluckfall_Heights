import 'dart:io';

import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:cluckfall_heights/features/profile/avatar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The profile: who this is, and what their planning actually adds up to.
///
/// The numbers are counted from the plans on the device, so the screen has a
/// reason to exist beyond holding a photo. There are no badges or streaks here:
/// the figures are a record, not a reward.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences preferences = ref.watch(preferencesProvider);
    final List<Structure> plans = ref.watch(structuresProvider);
    final MeasurementSystem units = preferences.units;
    final AppPalette palette = context.palette;

    final List<StabilityReport> reports = plans
        .map(StabilityAnalyzer.analyse)
        .toList(growable: false);
    final int objects = reports.fold(0, (sum, r) => sum + r.objectCount);
    final double weight = reports.fold(0.0, (sum, r) => sum + r.totalWeightKg);
    final int sound = reports.where((r) => r.status == StabilityStatus.stable).length;
    final int needWork = reports.where((r) => r.status != StabilityStatus.stable).length;

    return AppPage(
      title: 'Profile',
      subtitle: 'Everything here is stored on this device only.',
      actions: [
        CircleAction(
          icon: LucideIcons.settings,
          tooltip: 'Settings',
          onTap: () => context.push('/settings'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IdentityCard(preferences: preferences),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Your planning so far'),
            ShelfCard(
              showTrim: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Plans',
                          value: '${plans.length}',
                          caption: plans.length == 1 ? 'saved' : 'saved on this device',
                        ),
                      ),
                      Expanded(
                        child: MetricTile(
                          label: 'Objects',
                          value: '$objects',
                          caption: 'placed across them',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Weight planned',
                          value: units.weight(weight, decimals: 0),
                          caption: 'in total',
                        ),
                      ),
                      Expanded(
                        child: MetricTile(
                          label: 'Reading sound',
                          value: '$sound of ${plans.length}',
                          caption: needWork == 0
                              ? 'nothing flagged'
                              : '$needWork need a look',
                          tint: needWork == 0 ? palette.stable : palette.caution,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            if (needWork > 0) ...[
              const SectionLabel('Worth revisiting'),
              for (int i = 0; i < plans.length; i++)
                if (reports[i].status != StabilityStatus.stable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: ShelfCard(
                      accent: reports[i].status.ink(palette),
                      showTrim: false,
                      padding: const EdgeInsets.all(Insets.md + 2),
                      onTap: () => context.push('/plans/${plans[i].id}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plans[i].name,
                                  style: AppTypography.bodyStrong.copyWith(
                                    color: palette.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reports[i].primaryFinding?.kind.title ??
                                      reports[i].status.label,
                                  style: AppTypography.caption.copyWith(
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: reports[i].status, compact: true),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: Insets.xl),
            ],

            const SectionLabel('About the app'),
            ShelfCard(
              showTrim: false,
              onTap: () => context.push('/legal/privacy'),
              padding: const EdgeInsets.all(Insets.md + 2),
              child: const _Row(
                icon: LucideIcons.shieldCheck,
                title: 'Privacy policy',
                subtitle: 'Readable with no connection',
              ),
            ),
            const SizedBox(height: Insets.sm),
            ShelfCard(
              showTrim: false,
              onTap: () => context.push('/legal/support'),
              padding: const EdgeInsets.all(Insets.md + 2),
              child: const _Row(
                icon: LucideIcons.circleHelp,
                title: 'Support and FAQ',
                subtitle: 'How the analysis works',
              ),
            ),
            const SizedBox(height: Insets.xxxl * 2),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

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
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
        Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
      ],
    );
  }
}

/// Photo and display name, both editable in place.
class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.preferences});

  final AppPreferences preferences;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.preferences.displayName,
  );
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _setPhoto(Future<String> Function() source) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final String path = await source();
      final String? previous = widget.preferences.avatarPath;
      await ref.read(preferencesProvider.notifier).setAvatarPath(path);
      await ref.read(avatarServiceProvider).discard(previous);
      await ref.read(feedbackProvider).saved();
    } on AvatarException catch (error) {
      if (error.failure != AvatarFailure.cancelled) {
        setState(() => _notice = error.description);
        await ref.read(feedbackProvider).error();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPhotoOptions() async {
    await ref.read(feedbackProvider).tap();
    if (!mounted) return;

    final AvatarService service = ref.read(avatarServiceProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile photo',
                style: AppTypography.heading.copyWith(color: context.palette.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Used only inside this app, on this device.',
                style: AppTypography.caption.copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: Insets.xl),
              AppButton(
                label: 'Take a photo',
                icon: LucideIcons.camera,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _setPhoto(service.capture);
                },
              ),
              const SizedBox(height: Insets.md),
              AppButton(
                label: 'Choose from library',
                icon: LucideIcons.image,
                kind: AppButtonKind.secondary,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _setPhoto(service.choose);
                },
              ),
              if (widget.preferences.avatarPath != null) ...[
                const SizedBox(height: Insets.md),
                AppButton(
                  label: 'Remove photo',
                  kind: AppButtonKind.destructive,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    final String? previous = widget.preferences.avatarPath;
                    await ref.read(preferencesProvider.notifier).setAvatarPath(null);
                    await ref.read(avatarServiceProvider).discard(previous);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final String? path = widget.preferences.avatarPath;
    final bool hasPhoto = path != null && File(path).existsSync();

    return ShelfCard(
      raised: true,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _busy ? null : _openPhotoOptions,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: palette.surfaceSunken,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.hairline, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _busy
                          ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.accent,
                                ),
                              ),
                            )
                          : hasPhoto
                          ? Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) => _Initials(
                                initials: widget.preferences.initials,
                              ),
                            )
                          : _Initials(initials: widget.preferences.initials),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.surface, width: 2),
                        ),
                        child: Icon(
                          hasPhoto ? LucideIcons.pencil : LucideIcons.camera,
                          size: 13,
                          color: palette.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: AppTypography.heading.copyWith(color: palette.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (value) => ref
                      .read(preferencesProvider.notifier)
                      .setDisplayName(value.trim()),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    ref
                        .read(preferencesProvider.notifier)
                        .setDisplayName(_name.text.trim());
                  },
                ),
              ),
            ],
          ),
          if (_notice != null) ...[
            const SizedBox(height: Insets.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 16, color: palette.caution),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    _notice!,
                    style: AppTypography.caption.copyWith(color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Center(
      child: Text(
        initials,
        style: AppTypography.display.copyWith(fontSize: 26, color: palette.textSecondary),
      ),
    );
  }
}
