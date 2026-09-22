/// One signal for "something shared changed".
///
/// The router draws most screens from shared, in-memory state that it reads
/// at build time. Without a signal, a screen underneath another keeps what it
/// drew when it was opened: log a check-in on Y04, go back, and Y03 still
/// shows the morning without it. Every routed screen listens to this and
/// redraws when it fires, so "back" always lands on the truth.
///
/// Call [AppChanges.bump] after changing shared state — from a callback,
/// never while a widget is building.
library;

import 'package:flutter/foundation.dart';

class AppChanges extends ChangeNotifier {
  AppChanges._();

  static final AppChanges instance = AppChanges._();

  /// Tell every open screen that shared state has changed.
  static void bump() => instance.notifyListeners();
}
