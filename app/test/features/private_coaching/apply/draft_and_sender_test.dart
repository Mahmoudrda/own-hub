import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/coach_application_draft.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_photo.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_sender.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/apply_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = MemoryPhotoStore();
  final draft = CoachApplicationDraft.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    draft.store = store;
    draft.reset();
    store.files.clear();
    store.deleteAllCalls = 0;
  });
  tearDown(() {
    draft.reset();
    draft.store = const FileCoachPhotoStore();
  });

  group('the draft', () {
    test('starts empty and untouched', () {
      expect(draft.touched, isFalse);
      expect(draft.step, 1);
      expect(
        AppSnapshot.capture().containsKey('coachApplicationDraft'),
        isFalse,
      );
    });

    test(
      'round trips through the snapshot, step and all, with no payout',
      () async {
        final app = await withLocalPhotos(store);
        draft.update(app, step: 5);
        final document = jsonEncode(AppSnapshot.capture());
        expect(document.contains('"payout"'), isFalse);

        draft.application; // read once
        draft.reset();
        expect(draft.touched, isFalse);
        store.files.clear();

        AppSnapshot.restore(document);
        expect(draft.touched, isTrue);
        expect(draft.step, 5);
        expect(
          draft.application.personal.displayName,
          app.personal.displayName,
        );
        expect(draft.application.payoutOptional, isTrue);
        expect(draft.application.personal.photoPath, app.personal.photoPath);
        expect(draft.application.certificates.single.mime, 'image/png');
        expect(draft.application.toMap().containsKey('payout'), isFalse);
      },
    );

    test('a damaged section is ignored', () {
      AppSnapshot.restore(
        jsonEncode({'schema': 2, 'coachApplicationDraft': 7}),
      );
      expect(draft.touched, isFalse);
    });

    test('dropping a photo from the draft deletes its copy', () async {
      final app = await withLocalPhotos(store);
      draft.update(app);
      final marker = app.personal.photoPath;
      expect(store.files.containsKey(marker), isTrue);
      draft.update(
        app.copyWith(personal: app.personal.copyWith(photoPath: '')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.files.containsKey(marker), isFalse);
      expect(store.files.length, 3);
    });

    test('Delete everything clears the draft and every photo copy', () async {
      draft.update(await withLocalPhotos(store), step: 3);
      expect(nothingOfHersRemains, isFalse);
      await const ThisPhoneWipe().clearPersistence();
      expect(draft.touched, isFalse);
      expect(draft.step, 1);
      expect(store.deleteAllCalls, greaterThan(0));
      expect(store.files, isEmpty);
      expect(nothingOfHersRemains, isTrue);
    });

    test(
      'seeding from the server keeps its uploaded paths and drops status',
      () {
        final server = CoachApplication.fromMap({
          ...completeApplication2Map(),
          'status': 'needs_changes',
          'reasons': {'personal': 'unclear'},
        });
        draft.seedFrom(server);
        expect(draft.touched, isTrue);
        expect(draft.application.status, isNull);
        expect(draft.application.payoutOptional, isTrue);
        expect(draft.application.personal.photoPath, server.personal.photoPath);
      },
    );

    test('keeps only the step and the application', () {
      expect(draft.toJson().keys, ['step', 'application']);
    });
  });

  group('photos', () {
    test('the type comes from the first bytes, not the name', () {
      expect(sniffImageType(jpegBytes()), 'image/jpeg');
      expect(sniffImageType(pngBytes()), 'image/png');
      expect(sniffImageType(utf8.encode('%PDF-1.4 xxxxxx').toUint8()), isNull);
      expect(
        () => checkPickedPhoto(utf8.encode('GIF89a...').toUint8()),
        throwsA(isA<ApplyPhotoInvalid>()),
      );
      expect(
        () => checkPickedPhoto(jpegBytes(CoachingLimits.uploadMaxBytes)),
        throwsA(isA<ApplyPhotoInvalid>()),
      );
    });
  });

  group('sending', () {
    late RecordingRepository repo;
    setUp(() => repo = RecordingRepository());

    test(
      'uploads each photo to its folder with its type, then submits',
      () async {
        draft.update(await withLocalPhotos(store));
        final progress = <(int, int)>[];
        final sender = ApplicationSender(repository: repo, draft: draft);
        final result = await sender.send(
          locale: 'ar',
          onProgress: (d, t) => progress.add((d, t)),
        );

        expect(result.status, ApplicationStatus.submitted);
        expect(repo.uploads.map((u) => (u.folder, u.contentType)).toList(), [
          ('photo', 'image/jpeg'),
          ('certificates', 'image/png'),
          ('transformations', 'image/jpeg'),
          ('transformations', 'image/jpeg'),
        ]);
        expect(progress.first, (0, 4));
        expect(progress.last, (4, 4));

        final body = repo.submits.single;
        expect(body['locale'], 'ar');
        expect(body.containsKey('payout'), isFalse);
        expect(jsonEncode(body).contains('local:'), isFalse);
        expect(jsonEncode(body).contains('coach-docs/u1/photo/'), isTrue);
        expect(draft.touched, isFalse);
        expect(store.files, isEmpty);
      },
    );

    test(
      'a failed submit keeps the draft; trying again uploads nothing twice',
      () async {
        draft.update(await withLocalPhotos(store));
        repo.failWith['submitCoachApplication'] = const CoachingFailure(
          CoachingRefusal.unreachable,
        );
        final sender = ApplicationSender(repository: repo, draft: draft);
        await expectLater(
          sender.send(locale: 'en'),
          throwsA(
            isA<CoachingFailure>().having(
              (f) => f.refusal,
              'refusal',
              CoachingRefusal.unreachable,
            ),
          ),
        );
        expect(repo.uploads, hasLength(4));
        expect(draft.touched, isTrue);
        expect(coachLocalPhotos(draft.application), isEmpty);

        repo.failWith.clear();
        await sender.send(locale: 'en');
        expect(repo.uploads, hasLength(4));
        expect(repo.submits, hasLength(1));
      },
    );

    test(
      'a failed upload stops before submitting and keeps the rest',
      () async {
        draft.update(await withLocalPhotos(store));
        repo.failWith['uploadCoachDoc'] = const CoachingFailure(
          CoachingRefusal.unreachable,
        );
        await expectLater(
          ApplicationSender(repository: repo, draft: draft).send(locale: 'en'),
          throwsA(isA<CoachingFailure>()),
        );
        expect(repo.submits, isEmpty);
        expect(coachLocalPhotos(draft.application), hasLength(4));
      },
    );

    test('a photo copy that is gone is a refusal, not a crash', () async {
      draft.update(await withLocalPhotos(store));
      store.files.clear();
      await expectLater(
        ApplicationSender(repository: repo, draft: draft).send(locale: 'en'),
        throwsA(
          isA<CoachingFailure>().having(
            (f) => f.refusal,
            'r',
            CoachingRefusal.fileNotUploaded,
          ),
        ),
      );
      expect(repo.submits, isEmpty);
    });

    test('an incomplete draft is never submitted', () async {
      draft.update(draftApplication().copyWith(specialties: []));
      await expectLater(
        ApplicationSender(repository: repo, draft: draft).send(locale: 'en'),
        throwsA(
          isA<CoachingFailure>().having(
            (f) => f.refusal,
            'r',
            CoachingRefusal.applicationIncomplete,
          ),
        ),
      );
      expect(repo.submits, isEmpty);
    });
  });
}

Map<String, Object?> completeApplication2Map() => draftApplication().toMap();

extension on List<int> {
  Uint8List toUint8() => Uint8List.fromList(this);
}
