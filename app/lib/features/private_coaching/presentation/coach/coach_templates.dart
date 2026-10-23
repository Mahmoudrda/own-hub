/// The starting points for a new package. Each fills every field except the
/// price, which stays hers to set.
library;

import '../../../../l10n/app_l10n.dart';
import '../../domain/coach_profile.dart';

enum PackageTemplate { fourWeeks, eightWeeks, twelveWeeks, blank }

String templateLabel(AppL10n l10n, PackageTemplate template) =>
    switch (template) {
      PackageTemplate.blank => l10n.blankPackage,
      _ => l10n.weeksSessions(
        _weeksLabel(l10n, template),
        l10n.countPluralOne1LiveSessionA(_sessions(template)),
      ),
    };

int _days(PackageTemplate t) => switch (t) {
  PackageTemplate.fourWeeks => 28,
  PackageTemplate.eightWeeks => 56,
  PackageTemplate.twelveWeeks => 84,
  PackageTemplate.blank => const PackageDraft().durationDays,
};

int _sessions(PackageTemplate t) => switch (t) {
  PackageTemplate.fourWeeks => 2,
  PackageTemplate.eightWeeks || PackageTemplate.twelveWeeks => 4,
  PackageTemplate.blank => const PackageDraft().liveSessionsPerMonth,
};

String _weeksLabel(AppL10n l10n, PackageTemplate t) =>
    l10n.countPluralOne1WeekOtherCount(_days(t) ~/ 7);

/// The draft a template starts from, written in the app's language.
PackageDraft templateDraft(
  AppL10n l10n,
  PackageTemplate template, {
  int order = 0,
}) {
  final plan = l10n.aWorkoutPlanMadeForYou;
  final sessions = l10n.liveVideoSessionsWithMe;
  final weekly = l10n.aWeeklyLookAtYourProgress;
  return switch (template) {
    PackageTemplate.fourWeeks => PackageDraft(
      title: l10n.weeksOfCoachingWithMe(_weeksLabel(l10n, template)),
      description: l10n.fourWeeksBuiltAroundYouAPlan,
      durationDays: _days(template),
      includes: <String>[plan, sessions, weekly],
      liveSessionsPerMonth: _sessions(template),
      sessionMinutes: 30,
      checkInsPerWeek: 1,
      order: order,
    ),
    PackageTemplate.eightWeeks => PackageDraft(
      title: l10n.weeksOfCoachingWithMe(_weeksLabel(l10n, template)),
      description: l10n.eightWeeksToBuildARoutineThat,
      durationDays: _days(template),
      includes: <String>[plan, sessions, weekly, l10n.aPlanThatChangesAsYouDo],
      liveSessionsPerMonth: _sessions(template),
      sessionMinutes: 45,
      checkInsPerWeek: 1,
      order: order,
    ),
    PackageTemplate.twelveWeeks => PackageDraft(
      title: l10n.weeksOfCoachingWithMe(_weeksLabel(l10n, template)),
      description: l10n.twelveWeeksForARealChangeWith,
      durationDays: _days(template),
      includes: <String>[plan, sessions, weekly, l10n.aPlanThatChangesAsYouDo],
      liveSessionsPerMonth: _sessions(template),
      sessionMinutes: 45,
      checkInsPerWeek: 1,
      order: order,
    ),
    PackageTemplate.blank => PackageDraft(order: order),
  };
}
