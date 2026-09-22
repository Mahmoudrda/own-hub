/// The guardrail, and the reason it runs first.
///
/// G15 D3: **the cheap classifier runs first and the expensive model is never
/// called on a medical question.** Two things follow from that sentence, and
/// both are structural here rather than procedural:
///
///  * `X02` must **refuse, not hedge**. A refusal that arrives after the answer
///    model has already composed a suggestion is a suppressed suggestion, and
///    HANDOFF rule 5 asks for something stronger: for a severe symptom the
///    workout suggestion **is never generated**. `AssistantService` therefore
///    short-circuits on the verdict — the provider is not called at all, so
///    there is no suggestion in memory to suppress, log or leak.
///
///  * A guardrail failure must **never open the gate**. [ClassifierUnavailable]
///    is an exception rather than a verdict, precisely so that a `catch` which
///    forgot to handle it cannot quietly fall through to a value that reads as
///    "fine". `assistant_service_test.dart` proves the expensive path is not
///    reached on a throw *or* on a timeout.
///
/// ## Why this is an interface with no working implementation
///
/// The same posture as `UnavailableCaptureService` in
/// `lib/features/signup/domain/id_capture.dart`: the only implementation that
/// exists is one that refuses and says why. There is no heuristic keyword
/// matcher here, and that absence is deliberate — a regex over "pain" and
/// "bleeding" would pass the tests, ship, and then fail open on the first
/// question phrased in Egyptian Arabic that nobody wrote a pattern for. A
/// guardrail that is 70% right is worse than one that is honestly absent,
/// because the product would be sold on it.
///
/// So until a model is wired behind this interface, the assistant is
/// unavailable, and `Feature.assistant` is off.
library;

import 'package:meta/meta.dart';

/// Why the assistant will not answer. G15 §3.2 classifies into exactly four.
///
/// Each maps to a copy variant on `X02`. There is no `other`: a verdict the
/// classifier cannot place is not a refusal category, it is a classifier
/// failure, and those fail closed through [ClassifierUnavailable] instead.
enum RefusalCategory {
  /// "Is this normal?" — a diagnostic question. X02 copy A.
  medicalDiagnostic,

  /// A severe symptom. HANDOFF rule 5's medical-guidance state: the suggestion
  /// is never generated, not generated and hidden.
  severeSymptom,

  /// Care is needed now. Same copy as [severeSymptom], with the route to care
  /// promoted above the fold.
  emergency,

  /// "Give me something intense despite my injury." X02 copy C.
  unsafeRequest;

  /// True when the route to care should lead, rather than follow the refusal.
  bool get promotesCare => this == emergency;
}

/// The guardrail's answer.
///
/// A sealed pair rather than a nullable category, so "in scope" is a value
/// somebody had to construct rather than the absence of one.
@immutable
sealed class SafetyVerdict {
  const SafetyVerdict();

  /// Safe to spend the expensive call on.
  const factory SafetyVerdict.inScope() = InScope;

  /// Refuse, and route. The answer model is never invoked.
  const factory SafetyVerdict.refused(RefusalCategory category) = Refused;
}

final class InScope extends SafetyVerdict {
  const InScope();
}

final class Refused extends SafetyVerdict {
  const Refused(this.category);

  final RefusalCategory category;
}

/// The guardrail could not answer, so nothing may proceed.
///
/// Thrown, never returned. See the file note: a failure that is representable
/// as a verdict is a failure that eventually gets treated as one.
class ClassifierUnavailable implements Exception {
  const ClassifierUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'ClassifierUnavailable($reason)';
}

/// Classifies a question before any expensive call is made.
abstract class SafetyClassifier {
  /// Returns a verdict, or throws [ClassifierUnavailable].
  ///
  /// Implementations must apply their own timeout and convert it into a throw:
  /// a hung guardrail that never completes holds the gate open for as long as
  /// the caller is willing to wait.
  Future<SafetyVerdict> classify(String question);
}

/// The only implementation that exists today: one that refuses, and says why.
///
/// It is **not** a stand-in guardrail. It never returns [InScope], so no screen
/// built against it can appear to be answering when nothing has screened the
/// question — and no test can pass by pretending, because no fake that *works*
/// ships in `lib/`.
class UnavailableSafetyClassifier implements SafetyClassifier {
  const UnavailableSafetyClassifier({this.reason = 'not-implemented'});

  final String reason;

  @override
  Future<SafetyVerdict> classify(String question) async {
    throw ClassifierUnavailable(reason);
  }
}
