/// Keeps the published coaches live for the find-a-coach screen. Each coach
/// page already carries her cheapest 28-day price, so there is one listener
/// for everyone. Reads only; nothing here writes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/coaching_repository.dart';
import '../../domain/coach_profile.dart';

enum DirectoryStatus { loading, ready, offline }

class CoachDirectoryController extends ChangeNotifier {
  CoachDirectoryController(this._repository);

  final CoachingRepository _repository;
  StreamSubscription<List<CoachProfile>>? _coachesSub;

  DirectoryStatus _status = DirectoryStatus.loading;
  List<CoachProfile> _coaches = const <CoachProfile>[];
  bool _disposed = false;

  DirectoryStatus get status => _status;
  List<CoachProfile> get coaches => _coaches;

  /// Starts (or restarts, after an offline answer) the streams.
  void start() {
    unawaited(_coachesSub?.cancel());
    _status = DirectoryStatus.loading;
    _changed();
    _coachesSub = _repository.watchPublishedCoaches().listen(
      _onCoaches,
      onError: (Object _) {
        _status = DirectoryStatus.offline;
        _changed();
      },
    );
  }

  void _onCoaches(List<CoachProfile> list) {
    _coaches = list;
    _status = DirectoryStatus.ready;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_coachesSub?.cancel());
    super.dispose();
  }
}
