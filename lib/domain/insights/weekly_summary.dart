import 'package:cluckfall_heights/domain/insights/portfolio_insights.dart';
import 'package:meta/meta.dart';

/// A count of plans by stability status, captured at one moment.
///
/// A rolling history of these, taken roughly once a day, is what lets the
/// weekly summary compare "now" against "about a week ago" without needing a
/// calendar-aware notion of when a week starts.
@immutable
class StabilitySnapshot {
  const StabilitySnapshot({
    required this.capturedAt,
    required this.stablePlans,
    required this.cautionPlans,
    required this.unstablePlans,
    required this.findingCount,
  });

  factory StabilitySnapshot.fromJson(Map<String, dynamic> json) {
    return StabilitySnapshot(
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
      stablePlans: json['stablePlans'] as int? ?? 0,
      cautionPlans: json['cautionPlans'] as int? ?? 0,
      unstablePlans: json['unstablePlans'] as int? ?? 0,
      findingCount: json['findingCount'] as int? ?? 0,
    );
  }

  factory StabilitySnapshot.of(PortfolioInsights insights, {required DateTime capturedAt}) {
    return StabilitySnapshot(
      capturedAt: capturedAt,
      stablePlans: insights.stablePlans,
      cautionPlans: insights.cautionPlans,
      unstablePlans: insights.unstablePlans,
      findingCount: insights.findingCount,
    );
  }

  final DateTime capturedAt;
  final int stablePlans;
  final int cautionPlans;
  final int unstablePlans;
  final int findingCount;

  int get plansNeedingWork => cautionPlans + unstablePlans;

  Map<String, dynamic> toJson() => {
    'capturedAt': capturedAt.toIso8601String(),
    'stablePlans': stablePlans,
    'cautionPlans': cautionPlans,
    'unstablePlans': unstablePlans,
    'findingCount': findingCount,
  };
}

enum StabilityTrend { improved, steady, worsened }

/// How the portfolio reads now compared to about a week ago.
///
/// Built from a short local history of [StabilitySnapshot]s rather than any
/// server data — nothing here is invented, and there is honestly nothing to
/// compare against until the app has a week of history behind it.
@immutable
class WeeklyStabilitySummary {
  const WeeklyStabilitySummary({required this.current, this.baseline});

  /// Rebuilds the comparison from a capture history plus live insights.
  ///
  /// [history] does not need to be sorted or de-duplicated by the caller: it
  /// is exactly what has been recorded so far.
  factory WeeklyStabilitySummary.build({
    required PortfolioInsights insights,
    required List<StabilitySnapshot> history,
    DateTime? now,
  }) {
    final DateTime today = now ?? DateTime.now();
    final StabilitySnapshot current = StabilitySnapshot.of(insights, capturedAt: today);
    if (history.isEmpty) return WeeklyStabilitySummary(current: current);

    final DateTime weekAgo = today.subtract(const Duration(days: 7));
    // The most recent capture that is at least a week old, so a summary
    // built on day eight still reads as "about a week ago" instead of
    // demanding an exact seven-day match.
    final List<StabilitySnapshot> eligible =
        history.where((snapshot) => !snapshot.capturedAt.isAfter(weekAgo)).toList()
          ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    return WeeklyStabilitySummary(
      current: current,
      baseline: eligible.isEmpty ? null : eligible.first,
    );
  }

  final StabilitySnapshot current;

  /// The closest capture to seven days ago. Null until the app has enough
  /// history for that to exist, so there is nothing false to compare against.
  final StabilitySnapshot? baseline;

  bool get hasBaseline => baseline != null;

  int get plansNeedingWorkDelta =>
      hasBaseline ? current.plansNeedingWork - baseline!.plansNeedingWork : 0;

  int get findingDelta => hasBaseline ? current.findingCount - baseline!.findingCount : 0;

  StabilityTrend get trend {
    if (!hasBaseline) return StabilityTrend.steady;
    if (plansNeedingWorkDelta < 0) return StabilityTrend.improved;
    if (plansNeedingWorkDelta > 0) return StabilityTrend.worsened;
    if (findingDelta < 0) return StabilityTrend.improved;
    if (findingDelta > 0) return StabilityTrend.worsened;
    return StabilityTrend.steady;
  }

  /// One line summarising the week, built only from real counts.
  String get headline {
    if (!hasBaseline) {
      return current.plansNeedingWork == 0
          ? 'Everything reads stable so far.'
          : '${_plural(current.plansNeedingWork, 'plan')} could use a look. Check '
                'back in a week to see how that changes.';
    }

    final int delta = plansNeedingWorkDelta;
    switch (trend) {
      case StabilityTrend.improved:
        return delta < 0
            ? '${_plural(-delta, 'plan')} fewer need attention than about a week ago.'
            : 'Fewer open findings than about a week ago.';
      case StabilityTrend.worsened:
        return delta > 0
            ? '${_plural(delta, 'plan')} more need attention than about a week ago.'
            : 'A few more open findings than about a week ago.';
      case StabilityTrend.steady:
        return 'About the same as this time last week.';
    }
  }

  static String _plural(int count, String noun) => '$count $noun${count == 1 ? '' : 's'}';
}
