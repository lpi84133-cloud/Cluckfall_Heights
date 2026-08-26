import 'package:cluckfall_heights/domain/insights/portfolio_insights.dart';
import 'package:cluckfall_heights/domain/insights/weekly_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the counts [WeeklyStabilitySummary] actually reads vary; everything
/// else is a plain zero so the constructor call stays readable.
PortfolioInsights _insights({int stable = 0, int caution = 0, int unstable = 0, int findings = 0}) {
  return PortfolioInsights(
    planCount: stable + caution + unstable,
    objectCount: 0,
    levelCount: 0,
    emptyLevelCount: 0,
    totalWeightKg: 0,
    totalCapacityKg: 0,
    stablePlans: stable,
    cautionPlans: caution,
    unstablePlans: unstable,
    findingCount: findings,
    fragileCount: 0,
    delicateCount: 0,
    averageCentreOfMass: 0,
    heaviestObjectKg: 0,
    heaviestObjectName: null,
    materials: const [],
    topObjects: const [],
    plans: const [],
  );
}

void main() {
  final DateTime now = DateTime(2026, 8, 26, 12);

  group('StabilitySnapshot', () {
    test('round-trips through json', () {
      final StabilitySnapshot original = StabilitySnapshot.of(
        _insights(stable: 2, caution: 1, unstable: 0, findings: 3),
        capturedAt: now,
      );
      final StabilitySnapshot restored = StabilitySnapshot.fromJson(original.toJson());

      expect(restored.capturedAt, original.capturedAt);
      expect(restored.stablePlans, 2);
      expect(restored.cautionPlans, 1);
      expect(restored.findingCount, 3);
      expect(restored.plansNeedingWork, 1);
    });
  });

  group('WeeklyStabilitySummary.build', () {
    test('has no baseline with an empty history', () {
      final WeeklyStabilitySummary summary = WeeklyStabilitySummary.build(
        insights: _insights(stable: 3),
        history: const [],
        now: now,
      );

      expect(summary.hasBaseline, isFalse);
      expect(summary.trend, StabilityTrend.steady);
    });

    test('ignores captures less than a week old', () {
      final StabilitySnapshot tooRecent = StabilitySnapshot.of(
        _insights(caution: 2),
        capturedAt: now.subtract(const Duration(days: 3)),
      );

      final WeeklyStabilitySummary summary = WeeklyStabilitySummary.build(
        insights: _insights(caution: 2),
        history: [tooRecent],
        now: now,
      );

      expect(summary.hasBaseline, isFalse);
    });

    test('uses the capture closest to seven days ago as the baseline', () {
      final StabilitySnapshot tenDaysAgo = StabilitySnapshot.of(
        _insights(unstable: 3),
        capturedAt: now.subtract(const Duration(days: 10)),
      );
      final StabilitySnapshot eightDaysAgo = StabilitySnapshot.of(
        _insights(unstable: 1),
        capturedAt: now.subtract(const Duration(days: 8)),
      );

      final WeeklyStabilitySummary summary = WeeklyStabilitySummary.build(
        insights: _insights(unstable: 1),
        history: [tenDaysAgo, eightDaysAgo],
        now: now,
      );

      expect(summary.hasBaseline, isTrue);
      expect(summary.baseline!.unstablePlans, 1);
    });

    test('fewer plans needing work than the baseline reads as improved', () {
      final StabilitySnapshot baseline = StabilitySnapshot.of(
        _insights(caution: 2, unstable: 1),
        capturedAt: now.subtract(const Duration(days: 7)),
      );

      final WeeklyStabilitySummary summary = WeeklyStabilitySummary.build(
        insights: _insights(caution: 1, unstable: 0),
        history: [baseline],
        now: now,
      );

      expect(summary.trend, StabilityTrend.improved);
      expect(summary.plansNeedingWorkDelta, -2);
    });

    test('more plans needing work than the baseline reads as worsened', () {
      final StabilitySnapshot baseline = StabilitySnapshot.of(
        _insights(stable: 3),
        capturedAt: now.subtract(const Duration(days: 8)),
      );

      final WeeklyStabilitySummary summary = WeeklyStabilitySummary.build(
        insights: _insights(stable: 1, caution: 2),
        history: [baseline],
        now: now,
      );

      expect(summary.trend, StabilityTrend.worsened);
      expect(summary.plansNeedingWorkDelta, 2);
    });

    test('the same count of plans needing work reads as steady', () {
      final StabilitySnapshot baseline = StabilitySnapshot.of(
        _insights(caution: 1, findings: 4),
        capturedAt: now.subtract(const Duration(days: 7)),
      );

      final WeeklyStabilitySummary summary = WeeklyStabilitySummary.build(
        insights: _insights(caution: 1, findings: 4),
        history: [baseline],
        now: now,
      );

      expect(summary.trend, StabilityTrend.steady);
      expect(summary.headline, isNotEmpty);
    });
  });
}
