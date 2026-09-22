/// The cost ceiling, enforced before a single token is spent.
///
/// G15 §2.4 is blunt about why this exists: the assistant is the one feature in
/// this product with an **unbounded third-party bill**. At the plan's own
/// adoption numbers it is the second-largest operating cost in the whole
/// product — roughly fifty times the entire Firebase and CDN spend. Without a
/// cap, any signed-in handset can loop the endpoint.
///
/// So the cap is an architectural component, not a monitoring alert:
///
/// | Cap | Value | Enforced |
/// |---|---|---|
/// | per woman, per day | 5 questions | before any provider call |
/// | per coach, per day | 6 drafts | before any provider call |
///
/// ## Why this is checked before the guardrail too
///
/// G15 §6.2 orders the gates quota → kill switch → payload → guardrail →
/// answer. Both the guardrail and the answer model cost money, so a cap that
/// ran after the guardrail would leave the *cheap* call uncapped — which is
/// still a real bill at scale, and still an abuse surface.
///
/// ## Why the count and not the question
///
/// `SCHEMA-SPINE.md` §8 says the assistant stores nothing, and G15 §1.2 flags
/// the deviation rather than hiding it: this holds a **count**, never content.
/// No question, no answer, no transcript. That is what keeps X02's promise —
/// "nothing was logged and nothing was shared" — true by construction.
///
/// ## Why it is in-memory here
///
/// The real ledger is `assistantQuota/{uid}`, a Function-only document with no
/// client access at all: a client that can write its own quota can mint itself
/// unlimited model calls. This class is the **device-side mirror** that keeps
/// the screen honest between calls; it is not the security boundary and does
/// not pretend to be. The comment matters, because a reader who mistook this
/// for the enforcement point would later "simplify" the server check away.
library;

import 'package:meta/meta.dart';

import '../../../domain/format/day_key.dart';

/// Which ceiling applies.
enum QuotaRoute {
  /// A woman asking on `X01`.
  question,

  /// A coach drafting on `K26` / `K27`.
  draft,
}

/// The caps, and where they come from.
///
/// Defaults are the conservative values G15 §2.4 names. The real values arrive
/// from Remote Config (`assistant_daily_cap`, `assistant_draft_cap`) and may be
/// tightened — 5 → 3 at the 70% spend rung — never loosened silently.
@immutable
class AssistantQuotaCaps {
  const AssistantQuotaCaps({this.questionsPerDay = 5, this.draftsPerDay = 6});

  /// The `tighten` rung: she has fewer questions, and `Ask Sara instead` — which
  /// `X01` already presents as a first-class action rather than a fallback.
  static const AssistantQuotaCaps tightened = AssistantQuotaCaps(
    questionsPerDay: 3,
  );

  final int questionsPerDay;
  final int draftsPerDay;

  int capFor(QuotaRoute route) => switch (route) {
    QuotaRoute.question => questionsPerDay,
    QuotaRoute.draft => draftsPerDay,
  };
}

/// The device-side count, per calendar day.
///
/// The day is **her** calendar day, from `dayKey` — the day it was for her, on
/// the phone she is holding, never UTC.
class AssistantQuota {
  AssistantQuota({this.caps = const AssistantQuotaCaps()});

  /// The ceilings in force. Tightened from Remote Config, never loosened
  /// silently.
  final AssistantQuotaCaps caps;

  String? _dayKey;
  final Map<QuotaRoute, int> _counts = <QuotaRoute, int>{};

  /// How many of [route] have been spent today.
  int spent(QuotaRoute route, DateTime now) {
    _rollOver(now);
    return _counts[route] ?? 0;
  }

  /// Whether one more of [route] is allowed, without consuming it.
  bool hasHeadroom(QuotaRoute route, DateTime now) =>
      spent(route, now) < caps.capFor(route);

  /// Consumes one unit of [route], returning false at the cap.
  ///
  /// **Call this before the provider, never after.** A cap enforced after the
  /// call has already been paid for is not a cap.
  bool tryConsume(QuotaRoute route, DateTime now) {
    if (!hasHeadroom(route, now)) return false;
    _counts[route] = (_counts[route] ?? 0) + 1;
    return true;
  }

  /// A new day resets the counts. The real document is TTL-deleted at +48 h.
  void _rollOver(DateTime now) {
    final key = dayKey(now);
    if (_dayKey != key) {
      _dayKey = key;
      _counts.clear();
    }
  }
}
