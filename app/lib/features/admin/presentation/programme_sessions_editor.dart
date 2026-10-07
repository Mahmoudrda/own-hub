/// Z13's sessions: what a programme actually asks her to do.
///
/// A programme row in the CSV is a shape (weeks, days, minutes). The sessions
/// are what Train runs, so they are built here, one move at a time, from the
/// exercise library: an exercise, its sets, reps or a hold, the rest between
/// sets, a note and a safety note in both languages. Each session says who it
/// is written for, and a woman is only ever offered a session written for her
/// life stage (`workout_library.dart`).
///
/// The numbers are checked here, beside the field. Everything else the member
/// app holds a programme to is checked by the repository with the member app's
/// own function before anything is written.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../../train/domain/workout_library.dart';
import 'admin_widgets.dart';

final RegExp _whole = RegExp(r'^\d+$');

class MoveDraft {
  MoveDraft([AuthoredMove? move])
    : exerciseId = move?.exerciseId,
      sets = TextEditingController(text: '${move?.sets ?? 3}'),
      reps = TextEditingController(text: move?.reps?.toString() ?? ''),
      hold = TextEditingController(text: move?.holdSeconds?.toString() ?? ''),
      rest = TextEditingController(text: '${move?.restSeconds ?? 60}'),
      notesEn = TextEditingController(text: move?.notesEn ?? ''),
      notesAr = TextEditingController(text: move?.notesAr ?? ''),
      safetyEn = TextEditingController(text: move?.safetyEn ?? ''),
      safetyAr = TextEditingController(text: move?.safetyAr ?? '');

  String? exerciseId;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController hold;
  final TextEditingController rest;
  final TextEditingController notesEn;
  final TextEditingController notesAr;
  final TextEditingController safetyEn;
  final TextEditingController safetyAr;

  List<TextEditingController> get _all => [
    sets,
    reps,
    hold,
    rest,
    notesEn,
    notesAr,
    safetyEn,
    safetyAr,
  ];

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

class SessionDraft {
  SessionDraft(this.sessionId, [AuthoredSession? session])
    : titleEn = TextEditingController(text: session?.titleEn ?? ''),
      titleAr = TextEditingController(text: session?.titleAr ?? ''),
      minutes = TextEditingController(text: '${session?.minutes ?? 20}'),
      stages = {
        ...(session?.lifeStages ?? {LifeStage.none}),
      },
      moves = [
        for (final m in session?.moves ?? const <AuthoredMove>[]) MoveDraft(m),
      ];

  final String sessionId;
  final TextEditingController titleEn;
  final TextEditingController titleAr;
  final TextEditingController minutes;
  final Set<LifeStage> stages;
  final List<MoveDraft> moves;

  void dispose() {
    titleEn.dispose();
    titleAr.dispose();
    minutes.dispose();
    for (final m in moves) {
      m.dispose();
    }
  }
}

/// The sessions being edited, and their field errors.
class ProgrammeSessionsController {
  ProgrammeSessionsController(List<AuthoredSession> initial)
    : sessions = [for (final s in initial) SessionDraft(s.sessionId, s)];

  final List<SessionDraft> sessions;

  /// By `session/move/field`, for the number fields.
  Map<String, String> errors = const {};

  String nextSessionId() {
    var n = sessions.length + 1;
    while (sessions.any((s) => s.sessionId == 's$n')) {
      n++;
    }
    return 's$n';
  }

  /// Checks the numbers. True when every one is a whole number where one is
  /// needed and each move has exactly one of reps and a hold.
  bool validate(AppL10n l10n) {
    final out = <String, String>{};
    for (var si = 0; si < sessions.length; si++) {
      final s = sessions[si];
      if (!_whole.hasMatch(s.minutes.text.trim())) {
        out['$si/minutes'] = l10n.checkTheNumberAndTryAgain;
      }
      for (var mi = 0; mi < s.moves.length; mi++) {
        final m = s.moves[mi];
        final key = '$si/$mi';
        if (m.exerciseId == null) out['$key/exercise'] = l10n.requiredLabel;
        for (final (field, c, required) in [
          ('sets', m.sets, true),
          ('rest', m.rest, true),
          ('reps', m.reps, false),
          ('hold', m.hold, false),
        ]) {
          final v = c.text.trim();
          if ((required || v.isNotEmpty) && !_whole.hasMatch(v)) {
            out['$key/$field'] = l10n.checkTheNumberAndTryAgain;
          }
        }
        final hasReps = m.reps.text.trim().isNotEmpty;
        final hasHold = m.hold.text.trim().isNotEmpty;
        if (hasReps == hasHold) out['$key/reps'] = l10n.repsOrAHoldNotBoth;
      }
    }
    errors = out;
    return out.isEmpty;
  }

  /// The sessions as written. Names are filled from the exercise library when
  /// the programme is saved.
  List<AuthoredSession> build() => [
    for (final s in sessions)
      AuthoredSession(
        sessionId: s.sessionId,
        titleEn: s.titleEn.text.trim(),
        titleAr: s.titleAr.text.trim(),
        minutes: int.tryParse(s.minutes.text.trim()) ?? 0,
        lifeStages: {...s.stages},
        moves: [
          for (final m in s.moves)
            AuthoredMove(
              exerciseId: m.exerciseId ?? '',
              nameEn: '',
              nameAr: '',
              sets: int.tryParse(m.sets.text.trim()) ?? 0,
              reps: int.tryParse(m.reps.text.trim()),
              holdSeconds: int.tryParse(m.hold.text.trim()),
              restSeconds: int.tryParse(m.rest.text.trim()) ?? 0,
              notesEn: m.notesEn.text.trim(),
              notesAr: m.notesAr.text.trim(),
              safetyEn: m.safetyEn.text.trim(),
              safetyAr: m.safetyAr.text.trim(),
            ),
        ],
      ),
  ];

  void dispose() {
    for (final s in sessions) {
      s.dispose();
    }
  }
}

class ProgrammeSessionsEditor extends StatefulWidget {
  const ProgrammeSessionsEditor({
    super.key,
    required this.controller,
    required this.exercises,
  });

  final ProgrammeSessionsController controller;

  /// The exercise library, as `(id, name)`.
  final List<(String, String)> exercises;

  @override
  State<ProgrammeSessionsEditor> createState() =>
      _ProgrammeSessionsEditorState();
}

class _ProgrammeSessionsEditorState extends State<ProgrammeSessionsEditor> {
  ProgrammeSessionsController get _c => widget.controller;

  String _error(String key) => _c.errors[key] ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHead(l10n.sessions),
        const SizedBox(height: 8),
        for (var si = 0; si < _c.sessions.length; si++) ...[
          _session(l10n, si),
          const SizedBox(height: 12),
        ],
        AppButton(
          l10n.addASession,
          icon: Icons.add,
          variant: AppButtonVariant.outlined,
          onPressed: () =>
              setState(() => _c.sessions.add(SessionDraft(_c.nextSessionId()))),
        ),
      ],
    );
  }

  Widget _session(AppL10n l10n, int si) {
    final s = _c.sessions[si];
    final stages = [
      (LifeStage.none, l10n.nothingRightNow),
      (LifeStage.postpartum, l10n.afterABirth),
      (LifeStage.pregnant, l10n.pregnant),
      (LifeStage.painInjury, l10n.aKneeBackOrShoulder),
    ];
    return AppCard(
      variant: AppCardVariant.filled,
      children: [
        AppField(
          controller: s.titleEn,
          label: l10n.sessionTitleEnglish,
          textDirection: TextDirection.ltr,
        ),
        AppField(
          controller: s.titleAr,
          label: l10n.sessionTitleArabic,
          textDirection: TextDirection.rtl,
        ),
        AppField(
          controller: s.minutes,
          label: l10n.minutes,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          errorText: _error('$si/minutes'),
        ),
        Text(l10n.whoItIsWrittenFor, style: AppText.label),
        AppChipRow(
          grow: false,
          items: [for (final (_, label) in stages) label],
          selected: {
            for (var i = 0; i < stages.length; i++)
              if (s.stages.contains(stages[i].$1)) i,
          },
          onTap: (i) => setState(() {
            final stage = stages[i].$1;
            if (!s.stages.remove(stage)) s.stages.add(stage);
          }),
        ),
        for (var mi = 0; mi < s.moves.length; mi++) _move(l10n, si, mi),
        if (widget.exercises.isEmpty)
          Text(
            l10n.addExercisesToTheLibraryFirst,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          )
        else
          AppButton(
            l10n.addAMove,
            icon: Icons.add,
            variant: AppButtonVariant.tonal,
            onPressed: () => setState(() => s.moves.add(MoveDraft())),
          ),
        AppButton(
          l10n.remove,
          variant: AppButtonVariant.text,
          onPressed: () => setState(() => _c.sessions.removeAt(si).dispose()),
        ),
      ],
    );
  }

  Widget _move(AppL10n l10n, int si, int mi) {
    final m = _c.sessions[si].moves[mi];
    final key = '$si/$mi';
    final ids = [for (final e in widget.exercises) e.$1];
    Widget number(TextEditingController c, String label, String field) =>
        AppField(
          controller: c,
          label: label,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          errorText: _error('$key/$field'),
        );
    return AppCard(
      children: [
        Text(l10n.exercise, style: AppText.label),
        DropdownButton<String>(
          isExpanded: true,
          value: ids.contains(m.exerciseId) ? m.exerciseId : null,
          hint: Text(l10n.exercise),
          items: [
            for (final (id, name) in widget.exercises)
              DropdownMenuItem(value: id, child: Text(name)),
          ],
          onChanged: (id) => setState(() => m.exerciseId = id),
        ),
        if (_error('$key/exercise').isNotEmpty)
          Text(
            _error('$key/exercise'),
            style: AppText.bodyM.copyWith(color: AppColors.error),
          ),
        number(m.sets, l10n.sets, 'sets'),
        number(m.reps, l10n.reps, 'reps'),
        number(m.hold, l10n.holdSeconds, 'hold'),
        number(m.rest, l10n.restSeconds, 'rest'),
        AppField(
          controller: m.notesEn,
          label: l10n.notesEnglish,
          textDirection: TextDirection.ltr,
          maxLines: null,
        ),
        AppField(
          controller: m.notesAr,
          label: l10n.notesArabic,
          textDirection: TextDirection.rtl,
          maxLines: null,
        ),
        AppField(
          controller: m.safetyEn,
          label: l10n.safetyNoteEnglish,
          textDirection: TextDirection.ltr,
          maxLines: null,
        ),
        AppField(
          controller: m.safetyAr,
          label: l10n.safetyNoteArabic,
          textDirection: TextDirection.rtl,
          maxLines: null,
        ),
        AppButton(
          l10n.remove,
          variant: AppButtonVariant.text,
          onPressed: () =>
              setState(() => _c.sessions[si].moves.removeAt(mi).dispose()),
        ),
      ],
    );
  }
}
