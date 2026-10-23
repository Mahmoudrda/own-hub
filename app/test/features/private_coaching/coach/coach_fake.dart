import 'dart:async';
import 'dart:typed_data';

import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/portfolio_media.dart';

/// A value that replays its latest state to each new listener.
class Feed<T> {
  Feed(this._value);

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast(
    sync: true,
  );

  set value(T next) {
    _value = next;
    _changes.add(next);
  }

  void fail(Object error) => _changes.addError(error);

  Stream<T> watch() => Stream<T>.multi((controller) {
    controller.add(_value);
    final sub = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = sub.cancel;
  });
}

/// Only what the coach screens use. Everything else is not implemented, so a
/// screen that reaches for it fails loudly.
class CoachRepo implements CoachingRepository {
  @override
  String? uid = 'me';

  final coaches = Feed<List<CoachProfile>>(const <CoachProfile>[]);
  final coachPrivate = Feed<CoachPrivateSummary?>(null);
  final application = Feed<CoachApplication?>(null);
  final packages = <String, Feed<List<CoachPackage>>>{};
  final media = Feed<List<PortfolioMedia>>(const <PortfolioMedia>[]);
  final prices = Feed<Map<String, int>>(const <String, int>{});

  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  final Map<String, CoachingFailure> failWith = <String, CoachingFailure>{};
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];
  final List<String> uploads = <String>[];

  List<String> get callNames => <String>[for (final c in calls) c.$1];

  void _record(String name, [Map<String, Object?> args = const {}]) {
    calls.add((name, args));
    final failure = failWith[name];
    if (failure != null) throw failure;
  }

  @override
  Stream<CoachProfile?> watchCoach(String coachUid) => coaches.watch().map(
    (list) => list.where((c) => c.uid == coachUid).firstOrNull,
  );

  @override
  Stream<CoachPrivateSummary?> watchCoachPrivate() => coachPrivate.watch();

  @override
  Stream<Map<String, int>> watchMyPackagePrices() => prices.watch();

  @override
  Stream<CoachApplication?> watchMyApplication() => application.watch();

  @override
  Stream<List<CoachPackage>> watchPackages(
    String coachUid, {
    bool onlyActive = true,
  }) => packages
      .putIfAbsent(coachUid, () => Feed<List<CoachPackage>>(const []))
      .watch()
      .map(
        (l) => <CoachPackage>[
          for (final p in l)
            if (!onlyActive || p.active) p,
        ],
      );

  @override
  Future<void> updateCoachProfile({
    String? headline,
    String? approachText,
    String? photoPath,
    bool? acceptingClients,
    bool? autoAccept,
    int? maxActiveClients,
  }) async {
    final sent = <String, Object?>{
      'headline': ?headline,
      'approachText': ?approachText,
      'photoPath': ?photoPath,
      'acceptingClients': ?acceptingClients,
      'autoAccept': ?autoAccept,
      'maxActiveClients': ?maxActiveClients,
    };
    updates.add(sent);
    _record('updateCoachProfile', sent);
  }

  @override
  Future<({String packageId, int priceFinalEgp, int youReceiveEgp})>
  saveCoachPackage(PackageDraft draft) async {
    _record('saveCoachPackage', draft.toRequest());
    return (
      packageId: draft.packageId ?? 'pkg1',
      priceFinalEgp: draft.priceFinalEgp,
      youReceiveEgp: draft.youReceiveEgp,
    );
  }

  @override
  Future<String> uploadCoachDoc(
    CoachDocFolder folder,
    Uint8List bytes,
    String contentType,
  ) async {
    uploads.add('${folder.name}:$contentType');
    return folder == CoachDocFolder.photo
        ? 'coach-docs/me/photo/new.png'
        : 'coach-docs/me/${folder.name}/f${uploads.length}.jpg';
  }

  @override
  Stream<List<PortfolioMedia>> watchMyPortfolioMedia() => media.watch();

  @override
  Future<String> addPortfolioMedia(MediaDraft draft) async {
    _record('addPortfolioMedia', draft.toRequest());
    return 'media1';
  }

  @override
  Future<void> removePortfolioMedia(String mediaId) async =>
      _record('removePortfolioMedia', {'mediaId': mediaId});

  @override
  Future<void> confirmMediaConsent(String mediaId) async =>
      _record('confirmMediaConsent', {'mediaId': mediaId});

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
