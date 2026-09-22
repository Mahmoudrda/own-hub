/// The money seam — `K05` (getting paid) and `K17` (earnings).
///
/// **There is no working implementation of this interface, and that is the
/// honest state of the product.** G12 §9 Q7 records it plainly: *"`K17`'s
/// earnings are rendered from a collection no group owns — payments, escrow,
/// the 80% split and payouts are absent from the spine entirely."* No provider
/// is contracted, no rail is wired, and `pubspec.yaml` carries no SDK. So the
/// only implementation here is [UnavailablePaymentProvider], which says so
/// rather than pretending.
///
/// The screens are built against this interface so that adding Paymob is a
/// dependency change rather than a rewrite — and so that a fake can never be
/// mistaken for a working rail, **because no fake that succeeds exists to be
/// mistaken**. This is the same posture `features/signup/domain/id_capture.dart`
/// takes for the camera, and it is taken here for a stronger reason: a fake
/// camera wastes a screenshot, a fake capture takes a woman's money.
///
/// Four properties of this interface are load-bearing, and each is enforced by
/// what the types cannot express rather than by a check:
///
///  * **A zero is not an answer.** [EarningsState] has no "empty statement"
///    variant and [EarningsStatement] has no zero-valued default constructor.
///    When the seam cannot supply a figure the only reachable state is
///    [EarningsUnavailable], and a screen given that renders **nothing about
///    money** — not "0 EGP". A fabricated zero is a claim about her month.
///  * **Success is never constructible by us.** [CaptureOutcome.captured] and a
///    non-empty [EarningsStatement] are built by the provider adapter and by
///    nothing else. `test/features/coach/no_fabricated_money_test.dart` scans
///    this feature's source and fails if any file constructs one.
///  * **The raw wallet number has nowhere to live.** [PayoutDestination] holds a
///    [PayoutDestination.maskedTail] and a holder name. There is no field an
///    account number could be stored in, so "we forgot to tokenise it" is not a
///    state this layer can reach. [PayoutMethodDraft] carries the number for the
///    length of one call and redacts itself in `toString`.
///  * **Refusal carries a reason a screen can act on.** [PaymentUnavailableReason]
///    distinguishes "no rail exists" from "you are offline" from "the switch is
///    dark", because those three need three different sentences and one spinner
///    would serve none of them.
///
/// Everything reachable from here is additionally behind `Feature.payments`
/// (`domain/flags/feature_flags.dart`), which ships **off**. The directory and
/// the profiles can be browsed long before a payment rail is contracted, and the
/// flag is what keeps those two facts separable.
library;

import 'package:meta/meta.dart';

/// Why the money rail cannot answer, in terms a screen can act on.
///
/// [notImplemented] is first because it is today's real answer, and naming it
/// keeps the gap visible in the UI instead of behind a spinner that never
/// resolves.
enum PaymentUnavailableReason {
  /// No provider is contracted and no SDK is wired up. Today's answer.
  notImplemented,

  /// `Feature.payments` is dark. Distinct from [notImplemented]: the rail may
  /// exist and simply not be switched on for her yet.
  featureOff,

  /// No signal. Tokenising a wallet number is a network round-trip by
  /// definition (G12 §4), so this is a refusal and never a queued write.
  offline,

  /// The provider is reachable but could not answer. **Never a rejection of
  /// her** — the screen offers a retry, not an explanation of her finances.
  providerUnavailable,

  /// She has not finished `K05`. Earnings exist but have nowhere to be sent.
  noPayoutMethod,
}

/// How she is paid. Wallet first, because that is how most Egyptian coaches
/// actually get paid (`K05`'s note).
enum PayoutKind { mobileWallet, bankAccount }

/// Where a month's money has got to.
enum PayoutState {
  /// Earned, not yet scheduled. The month is still running.
  accruing,

  /// Scheduled for the 1st.
  scheduled,

  /// Sent.
  paid,

  /// The transfer failed. Surfaced honestly; never rendered as `paid`.
  failed,
}

/// What she typed on `K05`, on its way to the provider's tokeniser.
///
/// **Transient by contract.** This object exists for the length of one
/// [PaymentProvider.setPayoutMethod] call and is never persisted: G12 §1.3 is
/// explicit that *"the raw wallet number never reaches Firestore"*. Nothing here
/// is `const`, nothing here is stored, and [toString] redacts the number so a
/// log line cannot leak it.
@immutable
class PayoutMethodDraft {
  const PayoutMethodDraft({
    required this.kind,
    required this.holderName,
    required this.accountRef,
  });

  final PayoutKind kind;

  /// Her name as it appears on the account. `K05`'s third field.
  final String holderName;

  /// The wallet or account number, for the tokeniser and for nothing else.
  final String accountRef;

  /// True when there is enough to attempt tokenisation at all.
  ///
  /// Deliberately weak: this is not validation of an Egyptian wallet number,
  /// which is the provider's job and depends on the rail. Guessing the format
  /// here would reject valid numbers on behalf of a provider nobody has chosen.
  bool get isComplete =>
      holderName.trim().isNotEmpty && accountRef.trim().length >= 6;

  /// Redacted. A draft that printed itself would put a wallet number in a log.
  @override
  String toString() => 'PayoutMethodDraft(${kind.name}, accountRef: redacted)';
}

/// Where her money goes, as the app is allowed to know it.
///
/// Note what is absent and must stay absent: the account number. Only the
/// provider holds it, behind a token; we hold four characters so `K05` and `K17`
/// can show her which wallet she chose.
@immutable
class PayoutDestination {
  const PayoutDestination({
    required this.kind,
    required this.holderName,
    required this.maskedTail,
    required this.updatedAt,
  });

  final PayoutKind kind;
  final String holderName;

  /// The last few characters, as the provider returned them — "xx32".
  final String maskedTail;

  final DateTime updatedAt;
}

/// What `K05` knows about her payout method.
@immutable
sealed class PayoutMethodState {
  const PayoutMethodState();

  /// The rail cannot answer. Carries the reason so the screen can offer the
  /// right way out.
  const factory PayoutMethodState.unavailable(PaymentUnavailableReason reason) =
      PayoutMethodUnavailable;

  /// The rail answered: she has not set one. Different from [unavailable], and
  /// the difference is the whole point — one is a gap in her setup, the other
  /// is a gap in ours.
  const factory PayoutMethodState.none() = PayoutMethodNotSet;

  const factory PayoutMethodState.set(PayoutDestination destination) =
      PayoutMethodSet;

  /// True only when money has somewhere to go.
  bool get isUsable => this is PayoutMethodSet;

  /// True when the app knows the answer, whatever the answer is.
  bool get isKnown => this is! PayoutMethodUnavailable;
}

class PayoutMethodUnavailable extends PayoutMethodState {
  const PayoutMethodUnavailable(this.reason);
  final PaymentUnavailableReason reason;
}

class PayoutMethodNotSet extends PayoutMethodState {
  const PayoutMethodNotSet();
}

class PayoutMethodSet extends PayoutMethodState {
  const PayoutMethodSet(this.destination);
  final PayoutDestination destination;
}

/// One line of a month's earnings — `K17`'s "10 monthly packages".
@immutable
class EarningsLine {
  const EarningsLine({
    required this.offerId,
    required this.count,
    required this.grossPiastres,
    required this.sharePiastres,
  });

  final String offerId;
  final int count;

  /// Minor units. Money is integer arithmetic here for the usual reason: a
  /// double cannot hold 18,000.00 EGP and 14,400.00 EGP and their difference
  /// without eventually disagreeing with the provider by a piastre.
  final int grossPiastres;
  final int sharePiastres;
}

/// One month, as the provider states it.
///
/// **There is no default constructor and no zero value.** A statement exists
/// only because a provider produced one; the absence of a statement is
/// [EarningsUnavailable], which renders nothing rather than a zero.
@immutable
class EarningsStatement {
  const EarningsStatement({
    required this.monthKey,
    required this.grossPiastres,
    required this.sharePiastres,
    required this.lines,
    required this.asOf,
    required this.payoutState,
    this.payoutDate,
    this.destination,
  });

  /// `yyyy-MM`. Western digits, sorts lexicographically, never localised —
  /// the same reasoning as `domain/format/day_key.dart`.
  final String monthKey;

  final int grossPiastres;
  final int sharePiastres;
  final List<EarningsLine> lines;

  /// When the provider last computed this. `K17` states it, because a stale
  /// figure is never rendered as live (G12 §4).
  final DateTime asOf;

  final PayoutState payoutState;
  final DateTime? payoutDate;

  /// Where this month is going, when that is known.
  final PayoutDestination? destination;

  /// Her share as a percentage of gross, or null when gross is zero.
  ///
  /// Nullable rather than defaulting to 80: the 80% is a contractual promise,
  /// and the number rendered beside her money must be the one the provider
  /// actually applied. If they ever disagree, she sees the truth.
  double? get sharePercent =>
      grossPiastres == 0 ? null : sharePiastres * 100 / grossPiastres;
}

/// What `K17` knows about a month.
@immutable
sealed class EarningsState {
  const EarningsState();

  const factory EarningsState.unavailable(PaymentUnavailableReason reason) =
      EarningsUnavailable;

  const factory EarningsState.statement(EarningsStatement statement) =
      EarningsAvailable;

  /// The statement, or null. Null renders **nothing about money at all**.
  EarningsStatement? get statementOrNull =>
      this is EarningsAvailable ? (this as EarningsAvailable).statement : null;
}

class EarningsUnavailable extends EarningsState {
  const EarningsUnavailable(this.reason);
  final PaymentUnavailableReason reason;
}

class EarningsAvailable extends EarningsState {
  const EarningsAvailable(this.statement);
  final EarningsStatement statement;
}

/// The result of capturing an authorisation, on accept (`K09`).
@immutable
sealed class CaptureOutcome {
  const CaptureOutcome();

  const factory CaptureOutcome.unavailable(PaymentUnavailableReason reason) =
      CaptureUnavailable;

  /// Money actually moved. **Constructed by a provider adapter and by nothing
  /// else** — see the note at the top of this file, and the source-scanning
  /// test that enforces it.
  const factory CaptureOutcome.captured({
    required String receiptId,
    required DateTime at,
  }) = Captured;

  bool get didCapture => this is Captured;
}

class CaptureUnavailable extends CaptureOutcome {
  const CaptureUnavailable(this.reason);
  final PaymentUnavailableReason reason;
}

class Captured extends CaptureOutcome {
  const Captured({required this.receiptId, required this.at});
  final String receiptId;
  final DateTime at;
}

/// The result of voiding an authorisation, on decline or expiry (`K09`).
@immutable
sealed class VoidOutcome {
  const VoidOutcome();

  const factory VoidOutcome.unavailable(PaymentUnavailableReason reason) =
      VoidUnavailable;

  const factory VoidOutcome.voided(DateTime at) = Voided;

  bool get didVoid => this is Voided;
}

class VoidUnavailable extends VoidOutcome {
  const VoidUnavailable(this.reason);
  final PaymentUnavailableReason reason;
}

class Voided extends VoidOutcome {
  const Voided(this.at);
  final DateTime at;
}

/// The money rail, as the coach app needs it.
///
/// Five methods, one per thing the product actually does with money:
/// read where it goes, change where it goes, read a month, take the hold when
/// she accepts, release the hold when she does not. G12 §3.3 fixes the
/// authorise-at-`H04` / capture-on-accept / void-on-decline shape, and it is Q2
/// — *"this needs a payment provider that supports authorisation holds in
/// Egypt"*, which is exactly the question this interface leaves open.
abstract class PaymentProvider {
  /// Where her money currently goes.
  Future<PayoutMethodState> payoutMethod();

  /// Tokenises [draft] and records the destination. The number is handed to the
  /// provider and never to us.
  ///
  /// **Never queued offline.** Tokenisation is a network round-trip by
  /// definition, so a caller with no signal gets
  /// [PaymentUnavailableReason.offline] rather than a spinner (G12 §4).
  Future<PayoutMethodState> setPayoutMethod(PayoutMethodDraft draft);

  /// One month, keyed `yyyy-MM`.
  Future<EarningsState> earnings(String monthKey);

  /// Takes the hold placed when she enquired. Called inside the accept
  /// transaction and never before it (G12 §3.3).
  Future<CaptureOutcome> capture({required String authorisationId});

  /// Releases the hold on decline, expiry or withdrawal. Capacity is unchanged
  /// either way.
  Future<VoidOutcome> voidAuthorisation({required String authorisationId});
}

/// The only implementation that exists today: one that refuses, and says why.
///
/// It is **not** a stand-in rail. It never returns [Captured], never returns a
/// [PayoutMethodSet] and never returns an [EarningsStatement], so no screen
/// built against it can appear to have moved money, and no test can pass by
/// pretending. When a provider is contracted, the adapter goes in `data/` and
/// this class stays for tests of the unavailable path.
class UnavailablePaymentProvider implements PaymentProvider {
  const UnavailablePaymentProvider({
    this.reason = PaymentUnavailableReason.notImplemented,
  });

  final PaymentUnavailableReason reason;

  @override
  Future<PayoutMethodState> payoutMethod() async =>
      PayoutMethodState.unavailable(reason);

  @override
  Future<PayoutMethodState> setPayoutMethod(PayoutMethodDraft draft) async =>
      // Silently succeeding here is what would turn a missing rail into a
      // screen that claims to have saved her wallet.
      PayoutMethodState.unavailable(reason);

  @override
  Future<EarningsState> earnings(String monthKey) async =>
      EarningsState.unavailable(reason);

  @override
  Future<CaptureOutcome> capture({required String authorisationId}) async =>
      CaptureOutcome.unavailable(reason);

  @override
  Future<VoidOutcome> voidAuthorisation({
    required String authorisationId,
  }) async => VoidOutcome.unavailable(reason);
}
