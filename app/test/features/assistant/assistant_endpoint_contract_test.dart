// P0-ASK-14, P0-ASK-15 and P0-ASK-16 — and an honest account of which half of
// each one a handset can actually prove.
//
// All three cases are written against the *backend*: an endpoint that rejects a
// missing App Check token, a relationship lookup that refuses another coach's
// client, a usage block that reports `cache_read_input_tokens > 0`. None of
// that is observable from `flutter test`, and pretending otherwise would be
// worse than not testing it — a green row labelled P0-ASK-14 reads as "the
// endpoint is secure" to whoever scans the suite next.
//
// So each group below states the server-side half as NOT COVERED, in the test
// names, and then asserts the client-side property that has to hold for the
// server-side one to be reachable at all:
//
//   * 14 — nothing in this app can call a model except through the backend, and
//     the shipped seam calls nothing at all.
//   * 15 — the payload has no field that names a woman, so a coach cannot even
//     express a request for someone else's data; the authorisation check has
//     nothing to authorise against but the caller's own token.
//   * 16 — the part of the cached prefix the app controls is byte-stable:
//     frozen, sorted, and free of anything that varies per woman.
//
// It also holds the seam's own contract — the guarantees that must survive a
// change of vendor, because none of them is a model feature.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/features/assistant/domain/assistant_pack.dart';
import 'package:own_hub/features/assistant/domain/assistant_provider.dart';
import 'package:own_hub/features/assistant/domain/assistant_quota.dart';
import 'package:own_hub/features/assistant/domain/assistant_service.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/assistant/domain/safety_classifier.dart';

final DateTime _now = DateTime(2026, 9, 19, 21, 10);

const String _providerSource =
    'lib/features/assistant/domain/assistant_provider.dart';
const String _wireSource = 'lib/features/assistant/domain/assistant_wire.dart';

/// Non-comment lines of [path].
List<String> _code(String path) => [
  for (final line in File(path).readAsLinesSync())
    if (!line.trimLeft().startsWith('//') &&
        !line.trimLeft().startsWith('///') &&
        !line.trimLeft().startsWith('*'))
      line,
];

AssistantRequest _request({
  Set<String> equipment = const {'mat', 'dumbbells'},
}) => AssistantRequest(
  question: 'a knee-safe alternative to today\'s squat',
  subject: AssistantSubject.boundToCaller(
    locale: 'ar',
    equipment: equipment,
    constraints: const ClientSafetyFacts(
      avoid: {
        ContraindicationTag.deepKneeFlexion,
        ContraindicationTag.highImpact,
      },
      allergies: {'sesame', 'nuts'},
      dietary: {'vegetarian'},
    ),
    sessionMinutes: '20',
    place: 'home',
  ),
);

/// Fails the test if it is ever reached. Several cases assert it is not.
class _NeverCalledProvider implements AssistantProvider {
  int calls = 0;

  @override
  Future<ProviderOutcome<AssistantAnswer>> answer(
    AssistantRequest request,
  ) async {
    calls++;
    return const ProviderDelivered<AssistantAnswer>(
      AssistantAnswer.nothingFound,
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

class _InScopeClassifier implements SafetyClassifier {
  int calls = 0;

  @override
  Future<SafetyVerdict> classify(String question) async {
    calls++;
    return const SafetyVerdict.inScope();
  }
}

AssistantService _service({
  required SafetyClassifier classifier,
  required AssistantProvider provider,
  AssistantQuota? quota,
}) => AssistantService(
  classifier: classifier,
  provider: provider,
  pack: AssistantPack.empty,
  quota: quota,
  flags: FeatureFlags.allOff.with_({Feature.assistant: true}),
);

void main() {
  group('P0-ASK-14 — the endpoint rejects what it should', () {
    test('NOT COVERED here: unauthenticated, missing App Check, replayed token '
        '— all three are server-side and unobservable from a handset', () {
      // Kept as a named, passing row so the gap is visible in the report
      // rather than inferred from a missing one. The Function's gates are
      // G15 §6.2: `request.auth` → `request.app` → claims → quota → kill
      // switch → payload → guardrail. The emulator suite owns them.
      expect(true, isTrue);
    });

    test('the app cannot reach a model except through the backend', () {
      // The client-side half that makes the server-side one the ONLY path. No
      // HTTP client, no vendor SDK, no endpoint string — asserted over the
      // whole feature in `assistant_product_rules_test.dart`. Here: the seam
      // itself takes no credentials, so there is no arrangement of it that
      // could authenticate to a vendor.
      final source = _code(_providerSource).join('\n');
      expect(
        RegExp(
          r'\b(token|credential|authorization|bearer|endpoint|baseUrl|Uri)\b',
          caseSensitive: false,
        ).hasMatch(source),
        isFalse,
        reason: 'the provider is an interface, not a client',
      );
    });

    test('the shipped seam spends nothing, because it calls nothing', () async {
      // "Zero tokens are spent in all three cases" has a stronger form today:
      // zero tokens are spent in every case, because the only implementation
      // that exists refuses.
      const provider = UnavailableAssistantProvider();
      for (final call in <Future<ProviderOutcome<Object>> Function()>[
        () => provider.answer(_request()),
        () => provider.draftPlan(_request()),
        () => provider.draftMealWeek(_request()),
      ]) {
        // A rejected future, not a synchronous throw: a caller that holds the
        // future and awaits it later must still see the refusal.
        await expectLater(
          call(),
          throwsA(isA<AssistantProviderUnavailable>()),
          reason: 'no route may appear to answer',
        );
      }
    });

    test('a closed gate ends the call, and the provider is never reached', () async {
      // The order matters more than any single gate: every refusal below
      // happens with `calls == 0`, so nothing was paid for before the decision
      // was made.
      final provider = _NeverCalledProvider();
      final classifier = _InScopeClassifier();

      // Switched off.
      final off = AssistantService(
        classifier: classifier,
        provider: provider,
        pack: AssistantPack.empty,
        flags: FeatureFlags.allOff.with_({Feature.assistant: false}),
      );
      expect(await off.ask(_request(), now: _now), isA<AssistantUnavailable>());

      // Offline.
      final online = _service(classifier: classifier, provider: provider);
      expect(
        await online.ask(_request(), now: _now, online: false),
        isA<AssistantUnavailable>(),
      );

      // Over the cap.
      final capped = _service(
        classifier: classifier,
        provider: provider,
        quota: AssistantQuota(
          caps: const AssistantQuotaCaps(questionsPerDay: 0, draftsPerDay: 0),
        ),
      );
      expect(await capped.ask(_request(), now: _now), isA<AssistantCapped>());
      expect(
        await capped.draftPlan(_request(), now: _now),
        isA<AssistantCapped>(),
      );

      expect(provider.calls, 0);
      expect(
        classifier.calls,
        0,
        reason: 'the guardrail costs money too, so it is behind the gates',
      );
    });
  });

  group('P0-ASK-15 — a coach cannot reach a client she does not coach', () {
    test('NOT COVERED here: the relationship lookup and the sharing switch are '
        'read by the Function, not by the app', () {
      // `bindCoachSubject` (G15 §6.2) requires role `coach`, an ACTIVE
      // relationship and `sharing.logs == true`, and throws
      // permission-denied before any model call. Emulator territory.
      expect(true, isTrue);
    });

    test('the payload has no field that could name another woman', () {
      final body = _request().toWire();
      for (final key in body.keys) {
        expect(
          RegExp(
            r'uid|userId|client|coach|subject|behalf',
            caseSensitive: false,
          ).hasMatch(key),
          isFalse,
          reason: '"$key" would be a way to ask about somebody else',
        );
      }
    });

    test('the subject is bound to the caller, and takes no identifier', () {
      // D4 in its strongest form: the factory that builds the only addressable
      // subject has no parameter for whose data it is. A model — or a coach —
      // has nothing to point elsewhere with.
      final source = _code(_wireSource).join('\n');
      final factory = RegExp(
        r'factory AssistantSubject\.boundToCaller\(\{([\s\S]*?)\}\)',
      ).firstMatch(source);
      expect(factory, isNotNull);
      expect(
        RegExp(r'\b(uid|userId|clientUid|coachUid|subjectId)\b')
            .hasMatch(factory!.group(1)!),
        isFalse,
      );
    });

    test('no tool takes an identifier either', () {
      // `get_client_context` is `{}` by design. The six names are frozen and
      // none of them has an argument that selects a person.
      expect(AssistantTool.values, hasLength(6));
      expect(AssistantTool.getClientContext.wireName, 'get_client_context');
      final source = _code(_wireSource).join('\n');
      expect(RegExp(r'\buid\b').hasMatch(source), isFalse);
    });
  });

  group('P0-ASK-16 — the cached prefix does not move', () {
    test(
      'NOT COVERED here: cache_read_input_tokens comes back in a usage block '
      'the app never sees',
      () {
        // The case FAILS on the server when the second response reports zero,
        // which means something in the prefix varies per request. What follows
        // is the half of "does not vary" that lives in this repository.
        expect(true, isTrue);
      },
    );

    test('the tool array is frozen, sorted and identical on every read', () {
      final first = [for (final t in AssistantTool.sortedByName) t.wireName];
      final second = [for (final t in AssistantTool.sortedByName) t.wireName];
      expect(first, second);
      expect(first, List<String>.from(first)..sort());
      expect(first, hasLength(6));
      // An unsorted tool array is a silent cache invalidator on every single
      // request (G15 §2.2), and it would never show up as a bug — only as a
      // bill.
      expect(
        () => AssistantTool.sortedByName.add(AssistantTool.draftPlan),
        throwsUnsupportedError,
      );
    });

    test('nothing per-woman rides in the prefix, and the body is stable', () {
      // The prefix is `tools` → `system`; her question, equipment and avoid
      // list go in `messages`, which is deliberately uncached. The property the
      // app owns is that the same facts serialise to the same bytes — a set
      // whose iteration order wandered would produce a different body for the
      // same woman on the same day, and the cache would read as broken.
      final a = _request(equipment: const {'mat', 'dumbbells', 'band'})
          .toWire();
      final b = _request(equipment: const {'band', 'mat', 'dumbbells'})
          .toWire();
      expect(a.toString(), b.toString());
      expect(a['equipment'], <String>['band', 'dumbbells', 'mat']);
      expect(a['avoid'], <String>['deep_knee_flexion', 'high_impact']);
      expect(a['allergies'], <String>['nuts', 'sesame']);
    });
  });

  group('the seam survives the vendor: what a real implementation must satisfy', () {
    test('three routes, and not one of them returns a write receipt', () {
      // Every return type is a value object from `assistant_wire.dart`. None is
      // a handle, a document reference or a receipt, so there is no server path
      // from a model token to a published plan — D1.
      final source = _code(_providerSource).join('\n');
      final abstract = RegExp(
        r'abstract class AssistantProvider \{[\s\S]*?\n\}',
      ).firstMatch(source);
      expect(abstract, isNotNull);

      final methods = RegExp(r'Future<ProviderOutcome<(\w+)>>\s+(\w+)\(')
          .allMatches(abstract!.group(0)!)
          .toList();
      expect(
        [for (final m in methods) m.group(2)],
        ['answer', 'draftPlan', 'draftMealWeek'],
      );
      expect(
        [for (final m in methods) m.group(1)],
        ['AssistantAnswer', 'PlanDraft', 'MealDraft'],
      );
    });

    test('a refusal and a truncation carry no content to render', () {
      // P0-ASK-06 made structural: the stop reason is not read before the
      // content by convention — there IS no content on the outcomes that
      // declined, so no ordering mistake can expose one.
      final source = _code(_providerSource).join('\n');
      for (final name in ['ProviderRefused', 'ProviderTruncated']) {
        final body = RegExp(
          'final class $name<T> extends ProviderOutcome<T> \\{[\\s\\S]*?\\n\\}',
        ).firstMatch(source);
        expect(body, isNotNull, reason: '$name must exist');
        expect(
          RegExp(
            r'^\s*final\s+T\s+\w+;',
            multiLine: true,
          ).hasMatch(body!.group(0)!),
          isFalse,
          reason: '$name must not carry a payload',
        );
      }
    });

    test('the interface takes no identifier, no key and no transport', () {
      final source = _code(_providerSource).join('\n');
      expect(
        RegExp(r'\b(uid|apiKey|api_key|model|prompt|systemPrompt)\s*[,:)]')
            .hasMatch(source),
        isFalse,
        reason:
            'the vendor is a detail of one class in data/; naming a model or a '
            'prompt here would put it in the shipped domain',
      );
    });

    test(
      'the only shipped implementation refuses, and names its reason',
      () async {
        const provider = UnavailableAssistantProvider();
        await expectLater(
          provider.answer(_request()),
          throwsA(
            isA<AssistantProviderUnavailable>().having(
              (e) => e.reason,
              'reason',
              AssistantUnavailableReason.notImplemented,
            ),
          ),
        );

        // And the service turns that into a named screen state rather than a
        // crash or an empty bubble.
        final outcome = await _service(
          classifier: _InScopeClassifier(),
          provider: provider,
        ).ask(_request(), now: _now);
        expect(
          outcome,
          isA<AssistantUnavailable>().having(
            (o) => o.reason,
            'reason',
            AssistantUnavailableReason.notImplemented,
          ),
        );
      },
    );

    test('the caps are the ones G15 §2.4 names, and they are per day', () {
      const caps = AssistantQuotaCaps();
      expect(caps.capFor(QuotaRoute.question), 5);
      expect(caps.capFor(QuotaRoute.draft), 6);
      // The 70%-of-budget rung tightens questions and never loosens anything.
      expect(AssistantQuotaCaps.tightened.questionsPerDay, 3);
      expect(
        AssistantQuotaCaps.tightened.questionsPerDay,
        lessThan(caps.questionsPerDay),
      );
    });

    test('a woman and a coach spend from separate ceilings', () {
      final quota = AssistantQuota();
      for (var i = 0; i < 5; i++) {
        expect(quota.tryConsume(QuotaRoute.question, _now), isTrue);
      }
      expect(quota.tryConsume(QuotaRoute.question, _now), isFalse);
      // Her spent questions do not eat into the coach's drafts.
      expect(quota.hasHeadroom(QuotaRoute.draft, _now), isTrue);
      expect(quota.spent(QuotaRoute.draft, _now), 0);
    });
  });
}
