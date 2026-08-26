import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/domain/insights/storage_guide.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One reference article, rendered natively.
///
/// Native rather than a web view: this is the app's own content, it has to read
/// well offline and in either theme, and the block model keeps the typography
/// consistent with the rest of the app.
class GuideArticleScreen extends StatelessWidget {
  const GuideArticleScreen({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    final GuideArticle? article = StorageGuide.byId(articleId);

    if (article == null) {
      return AppPage(
        title: 'Not found',
        showBack: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.page),
          child: EmptyState(
            icon: LucideIcons.fileQuestion,
            title: 'That article is not here',
            message: 'It may have been renamed in a newer version of the app.',
            actionLabel: 'Back to insights',
            onAction: () => context.go('/insights'),
          ),
        ),
      );
    }

    final int index = StorageGuide.all.indexOf(article);
    final GuideArticle? next = index >= 0 && index < StorageGuide.all.length - 1
        ? StorageGuide.all[index + 1]
        : null;

    return AppPage(
      title: article.title,
      subtitle: '${article.readMinutes} min read',
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final GuideBlock block in article.blocks) _Block(block: block),
            const SizedBox(height: Insets.xl),
            if (next != null) ...[
              const SectionLabel('Next'),
              const SizedBox(height: Insets.md),
              ShelfCard(
                onTap: () => context.pushReplacement('/insights/guide/${next.id}'),
                padding: const EdgeInsets.all(Insets.md + 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next.title,
                            style: AppTypography.bodyStrong.copyWith(
                              color: context.palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            next.summary,
                            style: AppTypography.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.palette.textTertiary,
                    ),
                  ],
                ),
              ),
            ] else ...[
              AppButton(
                label: 'Back to insights',
                kind: AppButtonKind.secondary,
                icon: LucideIcons.chartNoAxesColumn,
                onPressed: () => context.go('/insights'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Block rendering
// ────────────────────────────────────────────────────────────────────────────

class _Block extends StatelessWidget {
  const _Block({required this.block});

  final GuideBlock block;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return switch (block) {
      GuideHeading(:final String text) => Padding(
        padding: const EdgeInsets.only(top: Insets.xl, bottom: Insets.sm),
        child: Text(
          text,
          style: AppTypography.title.copyWith(color: palette.textPrimary),
        ),
      ),

      GuideText(:final String text) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Text(
          text,
          style: AppTypography.body.copyWith(
            color: palette.textSecondary,
            height: 1.55,
          ),
        ),
      ),

      GuidePoints(:final List<String> points) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final String point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A shelf-edge dash rather than a bullet, to match the motif.
                    Container(
                      margin: const EdgeInsets.only(top: 9, right: Insets.md),
                      width: 10,
                      height: 2,
                      color: palette.shelfEdge,
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: AppTypography.body.copyWith(
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),

      GuideFigure(:final String value, :final String caption) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: ShelfCard(
          accent: palette.accent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.metric.copyWith(color: palette.accent),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    caption,
                    style: AppTypography.caption.copyWith(
                      color: palette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    };
  }
}
