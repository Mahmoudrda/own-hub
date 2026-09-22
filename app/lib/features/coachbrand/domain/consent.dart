/// Another woman's photograph, and the rules that make it hers.
///
/// This is the strictest file in the flow. Everything else in the builder is a
/// coach arranging her own words; a client result is a second woman's face,
/// numbers and sentence on a stranger-readable page, and she may take it back
/// at any moment.
///
/// ## Three properties, each enforced somewhere that is not a widget
///
/// **1. The coach cannot author a result.** She creates a [ResultRequest],
/// which has five fields and none of them is content. There is no constructor,
/// no `copyWith` and no repository method that lets a coach path reach
/// `mediaIds`, `quote`, `numbers`, `scope` or `consentState` — the client
/// factories on [ClientResult] are the only way those fields acquire a value,
/// and the generative constructor is private.
///
/// **2. Numbers are derived, never typed.** See `derived_numbers.dart`. The
/// allowlist excludes weight and weight-lost, so *"12 weeks, 20 kg down"* is
/// not a thing this product can store, let alone display.
///
/// **3. `consentState` is read, never copied.** [ResultVisibility.isPublishable]
/// is called by the reader, by the render Function and by the security rule —
/// and **never at publish time**. Its answer is never stored. No portfolio, ad,
/// page object or analytics record contains a consent field, which is what
/// makes withdrawal take effect on a version that was published while consent
/// was active. `toPublishedJson` is the only serialiser a published object
/// touches and it refuses to emit one.
///
/// ## The 12-month expiry, and the fail-closed default
///
/// The owner decided a granted consent **expires after 12 months and must be
/// re-requested**. G13 §1.6 wrote the predicate as
/// `granted && (expiresAt == null || now < expiresAt)`, which treats a missing
/// `expiresAt` as "never expires". Under the owner's rule that is the wrong
/// default for an old document written before the rule existed, so
/// [ResultVisibility.isPublishable] falls back to `consentedAt +
/// kConsentValidity` when `expiresAt` is absent, and refuses a `granted` result
/// with no `consentedAt` at all. A result whose provenance is unclear is not
/// published; it is the one place in this flow where silence means no.
///
/// ## Withdrawal confirms, and that is deliberate
///
/// §2 rule 9 is undo, not confirmation, everywhere in this product.
/// Consent withdrawal is the documented exception (G13 §5): it is destructive,
/// it is about another woman's photograph, and it behaves like G7's
/// block/delete. [WithdrawalIntent] therefore carries a confirmation step.
library;

import 'package:meta/meta.dart';

import 'derived_numbers.dart';

/// How long a granted consent lasts before it has to be asked again.
///
/// Owner decision. G13 §10 Q4 left this open — *"a standing 'yes' that outlives
/// the coaching relationship is an owner/legal call"* — and the answer is
/// twelve months.
const Duration kConsentValidity = Duration(days: 365);

/// How long an unanswered request stays open. G13 §3.2.
const Duration kRequestValidity = Duration(days: 14);

/// The seven states of a client result. G13 §3.2.
enum ConsentState {
  /// The coach asked. No content exists yet.
  requested,

  /// The client said yes, **in her own consent sheet**. The only publishable
  /// value, and only while it is current.
  granted,

  /// The client said no. Terminal.
  declined,

  /// The client took it back. Terminal, and a purge fires.
  withdrawn,

  /// Fourteen days with no answer, or a grant older than [kConsentValidity].
  expired,

  /// Moderation removed it.
  revoked,

  /// Her account was deleted. Treated exactly as withdrawn.
  orphaned;

  /// True for a state nothing can move out of.
  bool get isTerminal => switch (this) {
    ConsentState.requested || ConsentState.granted => false,
    _ => true,
  };
}

/// What the client ticked in her consent sheet. Hers, and only hers.
@immutable
class ConsentScope {
  const ConsentScope({
    this.photos = false,
    this.numbers = false,
    this.quote = false,
    this.faceVisible = false,
  });

  /// Nothing agreed to. The value a request carries, which is why a request
  /// cannot publish anything even if somebody forced its state.
  static const ConsentScope none = ConsentScope();

  final bool photos;
  final bool numbers;
  final bool quote;

  /// **False by default, always.** C11: blur is on unless this client chose to
  /// show her own face. It is the one field in this product where the safe
  /// value and the default value have to be the same thing.
  final bool faceVisible;

  bool get isEmpty => !photos && !numbers && !quote;

  Map<String, Object?> toJson() => <String, Object?>{
    'photos': photos,
    'numbers': numbers,
    'quote': quote,
    'faceVisible': faceVisible,
  };

  @override
  String toString() =>
      'ConsentScope(photos: $photos, numbers: $numbers, quote: $quote, '
      'faceVisible: $faceVisible)';
}

/// What a **coach** creates on B08. Five fields, none of them content.
///
/// This type is the first half of "the coach cannot author a result": there is
/// nothing on it to author with. The security rule is the second half, and the
/// repository interface is the third.
@immutable
class ResultRequest {
  const ResultRequest({
    required this.resultId,
    required this.clientUid,
    required this.relationshipId,
    required this.requestedAt,
    this.order = 0,
  });

  /// Minted once by the client, reused on every retry. Spine C1.
  final String resultId;

  final String clientUid;

  /// From G11. B08 cannot request a result from a stranger, because it cannot
  /// produce a relationship id for one.
  final String relationshipId;

  final DateTime requestedAt;

  /// The only field a coach may change after creation.
  final int order;

  /// Exactly the coach key set from G13 §6. Nothing else may be written.
  Map<String, Object?> toJson() => <String, Object?>{
    'clientUid': clientUid,
    'relationshipId': relationshipId,
    'requestedAt': requestedAt.toIso8601String(),
    'order': order,
    'consentState': ConsentState.requested.name,
  };

  @override
  String toString() => 'ResultRequest($resultId → $clientUid)';
}

/// A client result as it actually exists.
///
/// The generative constructor is private. A coach path reaches
/// [ClientResult.fromRequest] and nothing else; the content-bearing factories
/// are named for the party that may call them, and they are the executable form
/// of G13 §6's two disjoint key sets.
@immutable
class ClientResult {
  const ClientResult._({
    required this.resultId,
    required this.clientUid,
    required this.relationshipId,
    required this.requestedAt,
    required this.consentState,
    required this.scope,
    required this.mediaIds,
    required this.numbers,
    required this.blurred,
    required this.order,
    this.quote,
    this.consentedAt,
    this.withdrawnAt,
    this.expiresAt,
  });

  /// The coach's write, and the only one she has.
  ///
  /// State `requested`, no media, no numbers, no quote, empty scope. There is
  /// no optional parameter here that could carry content past it.
  factory ClientResult.fromRequest(ResultRequest request) => ClientResult._(
    resultId: request.resultId,
    clientUid: request.clientUid,
    relationshipId: request.relationshipId,
    requestedAt: request.requestedAt,
    consentState: ConsentState.requested,
    scope: ConsentScope.none,
    mediaIds: const <String>[],
    numbers: const <String, DerivedNumber>{},
    blurred: true,
    order: request.order,
  );

  final String resultId;
  final String clientUid;
  final String relationshipId;
  final DateTime requestedAt;

  /// Read at every render. Never copied into anything.
  final ConsentState consentState;

  /// Client-written.
  final ConsentScope scope;

  /// Client-written — she picks the pictures. At most six (G13 §6).
  final List<String> mediaIds;

  /// Client-written, ≤240 graphemes.
  final String? quote;

  /// Function-written from her own bests. Never typed, never by a coach.
  final Map<String, DerivedNumber> numbers;

  final bool blurred;
  final int order;

  final DateTime? consentedAt;
  final DateTime? withdrawnAt;

  /// When this grant stops being current. Set on grant to
  /// `consentedAt + kConsentValidity`.
  final DateTime? expiresAt;

  /// **The client's own write**, from her consent sheet. Not reachable from any
  /// coach surface in this flow.
  ///
  /// [mediaIds] is capped at six to match the rule; [scope] is what she ticked,
  /// and a field she did not tick is dropped here rather than filtered later.
  ClientResult grantedByClient({
    required DateTime at,
    required ConsentScope scope,
    List<String> mediaIds = const <String>[],
    String? quote,
    Duration validity = kConsentValidity,
  }) {
    if (mediaIds.length > 6) {
      throw ArgumentError.value(
        mediaIds.length,
        'mediaIds',
        'A client may attach at most 6 pictures to one result (G13 §6).',
      );
    }
    return _copy(
      consentState: ConsentState.granted,
      consentedAt: at,
      expiresAt: at.add(validity),
      scope: scope,
      // Scope is the gate, not a later filter: unticked means not stored.
      mediaIds: scope.photos ? List.unmodifiable(mediaIds) : const <String>[],
      quote: scope.quote ? quote : null,
      // Explicit, so an unticked `quote` really clears rather than falling
      // through to whatever was there. `null` as "leave it alone" is how a
      // withdrawn sentence survives a re-grant.
      clearQuote: true,
      blurred: !scope.faceVisible,
    );
  }

  /// The client's no. Terminal.
  ClientResult declinedByClient({required DateTime at}) =>
      _copy(consentState: ConsentState.declined, withdrawnAt: at);

  /// The client taking it back, at any time, for any reason, without saying why.
  ///
  /// Content is dropped in the same write. Step 1 of G13 §3.2's propagation is
  /// *"sufficient on its own: even if 2–4 fail, no client can read the result"*
  /// — and dropping the content here means even a leaked document holds nothing.
  ClientResult withdrawnByClient({required DateTime at}) => _copy(
    consentState: ConsentState.withdrawn,
    withdrawnAt: at,
    mediaIds: const <String>[],
    quote: null,
    clearQuote: true,
    numbers: const <String, DerivedNumber>{},
    scope: ConsentScope.none,
  );

  /// Function-written: fourteen days with no answer, or a grant that aged out.
  ClientResult expiredByServer({required DateTime at}) => _copy(
    consentState: ConsentState.expired,
    withdrawnAt: at,
    mediaIds: const <String>[],
    quote: null,
    clearQuote: true,
    numbers: const <String, DerivedNumber>{},
  );

  /// Moderation.
  ClientResult revokedByModeration({required DateTime at}) => _copy(
    consentState: ConsentState.revoked,
    withdrawnAt: at,
    mediaIds: const <String>[],
    quote: null,
    clearQuote: true,
    numbers: const <String, DerivedNumber>{},
  );

  /// `onAccountDelete(uid)` from G1. Treated exactly as a withdrawal.
  ///
  /// P0-CONSENT-06: a deleted account takes its consent with it, the media is
  /// purged, and the coach is told why.
  ClientResult orphanedByAccountDeletion({required DateTime at}) => _copy(
    consentState: ConsentState.orphaned,
    withdrawnAt: at,
    mediaIds: const <String>[],
    quote: null,
    clearQuote: true,
    numbers: const <String, DerivedNumber>{},
    scope: ConsentScope.none,
  );

  /// Function-written figures, derived from her own logged bests.
  ///
  /// [bests] is *everything* G6 holds for her, which legitimately includes a
  /// weight — she logs one privately, and A03 is where it lives. Filtering it
  /// out here is the allowlist doing its job, not an error, so this path is
  /// deliberately **not** strict. [ResultNumbers.derive] with `strict: true`
  /// is for a caller that named a measure and must be told it cannot have it.
  ClientResult withDerivedNumbers(Iterable<ClientBest> bests) => _copy(
    numbers: ResultNumbers.derive(bests: bests, scopeNumbers: scope.numbers),
  );

  /// The one field a coach may change after creation: where it sits on her page.
  ClientResult reorderedByCoach(int order) => _copy(order: order);

  /// True when this result may currently be rendered anywhere.
  bool publishableAt(DateTime now) => ResultVisibility.isPublishable(this, now);

  /// What a published result object carries.
  ///
  /// **No consent field appears here.** The object's *existence* is the gate:
  /// withdrawal deletes it, the CDN returns 404, and the renderer omits the
  /// item rather than drawing a placeholder. Calling this on a result that is
  /// not currently publishable is a programming error, not a filtered-out case.
  Map<String, Object?> toPublishedJson(DateTime now) {
    if (!publishableAt(now)) {
      throw StateError(
        'toPublishedJson called on a result that is not currently publishable '
        '($resultId, ${consentState.name}). Consent is checked at read time; '
        'a caller that reaches this line has already skipped the check.',
      );
    }
    return <String, Object?>{
      'resultId': resultId,
      'order': order,
      'blurred': blurred,
      if (scope.photos) 'mediaIds': List<String>.unmodifiable(mediaIds),
      if (scope.quote && quote != null) 'quote': quote,
      if (scope.numbers)
        'numbers': <String, Object?>{
          for (final e in numbers.entries) e.key: e.value.toJson(),
        },
    };
  }

  ClientResult _copy({
    ConsentState? consentState,
    ConsentScope? scope,
    List<String>? mediaIds,
    String? quote,
    bool clearQuote = false,
    Map<String, DerivedNumber>? numbers,
    bool? blurred,
    int? order,
    DateTime? consentedAt,
    DateTime? withdrawnAt,
    DateTime? expiresAt,
  }) => ClientResult._(
    resultId: resultId,
    clientUid: clientUid,
    relationshipId: relationshipId,
    requestedAt: requestedAt,
    consentState: consentState ?? this.consentState,
    scope: scope ?? this.scope,
    mediaIds: mediaIds ?? this.mediaIds,
    quote: clearQuote ? quote : (quote ?? this.quote),
    numbers: numbers ?? this.numbers,
    blurred: blurred ?? this.blurred,
    order: order ?? this.order,
    consentedAt: consentedAt ?? this.consentedAt,
    withdrawnAt: withdrawnAt ?? this.withdrawnAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  @override
  String toString() => 'ClientResult($resultId, ${consentState.name})';
}

/// The read-time predicate, in one place.
///
/// G13 §1.6.3 and §3.2: called by the reader, by the render Function and
/// mirrored in the security rule. **Never called at publish time, and its
/// answer is never stored.**
abstract final class ResultVisibility {
  /// Whether [result] may be rendered at [now].
  ///
  /// Fails closed three ways: a non-granted state, a grant with no
  /// `consentedAt`, and a grant older than [kConsentValidity] when `expiresAt`
  /// was never written.
  static bool isPublishable(ClientResult result, DateTime now) {
    if (result.consentState != ConsentState.granted) return false;

    final consentedAt = result.consentedAt;
    if (consentedAt == null) return false;

    final expiry = result.expiresAt ?? consentedAt.add(kConsentValidity);
    return now.isBefore(expiry);
  }

  /// [results] filtered to what may be rendered, in their own order.
  ///
  /// Note the shape: a filter over live documents, at read time, every time.
  /// There is no cached list and no `publishedResultIds` field anywhere for it
  /// to disagree with.
  static List<ClientResult> visible(
    Iterable<ClientResult> results,
    DateTime now,
  ) {
    final out = results.where((r) => isPublishable(r, now)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(out);
  }

  /// The ids from [ids] that currently resolve to a publishable result.
  ///
  /// This is what a `results` block does at render: it holds ids, and the ids
  /// are resolved against live documents. An id whose result is gone simply
  /// drops out.
  static List<String> resolveIds(
    Iterable<String> ids,
    Map<String, ClientResult> byId,
    DateTime now,
  ) => List.unmodifiable(
    ids.where((id) {
      final result = byId[id];
      return result != null && isPublishable(result, now);
    }),
  );
}

/// When a withdrawal actually takes effect.
///
/// G13 §4 and `P0-CONSENT-05`: offline, the write is queued, and **the copy
/// must not say "immediately"** while it is. G7's recorded honest limit applies
/// here verbatim.
enum WithdrawalTiming {
  /// Online. The propagation cycle starts now.
  immediate,

  /// Queued. It applies when she is back online, and the screen says so.
  whenBackOnline,
}

/// A withdrawal the client has asked for.
///
/// Carries [confirmed] because consent withdrawal is the **documented
/// exception** to §2 rule 9: it may confirm. Everything else in this flow
/// undoes.
@immutable
class WithdrawalIntent {
  const WithdrawalIntent({
    required this.resultId,
    required this.requestedAt,
    required this.online,
    this.confirmed = false,
  });

  final String resultId;
  final DateTime requestedAt;

  /// Whether there was signal when she asked.
  final bool online;

  /// Set by the confirmation step. An unconfirmed intent does nothing.
  final bool confirmed;

  /// The honest answer about when this takes effect.
  WithdrawalTiming get timing =>
      online ? WithdrawalTiming.immediate : WithdrawalTiming.whenBackOnline;

  /// True only once she has confirmed. The exception to rule 9 is a
  /// confirmation, not an absence of one.
  bool get isActionable => confirmed;

  WithdrawalIntent confirm() => WithdrawalIntent(
    resultId: resultId,
    requestedAt: requestedAt,
    online: online,
    confirmed: true,
  );

  @override
  String toString() =>
      'WithdrawalIntent($resultId, ${timing.name}, confirmed: $confirmed)';
}
