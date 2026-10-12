/// A01 — the notification inbox and the permission state machine.
///
/// # Why this collection can never become an unbounded scan
///
/// G7 §2 names A01 as "the only screen in this group that can break the budget":
/// at 15 documents a page, a once-a-day habit would spend 15 of the 8-read
/// allowance by itself. Three things prevent it and **all three are
/// requirements, not optimisations**:
///
///   1. page size capped at [kInboxPageSize] — enforced by the repository, not
///      by callers remembering;
///   2. a 30-day Firestore TTL on `expiresAt`, which is what keeps the inbox
///      bounded with no cleanup job;
///   3. **no snapshot listener.** A live listener on a notification inbox
///      re-reads on every server-side write and is the standard way this goes
///      wrong. There is no `watch()` on [NotificationsRepository], so a screen
///      cannot open one.
///
/// # Spine C6, and the counter that is deliberately absent
///
/// A01 promises "ignore three and they stop by themselves". That is naturally a
/// consecutive-ignored counter, and C6 forbids a daily-consecutive counter
/// *anywhere*: "Rule 3 is enforced by making it unstorable. A UI cannot render
/// what the schema cannot hold."
///
/// So nothing counts. [MealNudgeSuppression] reads the last three `mealNudge`
/// documents — which already exist, already carry an outcome, and are already
/// TTL-bounded — and derives the answer at read time. No counter, no run, no
/// array to clobber when two devices answer the same nudge, and nothing a screen
/// could render as a streak even by mistake.
library;

import 'package:meta/meta.dart';

/// The hard page cap. A01 reads this many and no more, ever.
const int kInboxPageSize = 15;

/// How long a notification lives. Enforced server-side by a Firestore TTL
/// policy on `expiresAt`; repeated here so the client agrees rather than guesses.
const Duration kNotificationTtl = Duration(days: 30);

/// What raised the notification.
///
/// The MVP set is **unresolved** — G7 Q11 asks the owner which events A01 ships
/// with, and proposes week closed, tier change, verification decided and nudge
/// receipt. The three community kinds are here because the prototype draws them;
/// they deep-link to G13/M06/M02, which are Phase 3.
enum NotificationKind {
  coachReply,
  groupMilestone,
  reaction,
  mealNudge,
  weekClosed,
  tierChanged,
  verificationDecided,
}

/// Her answer to a meal nudge, recorded on that nudge's own document.
///
/// Written to the notification rather than to a shared array on the user
/// document — the C3 correction applied to G7's own collection. Two devices
/// answering the same nudge converge on one document instead of clobbering each
/// other.
enum NudgeOutcome { logged, ignored, dismissed }

/// One row of A01.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.read = false,
    this.readAt,
    this.outcome,
    this.deepLink,
  });

  /// Deterministic per event — `week-2026-W38-closed`, `nudge-2026-09-18-breakfast`.
  ///
  /// Spine C1: a deterministic id is what makes a replayed write idempotent. A
  /// random id would let the same week closing arrive twice.
  final String id;

  final NotificationKind kind;
  final DateTime createdAt;
  final bool read;
  final DateTime? readAt;

  /// Only ever set on a [NotificationKind.mealNudge].
  final NudgeOutcome? outcome;

  /// The screen id this row opens.
  final String? deepLink;

  /// When this document disappears. Derived, never stored independently — a
  /// stored copy could disagree with the TTL policy that actually deletes it.
  DateTime get expiresAt => createdAt.add(kNotificationTtl);

  AppNotification copyWith({
    bool? read,
    DateTime? readAt,
    NudgeOutcome? outcome,
  }) => AppNotification(
    id: id,
    kind: kind,
    createdAt: createdAt,
    read: read ?? this.read,
    readAt: readAt ?? this.readAt,
    outcome: outcome ?? this.outcome,
    deepLink: deepLink,
  );

  @override
  bool operator ==(Object other) =>
      other is AppNotification &&
      other.id == id &&
      other.read == read &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(id, read, outcome);

  @override
  String toString() => 'AppNotification($id, ${kind.name}, read: $read)';
}

/// Reads the inbox and writes the three fields a client may write.
///
/// The security rules allow a client to update `read`, `readAt` and `outcome`
/// and nothing else; creation is Function-only. This interface holds exactly
/// that shape, so a client write the rules would reject is not expressible here.
///
/// Note the absence of `watch()`. See the file note on why.
abstract class NotificationsRepository {
  /// Newest first, capped at [kInboxPageSize].
  ///
  /// Cache-first: this is called on open and on explicit pull-to-refresh, never
  /// on a timer.
  Future<List<AppNotification>> page({int limit});

  Future<void> markRead(String id);

  /// Records her answer on that nudge's own document.
  Future<void> recordOutcome(String id, NudgeOutcome outcome);

  /// The last three meal nudges, newest first — the input
  /// [MealNudgeSuppression] derives "ignore three and they stop" from.
  Future<List<AppNotification>> recentMealNudges();
}

/// In-memory, and **strict where the real one is strict**: it refuses a page
/// larger than the cap rather than quietly serving it.
///
/// A fake that honoured any `limit` would let A01 ship a 50-row page that passes
/// every test here and blows the read budget in production — the same failure
/// mode `InMemoryMealRepository` is strict about for the slot cap.
class InMemoryNotificationsRepository implements NotificationsRepository {
  InMemoryNotificationsRepository([List<AppNotification>? seed])
    : _items = [...?seed];

  final List<AppNotification> _items;

  /// Every id marked read, in order. Evidence that A01 wrote one field.
  final List<String> reads = <String>[];

  /// Every outcome recorded, as `id:outcome`.
  final List<String> outcomes = <String>[];

  @override
  Future<List<AppNotification>> page({int limit = kInboxPageSize}) async {
    if (limit > kInboxPageSize) {
      throw StateError(
        'A01 asked for $limit notifications; the cap is $kInboxPageSize. '
        'G7 §2: a larger page spends the whole 8-read daily allowance on one '
        'screen. The cap is a requirement, not a default.',
      );
    }
    final sorted = [..._items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> markRead(String id) async {
    reads.add(id);
    _replace(id, (n) => n.copyWith(read: true, readAt: DateTime.now()));
  }

  @override
  Future<void> recordOutcome(String id, NudgeOutcome outcome) async {
    outcomes.add('$id:${outcome.name}');
    _replace(id, (n) => n.copyWith(outcome: outcome));
  }

  @override
  Future<List<AppNotification>> recentMealNudges() async {
    final nudges =
        _items.where((n) => n.kind == NotificationKind.mealNudge).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return nudges.take(3).toList();
  }

  /// Empties her inbox. Account deletion calls it; manifest row 15.
  void reset() {
    _items.clear();
    reads.clear();
    outcomes.clear();
  }

  void _replace(String id, AppNotification Function(AppNotification) f) {
    final at = _items.indexWhere((n) => n.id == id);
    if (at >= 0) _items[at] = f(_items[at]);
  }
}

/// "Ignore three and they stop by themselves" — derived, never counted.
///
/// See the file note on C6. The input is three documents that already exist; the
/// output is a bool computed on the spot. There is no field anywhere in the G7
/// schema holding a run of ignored nudges, which is why this rule cannot be
/// rendered as a streak.
class MealNudgeSuppression {
  const MealNudgeSuppression();

  /// True when the last three meal nudges were all ignored.
  ///
  /// Fewer than three is **not** suppression: a woman with two ignored nudges
  /// has not yet told us anything three times.
  static bool suppressed(List<AppNotification> recentNudges) {
    if (recentNudges.length < 3) return false;
    return recentNudges.take(3).every((n) => n.outcome == NudgeOutcome.ignored);
  }
}

// --------------------------------------------------------------- permission --

/// The OS permission, as a **device** fact.
///
/// It lives in `users/{uid}/devices/{deviceId}` (G8's collection), never on the
/// user document: one handset denying notifications says nothing about another.
enum NotifPermission {
  notDetermined,
  prompting,
  granted,

  /// iOS only. Delivered quietly; behaves as granted.
  provisional,

  /// Denied once, and a rationale is still available. May ask **once** more, at
  /// a moment of value.
  deniedSoft,

  /// Denied for good. **Never prompts again** — the row deep-links to OS
  /// settings and T01 shows the in-app nudge card instead.
  deniedTerminal,

  /// Turned off in Settings after being granted. Detected on resume.
  revokedInSettings,

  /// No Play services, or a token failure. "Reminders are not available on this
  /// phone" — and an in-app nudge instead, because a silent failure is the one
  /// outcome that is not allowed.
  unavailable,
}

/// What happened to the permission.
enum PermissionEvent {
  promptShown,
  userGranted,
  userDenied,
  userGrantedProvisional,
  detectedRevoked,
  detectedGrantedInSettings,
  deliveryUnavailable,
}

/// The permission and how many times we have asked.
///
/// [promptsUsed] is a count of *our* prompts, not of her days. It exists because
/// "may ask once more" is a real rule with a real limit, and a limit nobody
/// counts is a limit that does not hold.
@immutable
class NotificationPermission {
  const NotificationPermission({
    this.state = NotifPermission.notDetermined,
    this.promptsUsed = 0,
  });

  static const NotificationPermission initial = NotificationPermission();

  final NotifPermission state;
  final int promptsUsed;

  /// The product **never prompts at launch** — it prompts after her first log.
  /// This answers "may we ask", never "should we ask now".
  bool get canPrompt => switch (state) {
    NotifPermission.notDetermined => true,
    // Once more, and only once.
    NotifPermission.deniedSoft => promptsUsed < 2,
    _ => false,
  };

  /// True when notifications can actually be delivered.
  bool get delivers =>
      state == NotifPermission.granted || state == NotifPermission.provisional;

  @override
  bool operator ==(Object other) =>
      other is NotificationPermission &&
      other.state == state &&
      other.promptsUsed == promptsUsed;

  @override
  int get hashCode => Object.hash(state, promptsUsed);

  @override
  String toString() => 'NotificationPermission(${state.name}, $promptsUsed)';
}

/// G7 §3.1's table, as a function.
///
/// "**Denied forever** is a first-class state", and its designed fallback — the
/// in-app card on T01 — is a deliverable rather than a note. Modelling it as a
/// real state is what stops the app from quietly re-prompting a woman who has
/// already said no twice, which is how an app earns a permanent denial at the OS
/// level.
class NotificationPermissionController {
  const NotificationPermissionController();

  static NotificationPermission transition(
    NotificationPermission from,
    PermissionEvent event,
  ) {
    // A token failure can happen from any state and always wins: the one thing
    // that must not happen is scheduling into a void.
    if (event == PermissionEvent.deliveryUnavailable) {
      return NotificationPermission(
        state: NotifPermission.unavailable,
        promptsUsed: from.promptsUsed,
      );
    }

    return switch ((from.state, event)) {
      (NotifPermission.notDetermined, PermissionEvent.promptShown) ||
      (NotifPermission.deniedSoft, PermissionEvent.promptShown) =>
        from.canPrompt
            ? NotificationPermission(
                state: NotifPermission.prompting,
                promptsUsed: from.promptsUsed + 1,
              )
            : from,

      (NotifPermission.prompting, PermissionEvent.userGranted) =>
        NotificationPermission(
          state: NotifPermission.granted,
          promptsUsed: from.promptsUsed,
        ),

      (NotifPermission.prompting, PermissionEvent.userGrantedProvisional) =>
        NotificationPermission(
          state: NotifPermission.provisional,
          promptsUsed: from.promptsUsed,
        ),

      // The second denial is terminal. The first leaves one more chance.
      (NotifPermission.prompting, PermissionEvent.userDenied) =>
        NotificationPermission(
          state: from.promptsUsed >= 2
              ? NotifPermission.deniedTerminal
              : NotifPermission.deniedSoft,
          promptsUsed: from.promptsUsed,
        ),

      (NotifPermission.granted, PermissionEvent.detectedRevoked) ||
      (
        NotifPermission.provisional,
        PermissionEvent.detectedRevoked,
      ) => NotificationPermission(
        state: NotifPermission.revokedInSettings,
        promptsUsed: from.promptsUsed,
      ),

      (
        NotifPermission.revokedInSettings,
        PermissionEvent.detectedGrantedInSettings,
      ) ||
      (
        NotifPermission.deniedTerminal,
        PermissionEvent.detectedGrantedInSettings,
      ) ||
      (
        NotifPermission.unavailable,
        PermissionEvent.detectedGrantedInSettings,
      ) => NotificationPermission(
        state: NotifPermission.granted,
        promptsUsed: from.promptsUsed,
      ),

      // Everything else is a no-op rather than an error. A permission callback
      // arriving twice is normal on both platforms, and crashing her app over it
      // would be a worse answer than ignoring it.
      _ => from,
    };
  }
}
