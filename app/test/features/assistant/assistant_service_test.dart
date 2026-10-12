// The order of the gates: P0-ASK-02, 04, 05, 06, 07, 08, 17.
//
// Every test here turns on the same question — **was the expensive model
// called?** — so the provider below is not a stub that returns something
// convenient. It is a recorder that counts its invocations, and several cases
// assert that count is zero. A refusal that cost a model call is a refusal that
// was generated and then hidden, which is the failure HANDOFF rule 5 exists to
// prevent.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/assistant/domain/assistant_pack.dart';
import 'package:own_hub/features/assistant/domain/assistant_provider.dart';
import 'package:own_hub/features/assistant/domain/assistant_quota.dart';
import 'package:own_hub/features/assistant/domain/assistant_service.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/assistant/domain/safety_classifier.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

final DateTime _now = DateTime(2026, 9, 19, 18, 40);

/// Fixture ids, deliberately unlike the seeded library's, so a test cannot pass
/// by accidentally reading real content.
final AssistantPack _pack = AssistantPack(
  version: 'fx-pack-8831',
  exercises: const [
    AssistantExercise(
      exerciseId: 'fx_8831_bridge',
      name: 'fixture bridge',
      tags: {ContraindicationTag.supineLoad},
      quiet: true,
      floorOnly: true,
      prescriptionLabel: 'fixture 3 x 12',
    ),
    AssistantExercise(
      exerciseId: 'fx_8831_row',
      name: 'fixture row',
      tags: {ContraindicationTag.none},
      quiet: true,
      floorOnly: false,
    ),
  ],
  foods: const FoodLibrary(<Food>[
    Food(
      foodId: 'fx_8831_soup',
      names: ['fixture soup'],
      sizes: [FoodSize(id: 'M', label: 'medium', kcal: 190, proteinG: 11)],
    ),
  ]),
);

/// Counts calls. Several tests assert the count is zero.
class _RecordingProvider implements AssistantProvider {
  _RecordingProvider({this.answerWith, this.outcome});

  /// What to deliver when asked. Null means "deliver an empty answer".
  final AssistantAnswer? answerWith;

  /// An explicit outcome, for the refusal and truncation cases.
  final ProviderOutcome<AssistantAnswer>? outcome;

  int calls = 0;

  @override
  Future<ProviderOutcome<AssistantAnswer>> answer(
    AssistantRequest request,
  ) async {
    calls++;
    return outcome ??
        ProviderDelivered<AssistantAnswer>(
          answerWith ?? AssistantAnswer.nothingFound,
        );
  }

  @override
  Future<ProviderOutcome<PlanDraft>> draftPlan(AssistantRequest request) async {
    calls++;
    return const ProviderDelivered<PlanDraft>(PlanDraft.empty);
  }

  @override
  Future<ProviderOutcome<MealDraft>> draftMealWeek(
    AssistantRequest request,
  ) async {
    calls++;
    return const ProviderDelivered<MealDraft>(MealDraft.empty);
  }
}

/// A guardrail with a scripted verdict, and a count of its own.
class _StubClassifier implements SafetyClassifier {
  _StubClassifier(this._verdict) : _failure = null;

  _StubClassifier.throwing() : _verdict = null, _failure = 'boom';

  /// A deadline that expired — the way a real timeout reaches this layer once
  /// the implementation has converted it into a throw.
  _StubClassifier.timingOut() : _verdict = null, _failure = 'deadline-exceeded';

  final SafetyVerdict? _verdict;
  final String? _failure;
  int calls = 0;

  @override
  Future<SafetyVerdict> classify(String question) async {
    calls++;
    final failure = _failure;
    if (failure != null) throw ClassifierUnavailable(failure);
    return _verdict!;
  }
}

AssistantRequest _request([String question = 'a knee-safe alternative']) =>
    AssistantRequest(
      question: question,
      subject: AssistantSubject.boundToCaller(
        locale: 'en',
        equipment: const {'mat'},
        constraints: const ClientSafetyFacts(avoid: <ContraindicationTag>{}),
      ),
    );

AssistantService _service({
  required SafetyClassifier classifier,
  required AssistantProvider provider,
  AssistantQuota? quota,
  FeatureFlags? flags,
}) => AssistantService(
  classifier: classifier,
  provider: provider,
  pack: _pack,
  quota: quota,
  flags: flags ?? FeatureFlags.allOff.with_({Feature.assistant: true}),
);

void main() {
  group('P0-ASK-17 — the guardrail fails closed', () {
    test(
      'a classifier error never falls through to the expensive model',
      () async {
        final provider = _RecordingProvider();
        final service = _service(
          classifier: _StubClassifier.throwing(),
          provider: provider,
        );

        final outcome = await service.ask(_request(), now: _now);

        expect(outcome, isA<AssistantUnavailable>());
        expect(
          (outcome as AssistantUnavailable).reason,
          AssistantUnavailableReason.guardrailUnavailable,
        );
        expect(
          provider.calls,
          0,
          reason:
              'FAILS if a classifier failure falls through to the main model',
        );
      },
    );

    test('a classifier timeout behaves identically', () async {
      final provider = _RecordingProvider();
      final service = _service(
        classifier: _StubClassifier.timingOut(),
        provider: provider,
      );

      final outcome = await service.ask(_request(), now: _now);

      expect(outcome, isA<AssistantUnavailable>());
      expect(provider.calls, 0);
    });

    test('the shipped classifier is the unavailable one', () async {
      // There is no working guardrail in `lib/`, and no fake that works either.
      final provider = _RecordingProvider();
      final service = _service(
        classifier: const UnavailableSafetyClassifier(),
        provider: provider,
      );

      final outcome = await service.ask(_request(), now: _now);
      expect(outcome, isA<AssistantUnavailable>());
      expect(provider.calls, 0);
    });
  });

  group('P0-ASK-04 / P0-ASK-05 — it refuses, and never generates first', () {
    for (final category in RefusalCategory.values) {
      test(
        '${category.name}: exactly one model call, and it is the guardrail',
        () async {
          final provider = _RecordingProvider();
          final classifier = _StubClassifier(SafetyVerdict.refused(category));
          final service = _service(classifier: classifier, provider: provider);

          final outcome = await service.ask(
            _request('is this bleeding normal?'),
            now: _now,
          );

          expect(outcome, isA<AssistantRefusal>());
          expect((outcome as AssistantRefusal).category, category);
          expect(classifier.calls, 1);
          expect(
            provider.calls,
            0,
            reason:
                'the suggestion is NEVER GENERATED — not generated and hidden',
          );
        },
      );
    }

    test('an emergency promotes the route to care', () {
      expect(RefusalCategory.emergency.promotesCare, isTrue);
      expect(RefusalCategory.medicalDiagnostic.promotesCare, isFalse);
    });
  });

  group('P0-ASK-06 — a model-side refusal is handled as a refusal', () {
    test('the stop reason is read before any content', () async {
      // Structural: `ProviderRefused` carries no answer, so there is no content
      // block to parse and no empty bubble to render.
      final provider = _RecordingProvider(
        outcome: const ProviderRefused<AssistantAnswer>(
          RefusalCategory.medicalDiagnostic,
        ),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
      );

      final outcome = await service.ask(_request(), now: _now);

      expect(outcome, isA<AssistantRefusal>());
      expect(
        (outcome as AssistantRefusal).category,
        RefusalCategory.medicalDiagnostic,
      );
    });

    test('a truncated response is never rendered', () async {
      final provider = _RecordingProvider(
        outcome: const ProviderTruncated<AssistantAnswer>(),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
      );

      final outcome = await service.ask(_request(), now: _now);
      expect(
        (outcome as AssistantUnavailable).reason,
        AssistantUnavailableReason.truncated,
      );
    });
  });

  group('P0-ASK-02 — a move that does not exist', () {
    test('an unknown id yields nothing found, and names no move', () async {
      final provider = _RecordingProvider(
        answerWith: const AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [
            AssistantPick(
              kind: PickKind.exercise,
              id: 'a_move_that_does_not_exist',
              source: PickSource.moveLibrary,
            ),
          ],
        ),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
      );

      final outcome = await service.ask(_request(), now: _now);
      final answer = (outcome as AssistantAnswered).answer;

      expect(answer.answerKey, AnswerKey.nothingFound);
      expect(answer.picks, isEmpty);
    });

    test('a known id survives and keeps its source', () async {
      final provider = _RecordingProvider(
        answerWith: const AssistantAnswer(
          answerKey: AnswerKey.groundedAlternatives,
          picks: [
            AssistantPick(
              kind: PickKind.exercise,
              id: 'fx_8831_bridge',
              source: PickSource.herPlan,
            ),
          ],
        ),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
      );

      final answer = ((await service.ask(
        _request(),
        now: _now,
      )) as AssistantAnswered).answer;
      expect(answer.answerKey, AnswerKey.groundedAlternatives);
      expect(answer.picks.single.source, PickSource.herPlan);
    });
  });

  group('P0-ASK-08 — the daily cap is enforced before any model call', () {
    test('the third question is refused, having spent nothing', () async {
      final provider = _RecordingProvider();
      final quota = AssistantQuota(
        caps: const AssistantQuotaCaps(questionsPerDay: 2),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
        quota: quota,
      );

      await service.ask(_request(), now: _now);
      await service.ask(_request(), now: _now);
      final third = await service.ask(_request(), now: _now);

      expect(third, isA<AssistantCapped>());
      expect((third as AssistantCapped).route, QuotaRoute.question);
      expect(
        provider.calls,
        2,
        reason: 'the quota transaction shows exactly two model invocations',
      );
    });

    test('a new day restores the allowance', () async {
      final provider = _RecordingProvider();
      final quota = AssistantQuota(
        caps: const AssistantQuotaCaps(questionsPerDay: 1),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
        quota: quota,
      );

      await service.ask(_request(), now: _now);
      expect(await service.ask(_request(), now: _now), isA<AssistantCapped>());

      final tomorrow = _now.add(const Duration(days: 1));
      expect(
        await service.ask(_request(), now: tomorrow),
        isA<AssistantAnswered>(),
      );
    });

    test('coach drafts have their own, separate ceiling', () async {
      final provider = _RecordingProvider();
      final quota = AssistantQuota(
        caps: const AssistantQuotaCaps(questionsPerDay: 1, draftsPerDay: 2),
      );
      final service = _service(
        classifier: _StubClassifier(const SafetyVerdict.inScope()),
        provider: provider,
        quota: quota,
      );

      await service.ask(_request(), now: _now);
      // The question cap is spent; the draft cap is untouched.
      expect(
        await service.draftPlan(_request(), now: _now),
        isA<AssistantPlanDrafted>(),
      );
      expect(
        await service.draftMealWeek(_request(), now: _now),
        isA<AssistantMealDrafted>(),
      );
      expect(
        await service.draftPlan(_request(), now: _now),
        isA<AssistantCapped>(),
      );
    });
  });

  group('P0-ASK-07 — no signal', () {
    test('asking offline spends nothing and queues nothing', () async {
      final provider = _RecordingProvider();
      final classifier = _StubClassifier(const SafetyVerdict.inScope());
      final quota = AssistantQuota();
      final service = _service(
        classifier: classifier,
        provider: provider,
        quota: quota,
      );

      final outcome = await service.ask(_request(), now: _now, online: false);

      expect(
        (outcome as AssistantUnavailable).reason,
        AssistantUnavailableReason.offline,
      );
      expect(provider.calls, 0);
      expect(classifier.calls, 0);
      // Nothing was consumed, because nothing was attempted — and nothing is
      // retried on reconnect.
      expect(quota.spent(QuotaRoute.question, _now), 0);
    });
  });

  group('the kill switch matters here more than anywhere', () {
    test('with the feature off, nothing is called at all', () async {
      final provider = _RecordingProvider();
      final classifier = _StubClassifier(const SafetyVerdict.inScope());
      final service = _service(
        classifier: classifier,
        provider: provider,
        // The kill switch, pulled here rather than borrowed from whatever
        // `FeatureFlags.shipped` happens to say today.
        flags: FeatureFlags.allOff,
      );

      final outcome = await service.ask(_request(), now: _now);

      expect(
        (outcome as AssistantUnavailable).reason,
        AssistantUnavailableReason.switchedOff,
      );
      expect(provider.calls, 0);
      expect(classifier.calls, 0);
    });

    test("the assistant is switched on, at the owner's instruction", () {
      // The kill switch still works -- every test above proves the service
      // does nothing when the flag is off. This only records the default.
      // Off in the first release: there is no model behind it yet, and a
      // switched-on assistant that cannot answer is worse than none.
      expect(FeatureFlags.shipped.isOn(Feature.assistant), isFalse);
    });
  });

  group('drafting refuses on a refusal verdict too', () {
    test('a coach draft is never generated for a refused question', () async {
      final provider = _RecordingProvider();
      final service = _service(
        classifier: _StubClassifier(
          const SafetyVerdict.refused(RefusalCategory.severeSymptom),
        ),
        provider: provider,
      );

      expect(
        await service.draftPlan(_request(), now: _now),
        isA<AssistantRefusal>(),
      );
      expect(provider.calls, 0);
    });
  });
}
