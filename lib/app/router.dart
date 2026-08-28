import 'package:cluckfall_heights/app/shell.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/features/analysis/analysis_screen.dart';
import 'package:cluckfall_heights/features/analysis/rearrangement_screen.dart';
import 'package:cluckfall_heights/features/bootstrap/loading_screen.dart';
import 'package:cluckfall_heights/features/builder/builder_screen.dart';
import 'package:cluckfall_heights/features/insights/guide_article_screen.dart';
import 'package:cluckfall_heights/features/insights/insights_screen.dart';
import 'package:cluckfall_heights/features/legal/document_screen.dart';
import 'package:cluckfall_heights/features/library/object_editor_screen.dart';
import 'package:cluckfall_heights/features/library/object_picker_sheet.dart';
import 'package:cluckfall_heights/features/onboarding/welcome_screen.dart';
import 'package:cluckfall_heights/features/plans/create_structure_screen.dart';
import 'package:cluckfall_heights/features/plans/plans_screen.dart';
import 'package:cluckfall_heights/features/profile/profile_screen.dart';
import 'package:cluckfall_heights/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every route in the app.
///
/// The three tabs sit inside a shell so the dock stays put while they change.
/// Everything opened from a tab is pushed above the shell instead, because a plan
/// or a policy is a place you finish and leave, and hiding the dock makes the back
/// button the obvious way out.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    // OneLink / partner URLs must not become Flutter routes.
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LoadingScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),

      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/plans',
            pageBuilder: (_, state) => _fade(state, const PlansScreen()),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (_, state) => _fade(state, const ObjectLibraryScreen()),
          ),
          GoRoute(
            path: '/insights',
            pageBuilder: (_, state) => _fade(state, const InsightsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => _fade(state, const ProfileScreen()),
          ),
        ],
      ),

      GoRoute(
        path: '/insights/guide/:id',
        builder: (_, state) =>
            GuideArticleScreen(articleId: state.pathParameters['id']!),
      ),

      GoRoute(path: '/plans/new', builder: (_, _) => const CreateStructureScreen()),
      GoRoute(
        path: '/plans/:id',
        builder: (_, state) => BuilderScreen(structureId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'analysis',
            builder: (_, state) => AnalysisScreen(structureId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'rearrange',
            builder: (_, state) =>
                RearrangementScreen(structureId: state.pathParameters['id']!),
          ),
        ],
      ),

      GoRoute(path: '/library/new', builder: (_, _) => const ObjectEditorScreen()),
      GoRoute(
        path: '/library/:id',
        builder: (_, state) => ObjectEditorScreen(objectId: state.pathParameters['id']),
      ),

      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const DocumentScreen(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: '/legal/support',
        builder: (_, _) => const DocumentScreen(document: LegalDocument.support),
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.toString()),
  );
}

/// Tabs cross-fade rather than slide, since a horizontal slide reads as "deeper
/// into something" and switching tabs is not that.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.fast,
    reverseTransitionDuration: Motion.fast,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Reachable only if a deep link points somewhere that no longer exists, most
/// likely a plan that was deleted.
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('That page is not here'),
              const SizedBox(height: Insets.sm),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: Insets.xl),
              FilledButton(
                onPressed: () => context.go('/plans'),
                child: const Text('Go to my plans'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final GoRouter router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
