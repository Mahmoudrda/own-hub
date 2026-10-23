import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_application_draft.dart';
import 'package:own_hub/app_state/profile_photo_state.dart' show PhotoSource;
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/data/firestore_coaching_repository.dart'
    show coachDocPath, kCoachDocExtensions;
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_photo.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_widgets.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../support/fixtures.dart';

/// Replays its latest value to each new listener.
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

  Stream<T> watch() => Stream<T>.multi((controller) {
    controller.add(_value);
    final sub = _changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
}

/// A JPEG's first bytes, enough for the type check.
Uint8List jpegBytes([int extra = 8]) => Uint8List.fromList(<int>[
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  ...List<int>.filled(extra, 7),
]);

Uint8List pngBytes() => Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  1,
  2,
  3,
]);

class MemoryPhotoStore implements CoachPhotoStore {
  final Map<String, Uint8List> files = <String, Uint8List>{};
  int deleteAllCalls = 0;
  int _n = 0;

  @override
  Future<String> save(Uint8List bytes, String contentType) async {
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    final marker = 'local:${(++_n).toString().padLeft(24, '0')}.$ext';
    files[marker] = bytes;
    return marker;
  }

  @override
  Future<Uint8List?> read(String marker) async => files[marker];

  @override
  Future<void> delete(String marker) async => files.remove(marker);

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
    files.clear();
  }
}

class FakePicker implements ApplyPhotoPicker {
  FakePicker(this.next);

  PickedPhoto? next;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async => next;
}

/// Just the calls the application makes, recorded. Anything else throws, so a
/// stray call shows up. `failWith` makes the named call throw.
class RecordingRepository implements CoachingRepository {
  RecordingRepository({this.uid = 'u1'});

  @override
  String? uid;

  final List<({String folder, String contentType, int length})> uploads = [];
  final List<Map<String, Object?>> submits = [];
  final Map<String, CoachingFailure> failWith = <String, CoachingFailure>{};
  final Feed<CoachApplication?> application = Feed<CoachApplication?>(null);
  int _n = 0;

  @override
  Stream<CoachApplication?> watchMyApplication() => application.watch();

  @override
  Future<String> uploadCoachDoc(
    CoachDocFolder folder,
    Uint8List bytes,
    String contentType,
  ) async {
    final failure = failWith['uploadCoachDoc'];
    if (failure != null) throw failure;
    uploads.add((
      folder: folder.name,
      contentType: contentType,
      length: bytes.length,
    ));
    return coachDocPath(
      uid: uid!,
      folder: folder,
      token: 'token${++_n}',
      extension: kCoachDocExtensions[contentType] ?? 'bin',
    );
  }

  @override
  Future<({ApplicationStatus status, int round})> submitCoachApplication(
    CoachApplication app, {
    required String locale,
  }) async {
    final failure = failWith['submitCoachApplication'];
    if (failure != null) throw failure;
    submits.add(app.toRequest(locale: locale));
    return (status: ApplicationStatus.submitted, round: 1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The finished application of the fixtures, as a draft holds it: no payout.
CoachApplication draftApplication() => CoachApplication.fromMap(
  completeApplication().toMap(),
  payoutOptional: true,
).copyWith(termsVersion: kCoachTermsVersion);

/// The finished application with every photo a local copy in [store].
Future<CoachApplication> withLocalPhotos(MemoryPhotoStore store) async {
  final base = draftApplication();
  Future<String> photo([bool png = false]) => store.save(
    png ? pngBytes() : jpegBytes(),
    png ? 'image/png' : 'image/jpeg',
  );
  return base.copyWith(
    personal: base.personal.copyWith(photoPath: await photo()),
    certificates: [
      CoachCertificate(
        id: 'cert-1',
        title: base.certificates.first.title,
        issuer: base.certificates.first.issuer,
        year: base.certificates.first.year,
        path: await photo(true),
        mime: 'image/png',
      ),
    ],
    transformations: [
      CoachTransformation(
        beforePath: await photo(),
        afterPath: await photo(),
        weeks: 12,
        note: 'Twelve weeks.',
        clientConsent: true,
      ),
    ],
  );
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  bool reduceMotion = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: child,
    ),
  ),
);

ApplyTools testTools(MemoryPhotoStore store, [ApplyPhotoPicker? picker]) =>
    ApplyTools(picker: picker ?? FakePicker(null), store: store);
