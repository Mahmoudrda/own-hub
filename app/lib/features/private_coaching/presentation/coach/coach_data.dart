/// What the coach's screens read: her coach page, her packages, whether she is
/// suspended and what she was approved on. One set of listeners, shared by the
/// coach space and the screens it opens.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/coaching_repository.dart';
import '../../domain/coach_application.dart';
import '../../domain/coach_money.dart';
import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/portfolio_media.dart';

class CoachSpaceData extends ChangeNotifier {
  CoachSpaceData(this.repository) {
    _start();
  }

  final CoachingRepository repository;

  CoachProfile? profile;
  CoachPrivateSummary? private;
  CoachApplication? application;
  List<CoachPackage> packages = const <CoachPackage>[];

  /// Her photos and results. Kept apart from the four above: a failure here
  /// must not hide the rest of her space.
  List<PortfolioMedia> media = const <PortfolioMedia>[];
  CoachingFailure? mediaFailure;

  /// Her own price for each package, by package id. Empty until it arrives;
  /// the package form falls back to working it back from the final price.
  Map<String, int> prices = const <String, int>{};

  CoachingFailure? failure;
  final Set<String> _got = <String>{};
  final List<StreamSubscription<Object?>> _subs =
      <StreamSubscription<Object?>>[];
  bool _disposed = false;

  static const int _streams = 4;

  /// No answer yet from every stream, and no failure to show instead.
  bool get loading => failure == null && _got.length < _streams;

  bool get suspended => private?.suspended ?? false;

  /// She has a coach page (an approved coach).
  bool get isCoach => profile != null;

  void _start() {
    final uid = repository.uid;
    if (uid == null) {
      failure = const CoachingFailure(CoachingRefusal.signedOut);
      return;
    }
    _listen<CoachProfile?>('profile', repository.watchCoach(uid), (v) {
      profile = v;
    });
    _listen<CoachPrivateSummary?>('private', repository.watchCoachPrivate(), (
      v,
    ) {
      private = v;
    });
    _listen<CoachApplication?>('application', repository.watchMyApplication(), (
      v,
    ) {
      application = v;
    });
    _subs.add(
      repository.watchMyPortfolioMedia().listen(
        (value) {
          media = value;
          mediaFailure = null;
          _changed();
        },
        onError: (Object error) {
          mediaFailure = error is CoachingFailure
              ? error
              : const CoachingFailure(CoachingRefusal.unknown);
          _changed();
        },
      ),
    );
    _subs.add(
      repository.watchMyPackagePrices().listen((value) {
        prices = value;
        _changed();
      }, onError: (Object _) {}),
    );
    _listen<List<CoachPackage>>(
      'packages',
      repository.watchPackages(uid, onlyActive: false),
      (v) {
        packages = v;
      },
    );
  }

  void _listen<T>(String key, Stream<T> stream, void Function(T) assign) {
    _subs.add(
      stream.listen(
        (value) {
          assign(value);
          _got.add(key);
          failure = null;
          _changed();
        },
        onError: (Object error) {
          failure = error is CoachingFailure
              ? error
              : const CoachingFailure(CoachingRefusal.unknown);
          _changed();
        },
      ),
    );
  }

  /// Starts the listeners again after a failure.
  void retry() {
    _cancel();
    _got.clear();
    failure = null;
    mediaFailure = null;
    _changed();
    _start();
  }

  void _cancel() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    super.dispose();
  }
}
