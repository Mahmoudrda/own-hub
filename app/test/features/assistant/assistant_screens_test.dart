// The five screens: P0-ASK-01 (X01), P0-ASK-03 (X01/R05), P0-ASK-07 (X01
// offline), P0-ASK-10's K27 half, P0-ASK-11 (K26/K27), and X03.
//
// The service tests prove the ORDER of the gates. These prove what actually
// reaches a woman's screen afterwards, which is a different failure: a payload
// can be perfectly validated and still be rendered with a figure nobody
// authored, a swap control that implies more than it does, or a draft that
// looks published.
//
// Two idioms are inherited from the rest of the suite and used throughout:
//
//   * fixture ids and names are deliberately unlike the seeded library's, so a
//     test cannot pass by accidentally reading real content; and
//   * where the claim is "no field exists that could do X", the test scans the
//     SOURCE, because an instance test can only prove that the one object built
//     here does not — and absence is a property of the type.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/assistant/domain/assistant_pack.dart';
import 'package:own_hub/features/assistant/domain/assistant_provider.dart';
import 'package:own_hub/features/assistant/domain/assistant_quota.dart';
import 'package:own_hub/features/assistant/domain/assistant_service.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/assistant/domain/safety_classifier.dart';
import 'package:own_hub/features/assistant/presentation/assistant_boundaries.dart';
import 'package:own_hub/features/assistant/presentation/assistant_copy.dart';
import 'package:own_hub/features/assistant/presentation/assistant_templates.dart';
import 'package:own_hub/features/assistant/presentation/ask_view_model.dart';
import 'package:own_hub/features/assistant/presentation/draft_view_model.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';

final AppL10n _l10n = AppL10nEn();

/// Two moves with authored prescriptions, one without — so a row that renders
/// no detail line can be told apart from one that renders the wrong figure.
final AssistantPack _pack = AssistantPack(
  version: 'fx-pack-4406',
  exercises: const [
    AssistantExercise(
      exerciseId: 'fx_4406_bridge',
      name: 'fixture bridge',
      tags: {ContraindicationTag.supineLoad},
      quiet: true,
      floorOnly: true,
      prescriptionLabel: 'fixture detail bridge',
    ),
    AssistantExercise(
      exerciseId: 'fx_4406_box_squat',
      name: 'fixture box squat',
      tags: {ContraindicationTag.none},
      quiet: true,
      floorOnly: false,
      prescriptionLabel: 'fixture detail box squat',
    ),
    AssistantExercise(
      exerciseId: 'fx_4406_squat',
      name: 'fixture squat',
      tags: {ContraindicationTag.deepKneeFlexion},
      quiet: true,
      floorOnly: false,
    ),
  ],
  foods: const FoodLibrary(<Food>[
    Food(
      foodId: 'fx_4406_lentils',
      names: ['fixture lentils'],
      allergens: <String>{},
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 193, proteinG: 17)],
    ),
    Food(
      foodId: 'fx_4406_unverified',
      names: ['fixture unverified dish'],
      allergens: <String>{},
      verified: false,
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 404, proteinG: 13)],
    ),
  ]),
);

/// `path:line` for every non-comment line matching [pattern].
List<String> _hits(String path, RegExp pattern) {
  final out = <String>[];
  final lines = File(path).readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('///') ||
        trimmed.startsWith('*')) {
      continue;
    }
    if (pattern.hasMatch(lines[i])) out.add('${i + 1}  ${lines[i].trim()}');
  }
  return out;
}

const String _askViewModel =
    'lib/features/assistant/presentation/ask_view_model.dart';
const String _draftViewModel =
    'lib/features/assistant/presentation/draft_view_model.dart';
const String _wire = 'lib/features/assistant/domain/assistant_wire.dart';

AssistantAnswer _twoAlternatives({String? swapFrom}) => AssistantAnswer(
  answerKey: AnswerKey.groundedAlternatives,
  swapFromExerciseId: swapFrom,
  picks: const [
    AssistantPick(
      kind: PickKind.exercise,
      id: 'fx_4406_bridge',
      source: PickSource.herPlan,
    ),
    AssistantPick(
      kind: PickKind.exercise,
      id: 'fx_4406_box_squat',
      source: PickSource.moveLibrary,
    ),
  ],
);

void main() {
  final view = AskViewModel(_pack);

  group('P0-ASK-01 — X01 — a grounded answer with its source', () {
    test('every move id exists in the pack, and each row carries its source', () {
      final screen = view.from(AssistantAnswered(_twoAlternatives()));

      expect(screen.state, AskState.answered);
      expect(screen.rows, hasLength(2));
      for (final row in screen.rows) {
        expect(
          _pack.exerciseById(row.exerciseId),
          isNotNull,
          reason: 'a rendered row must resolve to a real pack row',
        );
      }
      // "An assistant that cannot show its source is indistinguishable from one
      // that guessed." Her plan for the first, the library for the second.
      expect(
        [for (final row in screen.rows) row.source],
        [PickSource.herPlan, PickSource.moveLibrary],
      );
    });

    test(
      'the name and the detail are read from the pack, not from the answer',
      () {
        final screen = view.from(AssistantAnswered(_twoAlternatives()));

        expect(screen.rows.first.name, 'fixture bridge');
        expect(screen.rows.first.detail, 'fixture detail bridge');
        // And the answer could not have supplied either: a pick is an id and a
        // provenance. Nothing on it spells a name, a set or a rep.
        const pick = AssistantPick(
          kind: PickKind.exercise,
          id: 'fx_4406_bridge',
          source: PickSource.herPlan,
        );
        expect(pick.toString(), isNot(contains('fixture')));
      },
    );

    test('a move with no authored prescription renders no detail line', () {
      // Null means the dictionary has no phrase for this move — never "3 × 10".
      final screen = view.from(
        AssistantAnswered(
          const AssistantAnswer(
            answerKey: AnswerKey.groundedAlternatives,
            picks: [
              AssistantPick(
                kind: PickKind.exercise,
                id: 'fx_4406_squat',
                source: PickSource.moveLibrary,
              ),
            ],
          ),
        ),
      );
      expect(screen.rows.single.detail, isNull);
    });

    test('the sentence is a dictionary template, chosen by key', () {
      final screen = view.from(AssistantAnswered(_twoAlternatives()));
      expect(screen.answerKey, AnswerKey.groundedAlternatives);

      final line = assistantAnswerTemplate(
        _l10n,
        screen.answerKey!,
        rowCount: screen.rows.length,
      );
      expect(line, _l10n.twoMovesInYourSessionWorkThe);
    });

    test('a template that states a count is withheld when it is not hers', () {
      // `stated_figure.dart`'s rule. "Two moves…" to a woman looking at one
      // move is the defect `baked_in_samples_test.dart` counts, in the one
      // place a selection still composes a sentence.
      final line = assistantAnswerTemplate(
        _l10n,
        AnswerKey.groundedAlternatives,
        rowCount: 1,
      );
      expect(line, isNull, reason: 'say less rather than something untrue');
    });

    test('the recorded gap matches what actually resolves', () {
      // `kAnswerKeysWithNoDictionaryLine` is the live list, and this test is
      // what keeps it honest. It is empty now that
      // `nothingFoundForThatIWouldRather` has been minted; it was not, and the
      // next withheld key goes back in it.
      for (final key in AnswerKey.values) {
        final line = assistantAnswerTemplate(_l10n, key, rowCount: 2);
        expect(
          line == null,
          kAnswerKeysWithNoDictionaryLine.contains(key),
          reason:
              '${key.name}: the set of keys with no dictionary line must match '
              'what actually resolves to null',
        );
      }
    });

    test('nothing found says so, in the dictionary\'s words', () {
      expect(
        assistantAnswerTemplate(_l10n, AnswerKey.nothingFound, rowCount: 0),
        _l10n.nothingFoundForThatIWouldRather,
      );
    });
  });

  group('the two routes are told two different things', () {
    test('offline names the act she cannot do, and promises nothing', () {
      expect(
        assistantUnavailableLine(_l10n, AssistantUnavailableReason.offline),
        _l10n.askingNeedsAConnection,
        reason: 'X01 is the asking route, and that is its default',
      );
      expect(
        assistantUnavailableLine(
          _l10n,
          AssistantUnavailableReason.offline,
          route: QuotaRoute.draft,
        ),
        _l10n.draftingNeedsAConnection,
        reason: 'K26/K27 is a coach drafting, not a woman asking',
      );
    });

    test('neither line is one of the four that promise a queue', () {
      final promised = <String>{
        _l10n.youAreOfflineEverythingYouAddIs,
        _l10n.waitingForSignal,
        _l10n.savedHereUntilYouHaveSignal,
        _l10n.weCouldNotReachTheServerYour,
      };
      for (final route in QuotaRoute.values) {
        expect(
          promised.contains(
            assistantUnavailableLine(
              _l10n,
              AssistantUnavailableReason.offline,
              route: route,
            ),
          ),
          isFalse,
          reason: '${route.name}: this feature queues nothing',
        );
      }
    });

    test('the kill switch is still silent, on both routes', () {
      // It is not a signal problem, so the offline sentence is not borrowed
      // for it. `kUnavailableReasonsWithNoDictionaryLine` is the live record.
      for (final route in QuotaRoute.values) {
        expect(
          assistantUnavailableLine(
            _l10n,
            AssistantUnavailableReason.switchedOff,
            route: route,
          ),
          isNull,
        );
      }
      expect(
        kUnavailableReasonsWithNoDictionaryLine,
        <AssistantUnavailableReason>{AssistantUnavailableReason.switchedOff},
      );
    });

    test('the recorded gap matches what actually resolves', () {
      for (final reason in AssistantUnavailableReason.values) {
        for (final route in QuotaRoute.values) {
          expect(
            assistantUnavailableLine(_l10n, reason, route: route) == null,
            kUnavailableReasonsWithNoDictionaryLine.contains(reason),
            reason:
                '${reason.name}/${route.name}: the set of reasons with no '
                'dictionary line must match what actually resolves to null',
          );
        }
      }
    });

    test('the daily cap has a sentence, and it states no figure', () {
      expect(
        assistantCappedLine(_l10n),
        _l10n.youHaveUsedTodaysQuestionsThereWill,
      );
      expect(RegExp(r'\d').hasMatch(assistantCappedLine(_l10n)), isFalse);
    });
  });

  group('P0-ASK-02 — X01 — no move is described, named or approximated', () {
    test('nothing found renders zero rows and names nothing', () {
      final screen = view.from(
        const AssistantAnswered(AssistantAnswer.nothingFound),
      );
      expect(screen.state, AskState.nothingFound);
      expect(screen.rows, isEmpty);
      expect(screen.answerKey, AnswerKey.nothingFound);
      expect(screen.askSaraEnabled, isTrue);
    });

    test('an answer whose picks all failed to resolve is nothing found', () {
      final screen = view.from(
        AssistantAnswered(
          const AssistantAnswer(
            answerKey: AnswerKey.groundedAlternatives,
            picks: [
              AssistantPick(
                kind: PickKind.exercise,
                id: 'fx_4406_invented',
                source: PickSource.moveLibrary,
              ),
            ],
          ),
        ),
      );
      // Not "a grounded answer with no moves" — that shape does not exist here.
      expect(screen.state, AskState.nothingFound);
      expect(screen.rows, isEmpty);
    });
  });

  group('P0-ASK-03 — X01/R05 — a swap changes today only', () {
    test('each row proposes a swap away from the move in today\'s session', () {
      final screen = view.from(
        AssistantAnswered(_twoAlternatives(swapFrom: 'fx_4406_squat')),
      );

      expect(screen.swaps, hasLength(2));
      for (final proposal in screen.swaps) {
        expect(proposal.fromExerciseId, 'fx_4406_squat');
        expect(proposal.reasonKey, AnswerKey.swapChangesTodayOnly);
      }
      expect(
        [for (final s in screen.swaps) s.toExerciseId],
        ['fx_4406_bridge', 'fx_4406_box_squat'],
      );
    });

    test('there is no control at all when nothing is being replaced', () {
      final screen = view.from(AssistantAnswered(_twoAlternatives()));
      expect(screen.swaps, isEmpty);
      expect(screen.rows.every((r) => r.canSwap), isFalse);
    });

    test('a swap cannot express a scope wider than the session', () {
      // The guarantee is the ABSENCE of a field. A date, a weekday, a repeat
      // flag or a plan version would each be a way to reach past today, and the
      // copy "swapping changes today only" would then be a promise rather than
      // a fact about the type.
      final source = File(_wire).readAsStringSync();
      final swapClass = RegExp(r'class SwapProposal \{[\s\S]*?\n\}')
          .firstMatch(source);
      expect(swapClass, isNotNull, reason: 'SwapProposal must exist');

      final declarations = <String>[
        for (final line in swapClass!.group(0)!.split('\n'))
          if (!line.trimLeft().startsWith('//') &&
              !line.trimLeft().startsWith('///') &&
              RegExp(r'^\s*final\s').hasMatch(line))
            line.trim(),
      ];
      expect(declarations, hasLength(3));
      for (final declaration in declarations) {
        expect(
          RegExp(
            r'date|day|week|until|repeat|recurr|every|version|published',
            caseSensitive: false,
          ).hasMatch(declaration),
          isFalse,
          reason: 'a swap must not be able to reach past today: $declaration',
        );
      }
    });

    test('the screen it renders on never claims to have changed a plan', () {
      for (final screen in <AskScreen>[
        view.idle(),
        view.from(
          AssistantAnswered(_twoAlternatives(swapFrom: 'fx_4406_squat')),
        ),
        view.from(const AssistantRefusal(RefusalCategory.medicalDiagnostic)),
        view.from(
          const AssistantUnavailable(AssistantUnavailableReason.offline),
        ),
      ]) {
        expect(screen.planUntouched, isTrue);
      }
    });

    test('accepting is somebody else\'s job: this layer has no apply', () {
      // G15 §7.1's named resolution of the conflict with HANDOFF — the tools
      // propose, G4's SwapService writes. A method here that applied one would
      // be the second writer for `users/{uid}/sessions/*`.
      expect(
        _hits(
          _askViewModel,
          RegExp(
            r'\b(apply|commit|save|send|write)\w*\s*\(',
            caseSensitive: false,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('P0-ASK-07 — X01 — no signal', () {
    test('the composer is disabled and Ask Sara is not', () {
      final screen = view.idle(online: false);
      expect(screen.state, AskState.unavailable);
      expect(screen.reason, AssistantUnavailableReason.offline);
      expect(screen.composerEnabled, isFalse);
      // The inversion G15 §4 calls the honest one: the human path works on a
      // microbus and the machine path does not.
      expect(screen.askSaraEnabled, isTrue);
    });

    test('Ask Sara is enabled on every state without exception', () {
      final screens = <AskScreen>[
        view.idle(),
        view.idle(online: false),
        view.from(AssistantAnswered(_twoAlternatives())),
        view.from(const AssistantAnswered(AssistantAnswer.nothingFound)),
        view.from(const AssistantRefusal(RefusalCategory.emergency)),
        view.from(const AssistantCapped(QuotaRoute.question)),
        for (final reason in AssistantUnavailableReason.values)
          view.from(AssistantUnavailable(reason)),
      ];
      expect(screens.every((s) => s.askSaraEnabled), isTrue);
    });

    test('nothing is queued and nothing is retried', () {
      // "No spinner, no queued question, nothing retried on reconnect." A
      // question she may no longer be asking is not resent for her.
      expect(
        _hits(
          _askViewModel,
          RegExp(
            r'\b(queue|pending|retry|resend|outbox)\w*',
            caseSensitive: false,
          ),
        ),
        isEmpty,
      );
    });

    test('the capped state disables the composer and keeps the human path', () {
      final screen = view.from(const AssistantCapped(QuotaRoute.question));
      expect(screen.state, AskState.capped);
      expect(screen.composerEnabled, isFalse);
      expect(screen.askSaraEnabled, isTrue);
    });
  });

  group('P0-ASK-05 — X02 — the route to care leads on an emergency', () {
    test('an emergency promotes care above the refusal', () {
      final screen = view.from(
        const AssistantRefusal(RefusalCategory.emergency),
      );
      expect(screen.state, AskState.refused);
      expect(screen.promotesCare, isTrue);
    });

    test('no suggestion is rendered on any refusal', () {
      for (final category in RefusalCategory.values) {
        final screen = view.from(AssistantRefusal(category));
        expect(screen.rows, isEmpty, reason: '${category.name} showed a move');
        expect(screen.answerKey, isNull);
      }
    });
  });

  group('P0-ASK-10 — K27 — an unverified dish carries no totals', () {
    final drafts = DraftViewModel(_pack, l10n: _l10n);

    const draft = MealDraft(
      days: [
        MealDraftDay(
          slots: {
            MealSlot.lunch: ['fx_4406_lentils'],
            MealSlot.dinner: ['fx_4406_unverified'],
          },
        ),
      ],
    );

    test('a verified dish renders the pack row through the parameterised form', () {
      final screen = drafts.meal(draft);
      final lunch = screen.days.single.slots
          .firstWhere((s) => s.slot == MealSlot.lunch)
          .dishes
          .single;

      expect(lunch.verified, isTrue);
      expect(lunch.hasTotals, isTrue);
      // The figures are the pack row's, and the sentence is the dictionary's
      // placeholder form filled with them — never a fixed string with a number
      // baked in.
      expect(lunch.kcal, 193);
      expect(lunch.proteinG, 17);
      expect(lunch.totals, _l10n.kcalKcalProteinGProtein('193', '17'));
      expect(lunch.totals, contains('193'));
      expect(lunch.totals, contains('17'));
    });

    test('an unverified dish has no figure and no line to render', () {
      final screen = drafts.meal(draft);
      final dinner = screen.days.single.slots
          .firstWhere((s) => s.slot == MealSlot.dinner)
          .dishes
          .single;

      expect(dinner.verified, isFalse);
      expect(dinner.kcal, isNull);
      expect(dinner.proteinG, isNull);
      expect(dinner.totals, isNull);
      expect(dinner.hasTotals, isFalse);
      // It is offered — the dish is on the screen — just without totals.
      expect(dinner.name, 'fixture unverified dish');
    });

    test('no total is computed anywhere, by the model or on its behalf', () {
      // P0-ASK-10 is explicit that "no total is ever computed by the model".
      // Nothing sums across dishes here either: a day total would be a figure
      // the food library never stated.
      expect(
        _hits(
          _draftViewModel,
          RegExp(r'\b(fold|reduce|sum|total\w*\s*\+|\+=)'),
        ),
        isEmpty,
      );
    });

    test('a dish the pack does not know contributes no row at all', () {
      final screen = drafts.meal(
        const MealDraft(
          days: [
            MealDraftDay(
              slots: {
                MealSlot.breakfast: ['fx_4406_invented'],
              },
            ),
          ],
        ),
      );
      expect(screen.days.single.slots, isEmpty);
    });
  });

  group('P0-ASK-11 — K26/K27 — a draft is a draft', () {
    final drafts = DraftViewModel(_pack, l10n: _l10n);

    test(
      'the plan draft is held, and counts itself from its own structure',
      () {
        final screen = drafts.plan(
          const PlanDraft(
            days: [
              PlanDraftDay(
                kind: PlanDayKind.training,
                exerciseIds: ['fx_4406_bridge'],
              ),
              PlanDraftDay(kind: PlanDayKind.rest),
              PlanDraftDay(
                kind: PlanDayKind.training,
                exerciseIds: ['fx_4406_box_squat'],
              ),
            ],
          ),
        );

        expect(screen.isHeldNotPublished, isTrue);
        expect(screen.dayCount, 3);
        expect(screen.sessionCount, 2);
        expect(screen.restCount, 1);
        expect(screen.days[1].isRest, isTrue);
        expect(screen.days.first.moves, ['fixture bridge']);
      },
    );

    test('the meal draft is held too', () {
      expect(MealDraftScreen.empty.isHeldNotPublished, isTrue);
      expect(PlanDraftScreen.empty.isHeldNotPublished, isTrue);
    });

    test('neither screen has a status, a publish or a write of any kind', () {
      // There is no transition out of `held` that reaches PUBLISHED. That
      // transition belongs to G2's PlanPublisher and is reachable only from a
      // coach's explicit publish tap on her own planner — not from here, and
      // not from anything this file can express.
      expect(
        _hits(
          _draftViewModel,
          RegExp(
            r'\b(publish\w*|status|PUBLISHED)\s*[(=;]',
            caseSensitive: false,
          ),
        ),
        isEmpty,
      );
      // And nothing here is even asynchronous: a read of a local pack cannot
      // await a network, so there is no shape for a write to hide in.
      expect(
        _hits(_draftViewModel, RegExp(r'\b(Future|async|await)\b')),
        isEmpty,
      );
    });

    test('an unknown move leaves an empty day rather than a shorter plan', () {
      final screen = drafts.plan(
        const PlanDraft(
          days: [
            PlanDraftDay(
              kind: PlanDayKind.training,
              exerciseIds: ['fx_4406_invented'],
            ),
          ],
        ),
      );
      // Dropping the day would silently shorten a 30-day plan and nobody would
      // see it happen.
      expect(screen.dayCount, 1);
      expect(screen.days.single.moves, isEmpty);
    });
  });

  group('X03 — what it can and cannot do', () {
    final boundaries = assistantBoundaries(_l10n);

    test('both lists are complete and come from the dictionary', () {
      expect(boundaries.can.keys, AssistantAbility.values);
      expect(boundaries.cannot.keys, AssistantLimit.values);
      expect(
        boundaries.cannot[AssistantLimit.diagnose],
        _l10n.diagnoseAnythingOrAnswerAMedicalQuestion,
      );
      expect(
        boundaries.can[AssistantAbility.findAMove],
        _l10n.findAMoveForYourEquipmentAnd,
      );
    });

    test('the cannot list is not the shorter one', () {
      // The opposite of how a feature like this is usually sold, and the reason
      // the screen is worth having.
      expect(boundaries.cannotListIsNotShorter, isTrue);
    });

    test('it needs no network and survives the kill switch', () {
      // G15 §2.4's `off` rung: X01's entry point is replaced by Ask Sara, and
      // the honest description of the feature stays readable.
      expect(boundaries.needsNetwork, isFalse);
      expect(boundaries.readableWhenSwitchedOff, isTrue);
    });

    test('one line promises less than the code delivers, and says which', () {
      // "See your cycle information unless you share it" implies that sharing
      // would open it. It would not: cycle has no field on the wire, so the
      // switch is never consulted. The dictionary is not this feature's to
      // edit, so the gap is named instead of quietly widened.
      expect(AssistantLimit.seeYourCycle.copyUnderstatesTheGuarantee, isTrue);
      for (final limit in AssistantLimit.values) {
        if (limit == AssistantLimit.seeYourCycle) continue;
        expect(limit.copyUnderstatesTheGuarantee, isFalse);
      }
    });

    test('P0-ASK-18 — nothing it renders names the feature that way', () {
      final rendered = <String>[
        boundaries.title,
        boundaries.canHeading,
        boundaries.cannotHeading,
        ...boundaries.can.values,
        ...boundaries.cannot.values,
        boundaries.whatLeavesYourPhoneHeading,
        boundaries.whatLeavesYourPhoneBody,
        boundaries.askCta,
        for (final key in AnswerKey.values)
          assistantAnswerTemplate(_l10n, key, rowCount: 2) ?? '',
      ];
      for (final line in rendered) {
        expect(RegExp(r'\bAI\b').hasMatch(line), isFalse, reason: line);
        expect(RegExp(r'A\.\s*I\.').hasMatch(line), isFalse, reason: line);
      }
    });
  });
}
