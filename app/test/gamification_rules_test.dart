// Executable guards for the motivation design in DECISIONS D37–D41 and the
// guide's §15. Each rule is one a well-meaning change would break quietly:
// a streak line added to a reminder, confetti copied to a second screen, a
// "surprise bonus" with a random number behind it.
//
// Every scan has a positive control beside it, so a guard that has stopped
// matching anything fails loudly instead of passing for ever.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartUnder(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*');
}

/// Lines of [source] that are code and match [pattern].
List<String> _codeHits(String source, RegExp pattern) => [
  for (final line in source.split('\n'))
    if (!_isComment(line) && pattern.hasMatch(line)) line.trim(),
];

/// The files that may import the training streak (D37). A notification, a
/// reminder, a widget or the lock screen is never on it.
const Set<String> _streakImporters = <String>{
  'lib/app_state/training_streak_state.dart',
  'lib/app_state/rewards_state.dart',
  'lib/app_state/app_snapshot.dart',
  // Account deletion resets it, and only resets it.
  'lib/app_state/account_data.dart',
  'lib/app_state/workout_session_state.dart',
  'lib/routing/app_router.dart',
  'lib/features/train/domain/session_summary.dart',
  'lib/features/train/presentation/finished_view.dart',
  'lib/features/today/presentation/today_view.dart',
  'lib/features/today/presentation/today_cards.dart',
  'lib/features/today/presentation/streak_sheet.dart',
  'lib/features/progress/presentation/progress_view.dart',
  'lib/features/account/presentation/profile_view.dart',
  // The streak's switch, under "Reminders and extras" on A01.
  'lib/features/account/presentation/extras_rows.dart',
};

/// Never allowed to know the streak exists.
const List<String> _neverStreak = <String>[
  'lib/app_state/reminder_scheduler.dart',
  'lib/app_state/notification_sync.dart',
  'lib/app_state/notification_taps.dart',
  'lib/features/train/domain/notification_plan.dart',
  'lib/features/train/presentation/notification_explainer.dart',
  'lib/app_state/push_registration.dart',
  'lib/app_state/home_widget_sync.dart',
  'lib/app_state/widget_links.dart',
  'lib/features/today/presentation/lock_screen_nudge_view.dart',
  'lib/features/today/domain/widget_projection.dart',
  'lib/features/train/domain/training_reminders.dart',
];

bool _hasEmDash(String value) => value.contains('\u2014');

final RegExp _importsStreak = RegExp(
  r'''import\s+['"][^'"]*(training_streak|training_streak_state)\.dart['"]''',
);

void main() {
  test('D37: only the listed files import the training streak', () {
    final offenders = <String>[];
    for (final file in _dartUnder('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('domain/rewards/training_streak.dart')) continue;
      if (_importsStreak.hasMatch(file.readAsStringSync()) &&
          !_streakImporters.contains(path)) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'D37: the streak is shown on Home, P01, R10, its sheet, and its switch on A01 '
          'only. Add a file to the list only with a decision behind it.',
    );
  });

  test('D37: no notification, reminder or widget knows the streak', () {
    for (final path in _neverStreak) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      expect(
        _importsStreak.hasMatch(source),
        isFalse,
        reason: '$path must never carry the streak (D37)',
      );
      expect(
        _codeHits(source, RegExp('trainingStreak|TrainingStreak')),
        isEmpty,
        reason: '$path must never name the streak (D37)',
      );
    }
  });

  test('the streak import check finds an import', () {
    expect(
      _importsStreak.hasMatch(
        "import '../domain/rewards/training_streak.dart';",
      ),
      isTrue,
    );
    expect(
      _importsStreak.hasMatch("import '../app_state/rewards_state.dart';"),
      isFalse,
    );
  });

  test('D40: paper confetti is drawn on R10 and nowhere else', () {
    final offenders = <String>[];
    for (final file in _dartUnder('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('ui/hand/paper_confetti.dart')) continue;
      final hits = _codeHits(file.readAsStringSync(), RegExp(r'PaperConfetti'));
      if (hits.isEmpty) continue;
      if (path.endsWith('features/train/presentation/finished_view.dart') ||
          path.endsWith('features/train/presentation/finish_reveal.dart')) {
        continue;
      }
      offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'One celebration, on R10 (D40).');
  });

  test('D41: nothing about rewards is left to chance', () {
    const files = <String>[
      'lib/app_state/rewards_state.dart',
      'lib/app_state/training_streak_state.dart',
      'lib/domain/rewards/training_streak.dart',
      'lib/features/train/domain/own_best_challenge.dart',
      'lib/features/train/domain/session_summary.dart',
    ];
    final random = RegExp(r'\bRandom\s*\(|\bnextInt\s*\(|\bnextDouble\s*\(');
    for (final path in files) {
      expect(
        _codeHits(File(path).readAsStringSync(), random),
        isEmpty,
        reason: '$path: chance-based rewards were rejected (D41).',
      );
    }
    // The control: the pattern does catch a random call.
    expect(_codeHits('final n = Random().nextInt(5);', random), hasLength(1));
  });

  test('the new motivation files never call analytics', () {
    const files = <String>[
      'lib/app_state/rewards_state.dart',
      'lib/app_state/training_streak_state.dart',
      'lib/app_state/haptics.dart',
      'lib/domain/rewards/training_streak.dart',
      'lib/features/train/domain/own_best_challenge.dart',
      'lib/features/train/domain/session_summary.dart',
      'lib/features/train/domain/library_recommendation.dart',
      'lib/features/train/domain/rest_policy.dart',
      'lib/features/train/presentation/finish_reveal.dart',
      'lib/features/today/presentation/streak_sheet.dart',
      'lib/ui/hand/paper_confetti.dart',
      'lib/ui/app_preparation_steps.dart',
      'lib/domain/rewards/credit_outcome.dart',
      'lib/domain/week/week_calendar.dart',
    ];
    final analytics = RegExp(r'analytics|AnalyticsEvent|PostHog');
    for (final path in files) {
      expect(
        _codeHits(File(path).readAsStringSync(), analytics),
        isEmpty,
        reason: '$path must not send anything anywhere.',
      );
    }
  });

  test('the em-dash check finds an em dash', () {
    expect(_hasEmDash('Rest \u2014 then go'), isTrue);
    expect(_hasEmDash('Rest, then go'), isFalse);
  });

  test('no em dash in any product string, in either language', () {
    for (final path in const ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
      final arb =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final offenders = [
        for (final entry in arb.entries)
          if (!entry.key.startsWith('@') &&
              entry.value is String &&
              _hasEmDash(entry.value as String))
            entry.key,
      ];
      expect(offenders, isEmpty, reason: '$path: owner copy rule, no em dash');
    }
  });
}
