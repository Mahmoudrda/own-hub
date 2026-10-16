/// "Nobody has told us yet" is not "she has nothing", and the app used to say
/// them with the same silence.
///
/// Every repository in this app answers a read synchronously, out of memory,
/// and an empty store and an unread store look identical from the outside. Two
/// screens turn that silence into a sentence: `T06` says **"Day one"** and
/// `E09` says **"Eat, day one"**. Both are confident, both are branches chosen
/// by `isEmpty`, and neither has any way of knowing whether anything has
/// looked.
///
/// Today nothing can look except the phone, and `main()` awaits
/// `LocalPersistence.load()` before `runApp`, so the first frame is already
/// drawn from an answered store. That stops being true the moment
/// `CloudStore._link` runs: it is started before the first frame and
/// deliberately not awaited, it pulls her documents over the network, and it
/// merges them in whenever they arrive. A woman two months into training who
/// signs in on a new handset therefore has an empty store and a full cloud, and
/// for as long as the pull takes, Home tells her she is starting over.
///
/// That is the failure this file exists to prevent: not a missing spinner, a
/// confident wrong answer.
///
/// ## The shape: one tri-state, asked of the repository
///
/// [DataState] has three values where there were two, and the rule for
/// producing one is one line, in [dataStateOf]:
///
///   * A store holding something is **[DataState.hasData]**, always and
///     immediately. A pull can only add to it, so "she has something" is never
///     the answer that turns out to be wrong, and nothing of hers is ever
///     hidden behind a wait.
///   * A store holding nothing is **[DataState.empty]** once everything that
///     was going to answer has answered, and **[DataState.unknown]** until
///     then. Only the empty answer can be a lie, so only the empty answer
///     waits.
///
/// So no screen needs a spinner, no repository needs an async read, and the
/// 53 screens that never claim emptiness need no change at all. The two that do
/// ask their repository one question and hold their tongue on `unknown`.
///
/// ## What counts as an answer
///
/// [expect] is called by a source that is going to speak and has not yet;
/// [answered] when it has, whether it spoke, refused or failed. The count
/// starts at zero, which is what makes this invisible to every widget test and
/// to the app as it ships: with no Firebase there is no pull, nothing is
/// expected, and `empty` means empty from the first frame exactly as before.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_state/app_changes.dart';

/// What a store can honestly say about itself.
enum DataState {
  /// Nothing has answered yet. **Not** "she has nothing": nobody has looked.
  unknown,

  /// Everything that was going to answer has, and she has nothing here.
  empty,

  /// She has something here. Never in doubt, whatever is still in flight.
  hasData,
}

/// The one rule, so that no repository writes its own version of it.
DataState dataStateOf({required bool holdsNothing}) =>
    holdsNothing ? PendingAnswers.ifEmpty : DataState.hasData;

/// The reads a screen may still be waiting on.
abstract final class PendingAnswers {
  /// How long a source gets before the app answers out of what it has.
  ///
  /// A quiet screen that never resolves is its own kind of broken, and a pull
  /// can hang for as long as the network lets it — Firestore does not time a
  /// read out on its own. Five seconds is longer than a pull that is going to
  /// succeed and short enough that nobody sits in front of a held tongue.
  /// After it, "nothing here yet" is the most honest thing the app can say,
  /// because by then it is.
  static const Duration deadline = Duration(seconds: 5);

  static int _waiting = 0;
  static Timer? _deadline;

  /// True when nothing is still expected to speak.
  static bool get settled => _waiting == 0;

  /// How many sources are still expected. Nothing renders it; it is for tests.
  @visibleForTesting
  static int get waiting => _waiting;

  /// What a store holding nothing may call itself right now.
  static DataState get ifEmpty => settled ? DataState.empty : DataState.unknown;

  /// A source is going to answer and has not yet.
  ///
  /// Call it **before** the frame in which the screen would otherwise claim
  /// emptiness, or the claim is made and then withdrawn, which is the flicker
  /// this whole file is about.
  static void expect() {
    _waiting++;
    _deadline ??= Timer(deadline, _giveUp);
  }

  /// A source has answered, refused, or failed. All three are answers.
  static void answered() {
    if (_waiting == 0) return;
    _waiting--;
    if (!settled) return;
    _stopWaiting();
    // Every screen that was holding its tongue now has something to say.
    AppChanges.bump();
  }

  /// Nothing answered in time.
  ///
  /// Every outstanding source is written off at once rather than one at a time:
  /// the deadline is about how long a woman is left looking at a screen that
  /// will not say anything, and that clock does not restart per source.
  static void _giveUp() {
    if (settled) return;
    _waiting = 0;
    _stopWaiting();
    AppChanges.bump();
  }

  static void _stopWaiting() {
    _deadline?.cancel();
    _deadline = null;
  }

  /// Back to expecting nothing. Tests only.
  @visibleForTesting
  static void reset() {
    _waiting = 0;
    _stopWaiting();
  }
}
