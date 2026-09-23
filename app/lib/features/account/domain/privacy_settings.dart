/// `users/{uid}.privacy` and `users/{uid}.notify` — the two maps G7 owns.
///
/// `SCHEMA-SPINE.md` §1 places both on the root user document on purpose: `T01`
/// already reads it, so A02/A03/A04 read their settings for **0 incremental
/// reads**. A separate `settings` document would add a read per screen.
///
/// # Every sharing switch is independent and defaults OFF
///
/// HANDOFF rule 6, restated by the spine: "Every sharing switch is independent
/// and defaults to OFF … and `blurDefault` is on (rule 6)."
///
/// Independence is not a promise here, it is the write shape. [PrivacyKey] is an
/// enum of single keys and the repository writes **one field path per call**
/// (`privacy.showBests`), never the whole map. Two devices flipping two
/// different switches offline therefore merge on distinct keys rather than one
/// clobbering the other (spine §5), and there is no call that could set two
/// switches at once — so "turning on X quietly turned on Y" is not a shape this
/// API can express.
///
/// # A contradiction, resolved toward the spine
///
/// `G7-profile-privacy-safety.md` §1.1 gives `showBests` a default of **true**.
/// `SCHEMA-SPINE.md` §1 says every sharing switch defaults **OFF**, and the
/// spine is the file a plan may not renegotiate. `showBests` governs what other
/// members see, so it is a sharing switch, and it defaults **false** here. The
/// divergence from G7 §1.1 is reported rather than silently taken.
///
/// # What is deliberately absent
///
/// There is no `nudgeOutcomes` array and no ignored-counter of any kind.
/// Spine C6 forbids a daily-consecutive counter *anywhere*, and A01's "ignore
/// three and they stop" is derived at read time from the last three `mealNudge`
/// notification documents instead — see [MealNudgeSuppression]. Nothing here
/// can be rendered as a streak even by mistake, because nothing here counts.
// `prefer_initializing_formals` asks for `this._online`, which Dart forbids: a
// named parameter cannot begin with an underscore. The field stays private
// deliberately — the only ways in and out are goOffline/goOnline, because
// coming back online *means* draining, and a settable flag would let a test
// report signal while writes were still stranded. See the same note on
// `lib/domain/identity/user_roles.dart`.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:meta/meta.dart';

/// The four switches on A03. One key per switch, and no key that groups two.
enum PrivacyKey {
  /// A03 row 1. Name, tier and groups.
  profileVisible('profileVisible'),

  /// Numbers only, never weight from a scale (C7, rule 11).
  showBests('showBests'),

  /// Rule 6 / HANDOFF 8. The one switch that defaults ON.
  blurFacesDefault('blurFacesDefault'),

  /// HANDOFF 6 — independent, default OFF.
  shareLogsWithCoach('shareLogsWithCoach');

  const PrivacyKey(this.wireName);

  /// The key inside the `privacy` map. Never the Dart enum name: a rename would
  /// otherwise silently rewrite everybody's settings.
  final String wireName;

  /// The field path a write names. This is what makes the merge field-level.
  String get fieldPath => 'privacy.$wireName';
}

/// `users/{uid}.privacy`.
@immutable
class PrivacySettings {
  const PrivacySettings({
    this.profileVisible = false,
    this.showBests = false,
    this.blurFacesDefault = true,
    this.shareLogsWithCoach = false,
    this.policyVersion = 1,
  });

  /// What a brand-new account holds.
  ///
  /// Three false and one true, and the one true is the blur. That asymmetry is
  /// the whole of rule 6: a default that protects her is on, and every default
  /// that exposes her is off.
  static const PrivacySettings initial = PrivacySettings();

  final bool profileVisible;
  final bool showBests;
  final bool blurFacesDefault;
  final bool shareLogsWithCoach;

  /// Which privacy text she agreed to. Bumped when the wording changes, so a
  /// consent is always attributable to what it consented to.
  final int policyVersion;

  bool valueOf(PrivacyKey key) => switch (key) {
    PrivacyKey.profileVisible => profileVisible,
    PrivacyKey.showBests => showBests,
    PrivacyKey.blurFacesDefault => blurFacesDefault,
    PrivacyKey.shareLogsWithCoach => shareLogsWithCoach,
  };

  /// One key, changed. There is deliberately no `copyWith` taking four bools —
  /// a caller that could set several at once is a caller that can couple two
  /// switches together by accident.
  PrivacySettings withKey(PrivacyKey key, bool value) => PrivacySettings(
    profileVisible: key == PrivacyKey.profileVisible ? value : profileVisible,
    showBests: key == PrivacyKey.showBests ? value : showBests,
    blurFacesDefault: key == PrivacyKey.blurFacesDefault
        ? value
        : blurFacesDefault,
    shareLogsWithCoach: key == PrivacyKey.shareLogsWithCoach
        ? value
        : shareLogsWithCoach,
    policyVersion: policyVersion,
  );

  /// The keys that are currently on. Used by tests to prove independence
  /// without naming every field.
  Set<PrivacyKey> get onKeys => PrivacyKey.values.where(valueOf).toSet();

  @override
  bool operator ==(Object other) =>
      other is PrivacySettings &&
      other.profileVisible == profileVisible &&
      other.showBests == showBests &&
      other.blurFacesDefault == blurFacesDefault &&
      other.shareLogsWithCoach == shareLogsWithCoach &&
      other.policyVersion == policyVersion;

  @override
  int get hashCode => Object.hash(
    profileVisible,
    showBests,
    blurFacesDefault,
    shareLogsWithCoach,
    policyVersion,
  );

  @override
  String toString() =>
      'PrivacySettings(on: ${onKeys.map((k) => k.wireName).join("+")})';
}

/// `users/{uid}.notify`.
///
/// `quietStart`/`quietEnd` are minutes past midnight, 0–1439 — A02's copy says
/// "quiet 10pm–8am", which is 1320 and 480.
@immutable
class NotifySettings {
  const NotifySettings({
    this.push = false,
    this.mealNudge = true,
    this.quietStart = 1320,
    this.quietEnd = 480,
    this.usualMealHour,
  }) : assert(quietStart >= 0 && quietStart <= 1439, 'minutes past midnight'),
       assert(quietEnd >= 0 && quietEnd <= 1439, 'minutes past midnight');

  static const NotifySettings initial = NotifySettings();

  /// Her switch, not the OS state. The two are different facts and conflating
  /// them is how a woman who revoked permission in Settings keeps being
  /// scheduled for notifications that can never arrive.
  final bool push;

  final bool mealNudge;
  final int quietStart;
  final int quietEnd;

  /// Computed **on-device** from the locally cached `meals/*` — zero reads, and
  /// never uploaded as a behavioural profile.
  final int? usualMealHour;

  /// True when [minutes] past midnight falls inside her quiet hours.
  ///
  /// The window wraps midnight (22:00 → 08:00), so this is deliberately not a
  /// simple range test. Getting this wrong sends a nudge at 3am.
  bool isQuietAt(int minutes) => quietStart <= quietEnd
      ? minutes >= quietStart && minutes < quietEnd
      : minutes >= quietStart || minutes < quietEnd;

  @override
  bool operator ==(Object other) =>
      other is NotifySettings &&
      other.push == push &&
      other.mealNudge == mealNudge &&
      other.quietStart == quietStart &&
      other.quietEnd == quietEnd &&
      other.usualMealHour == usualMealHour;

  @override
  int get hashCode =>
      Object.hash(push, mealNudge, quietStart, quietEnd, usualMealHour);
}

/// What a switch write did, and whether it has reached the server yet.
///
/// [queuedLocally] is the honest half. HANDOFF rule 6 says revoking a sharing
/// switch "immediately revokes the coach's derived panels"; offline that cannot
/// be true, because the server cannot deny a read it has not heard about. G7 §4
/// records the collision and its resolution: the switch flips locally at once,
/// and the copy says it applies everywhere once she has signal — never
/// "immediately".
///
/// So a caller cannot render this outcome without being handed the fact that it
/// is queued. A screen that wanted to claim immediacy would have to ignore a
/// field that is right there.
@immutable
class SwitchOutcome {
  const SwitchOutcome({required this.settings, required this.queuedLocally});

  final PrivacySettings settings;

  /// True when the write is saved on this phone and has not reached the server.
  final bool queuedLocally;

  /// Deliberately phrased as a question about *sync*, not about time. There is
  /// no `appliesImmediately` anywhere in this file.
  bool get appliesEverywhereNow => !queuedLocally;
}

/// Reads and writes the two G7 maps.
///
/// Every write names **one field path**. There is no method that takes a whole
/// [PrivacySettings], because that is a read-modify-write and spine §5 allows
/// last-write-wins only for single-owner scalars — a map is not one.
abstract class PrivacyRepository {
  PrivacySettings settings();
  NotifySettings notify();

  /// Writes exactly `privacy.<key>`. Returns whether it queued rather than sent.
  Future<bool> setPrivacyKey(PrivacyKey key, bool value);

  /// Writes exactly `notify.push` or `notify.mealNudge`.
  Future<bool> setNotifyPush(bool value);
  Future<bool> setNotifyMealNudge(bool value);
}

/// In-memory, and **strict about the one thing that matters**: it records the
/// field path of every write, so a test can prove that flipping one switch wrote
/// one key and touched nothing else.
///
/// A fake that stored the resulting object without recording the path would let
/// a whole-map overwrite pass here and lose a woman's other settings in
/// production — the same class of defect `InMemoryMealRepository` is strict
/// about for C3.
class InMemoryPrivacyRepository implements PrivacyRepository {
  InMemoryPrivacyRepository({
    PrivacySettings? privacy,
    NotifySettings? notify,
    bool online = true,
  }) : _privacy = privacy ?? PrivacySettings.initial,
       _notify = notify ?? NotifySettings.initial,
       _online = online;

  PrivacySettings _privacy;
  NotifySettings _notify;
  bool _online;

  /// Field paths written, in order: `privacy.showBests`, `notify.push`.
  final List<String> writes = <String>[];

  /// Writes made with no signal and not yet sent.
  final List<String> pending = <String>[];

  bool get online => _online;

  void goOffline() => _online = false;

  Future<void> goOnline() async {
    _online = true;
    pending.clear();
  }

  @override
  PrivacySettings settings() => _privacy;

  @override
  NotifySettings notify() => _notify;

  @override
  Future<bool> setPrivacyKey(PrivacyKey key, bool value) async {
    _privacy = _privacy.withKey(key, value);
    return _record(key.fieldPath);
  }

  @override
  Future<bool> setNotifyPush(bool value) async {
    _notify = NotifySettings(
      push: value,
      mealNudge: _notify.mealNudge,
      quietStart: _notify.quietStart,
      quietEnd: _notify.quietEnd,
      usualMealHour: _notify.usualMealHour,
    );
    return _record('notify.push');
  }

  @override
  Future<bool> setNotifyMealNudge(bool value) async {
    _notify = NotifySettings(
      push: _notify.push,
      mealNudge: value,
      quietStart: _notify.quietStart,
      quietEnd: _notify.quietEnd,
      usualMealHour: _notify.usualMealHour,
    );
    return _record('notify.mealNudge');
  }

  bool _record(String fieldPath) {
    writes.add(fieldPath);
    if (!_online) pending.add(fieldPath);
    return !_online;
  }

  /// Puts back the settings the app was holding when it closed.
  ///
  /// Not a write path, and deliberately not reachable from a screen: it takes
  /// whole objects, which is exactly what [setPrivacyKey] refuses to do. The
  /// storage layer calls it at launch, before any screen exists, and the
  /// field-path record stays empty because nothing was written — see
  /// `lib/app_state/local_persistence.dart`.
  void restore({PrivacySettings? privacy, NotifySettings? notify}) {
    if (privacy != null) _privacy = privacy;
    if (notify != null) _notify = notify;
  }

  /// Back to the settings a new account opens with. Account deletion calls it.
  void reset() {
    _privacy = PrivacySettings.initial;
    _notify = NotifySettings.initial;
    writes.clear();
    pending.clear();
  }
}

/// Rule 9's **exception boundary**, named so QA does not have to guess.
///
/// §2 rule 9 is "undo, not confirmation" and it is about *logging*. A privacy
/// toggle is not a log: it is instantly reversible by tapping it again, which is
/// already the undo. So [setSwitch] raises no dialog and has no parameter that
/// could produce one.
///
/// Account deletion and blocking are the documented exemptions — destructive and
/// not logging — and both confirm in a **sheet**, never a dialog. The rule-9
/// source guard in `test/product_rules_test.dart` bans confirmation dialogs
/// across `lib/features/`, so that exemption is enforced structurally too.
///
/// That guard reads whole files **without stripping comments** — unlike the
/// rules 3/7/8/11 scanner beside it, which skips comment lines — so this note
/// deliberately does not spell out the two banned Flutter APIs. Documenting the
/// rule would otherwise break it.
class PrivacySettingsService {
  const PrivacySettingsService(this._repository);

  final PrivacyRepository _repository;

  PrivacySettings get current => _repository.settings();

  /// Flips one switch. No confirmation, and re-tapping is the undo.
  Future<SwitchOutcome> setSwitch(PrivacyKey key, bool value) async {
    final queued = await _repository.setPrivacyKey(key, value);
    return SwitchOutcome(
      settings: _repository.settings(),
      queuedLocally: queued,
    );
  }
}
