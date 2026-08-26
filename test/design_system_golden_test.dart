import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/app_chip.dart';
import 'package:cluckfall_heights/core/widgets/progress_track.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/stability_rail.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'helpers/app_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final Brightness brightness in Brightness.values) {
    testWidgets('design system gallery, ${brightness.name}', (tester) async {
      await pumpAndDecode(
        tester,
        themedHarness(brightness: brightness, child: const _Gallery()),
        surface: const Size(420, 1080),
      );

      await expectLater(
        find.byType(_Gallery),
        matchesGoldenFile('goldens/design_system_${brightness.name}.png'),
      );
    });
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pantry Shelf', style: AppTypography.display.copyWith(color: palette.textPrimary)),
            const SizedBox(height: Insets.xs),
            Text(
              '5 levels  ·  180 cm',
              style: AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: Insets.xl),

            Row(
              children: [
                for (final StabilityStatus status in StabilityStatus.values) ...[
                  StatusBadge(status: status),
                  const SizedBox(width: Insets.sm),
                ],
              ],
            ),
            const SizedBox(height: Insets.xl),

            ShelfCard(
              accent: palette.stable,
              onTap: () {},
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Garage Rack',
                          style: AppTypography.title.copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '4 levels  ·  28.4 kg',
                          style: AppTypography.caption.copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const StatusBadge(status: StabilityStatus.stable, compact: true),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
            ShelfCard(
              accent: palette.unstable,
              onTap: () {},
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kitchen Cabinet',
                          style: AppTypography.title.copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Heavy items on level 4',
                          style: AppTypography.caption.copyWith(color: palette.unstable),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            Text(
              'TOTAL WEIGHT',
              style: AppTypography.overline.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: Insets.xs),
            Text('28.4 kg', style: AppTypography.metric.copyWith(color: palette.textPrimary)),
            const SizedBox(height: Insets.xl),

            Row(
              children: [
                AppChip(label: 'All', selected: true, onSelected: () {}, count: 12),
                const SizedBox(width: Insets.sm),
                AppChip(label: 'Containers', selected: false, onSelected: () {}, count: 5),
                const SizedBox(width: Insets.sm),
                AppChip(label: 'Fragile', selected: false, onSelected: () {}, count: 2),
              ],
            ),
            const SizedBox(height: Insets.xl),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const StabilityRail(status: StabilityStatus.caution),
                const SizedBox(width: Insets.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ProgressTrack(value: 0.68),
                      const SizedBox(height: Insets.lg),
                      const ProgressTrack(value: 1),
                      const SizedBox(height: Insets.xl),
                      AppButton(label: 'Add object', icon: LucideIcons.plus, onPressed: () {}),
                      const SizedBox(height: Insets.md),
                      AppButton(
                        label: 'Open library',
                        kind: AppButtonKind.secondary,
                        onPressed: () {},
                      ),
                      const SizedBox(height: Insets.md),
                      AppButton(
                        label: 'Delete',
                        kind: AppButtonKind.destructive,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.xl),
                const SizedBox(height: 190, child: VerticalProgressTrack(value: 0.42)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
