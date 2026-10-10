/// What the Home Screen and Lock Screen widgets are allowed to know.
///
/// The widgets run in a separate iOS process (`ios/OwnHubWidgets`) that reads
/// one JSON string out of the App Group the app shares with it. This file is
/// the only thing that writes that string, so it is where the privacy promise
/// is kept: **the payload is built from an allow-list, field by field**, and a
/// field that is not named in [kWidgetPayloadKeys] cannot reach the widget.
///
/// ## What it carries
///
/// This week's session count against her target, the state of today, and
/// whether a meal is logged today. Plus the sentences the widget shows, already
/// in the language she chose in the app, because that can differ from the
/// phone's own language and the widget has no other way to know it.
///
/// ## What it cannot carry
///
/// Her cycle, her life stage, her weight, her measurements, her allergies, her
/// kcal, and the title of her programme or session. Not hidden by the widget:
/// absent from the input. [WidgetProjection.build] takes a [TodayDay], which has
/// no field for any of them, and `widget_privacy_guard_test.dart` proves by
/// parsing this file that it imports nothing that does. A Lock Screen widget is
/// readable by anyone holding the phone, and redaction settings are hers to
/// change, so the only safe payload is one that has nothing to redact.
///
/// ## Weeks, not days
///
/// §2 rule 3 holds here as everywhere: the count is this week's, the day
/// carries a state and never a tally, and nothing is ever "missed".
library;

import '../../../domain/format/day_key.dart';
import '../../../domain/week/week_key.dart';
import '../../../l10n/app_l10n.dart';
import 'today_day.dart';

/// The App Group key the widget reads. Versioned, so a later shape is a new
/// key the old extension simply does not find, and it shows the closed state.
const String kWidgetPayloadKey = 'ownhub.widget.v1';

/// Every top-level key the payload may hold.
const Set<String> kWidgetPayloadKeys = {
  'v',
  'state',
  'lang',
  'dayKey',
  'weekId',
  'done',
  'target',
  'today',
  'meal',
  's',
};

/// Every sentence the payload may hold, under `s`.
const Set<String> kWidgetStringKeys = {
  'title',
  'today',
  'week',
  'weekFresh',
  'inline',
  'inlineFresh',
  'a11y',
  'a11yFresh',
  'status',
  'meal',
  'mealNone',
  'stale',
  'closed',
};

/// Builds the widget payload. Holds nothing.
class WidgetProjection {
  const WidgetProjection._();

  /// The payload for [day], or the closed one when [open] is false.
  ///
  /// [open] is false whenever she is signed out or not verified. The closed
  /// payload says "Open Own Hub to start" and nothing else: no number, and no
  /// hint of where her check stands.
  ///
  /// `dayKey` and `weekId` are the day the data is for, which the widget
  /// compares with its own clock: past midnight it stops claiming today's
  /// state, and past Monday it shows the new week at zero. `weekFresh`,
  /// `inlineFresh` and `a11yFresh` are those zero sentences, ready in her
  /// language.
  static Map<String, Object?> build({
    required TodayDay day,
    required bool open,
    required AppL10n l10n,
    required String lang,
    required DateTime now,
  }) {
    if (!open) return closed(l10n: l10n, lang: lang);
    final done = day.week.sessionsLogged < 0 ? 0 : day.week.sessionsLogged;
    final target = day.week.sessionsTarget < 1 ? 1 : day.week.sessionsTarget;
    final forDay = dayKey(day.date);
    final meal =
        day.mealLoggedAt != null && dayKey(day.mealLoggedAt!) == forDay;
    // Data from an earlier day says nothing about today, so it is not
    // presented as today's state even before the widget's clock notices.
    final current = forDay == dayKey(now);
    return {
      'v': 1,
      'state': 'open',
      'lang': lang,
      'dayKey': forDay,
      'weekId': WeekKey.of(day.date).id,
      'done': done,
      'target': target,
      'today': current ? day.state.name : 'stale',
      'meal': current && meal,
      's': {
        'title': l10n.thisWeek,
        'today': l10n.today,
        'week': l10n.thisWeekDoneOfTarget(done, target),
        'weekFresh': l10n.thisWeekDoneOfTarget(0, target),
        'inline': l10n.doneOfTargetThisWeek(done, target),
        'inlineFresh': l10n.doneOfTargetThisWeek(0, target),
        'a11y': l10n.sessionsThisWeekDoneOfTarget(done, target),
        'a11yFresh': l10n.sessionsThisWeekDoneOfTarget(0, target),
        'status': current
            ? statusFor(day.state, l10n)
            : l10n.openOwnHubForToday,
        'meal': l10n.youAddedAMealToday,
        'mealNone': l10n.addWhatIAte,
        'stale': l10n.openOwnHubForToday,
        'closed': l10n.openOwnHubToStart,
      },
    };
  }

  /// Signed out, not verified, waiting on a reviewer, or after a deletion.
  static Map<String, Object?> closed({
    required AppL10n l10n,
    required String lang,
  }) => {
    'v': 1,
    'state': 'closed',
    'lang': lang,
    's': {'closed': l10n.openOwnHubToStart},
  };

  /// The one line about today. Generic on purpose: a programme title can name
  /// a life stage ("Postpartum rebuild"), so the widget never shows one.
  static String statusFor(DayState state, AppL10n l10n) => switch (state) {
    DayState.dayOne => l10n.yourFirstSessionIsReady,
    DayState.nothingDone => l10n.todaysWorkoutIsReady,
    DayState.inProgress => l10n.todayIsUnderWay,
    DayState.done => l10n.sessionDone,
    DayState.recalled => l10n.sessionSaved,
    DayState.restDay => l10n.restDay,
  };
}
