/// The 2 marketing videos a month a coach makes for Own Hub (Coach Agreement,
/// section 5). The file goes to `coach-docs/{uid}/promo/`, then
/// `add_promo_video` records it; staff approve it or ask for changes. It is
/// never on her public page. Same shape as `check_in.dart`: an interface, a
/// callable-backed one, an in-memory one for tests.
library;

import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../app_state/firebase_boot.dart';
import 'coaching_contract.dart' show CoachingRefusal;
import 'coaching_failure.dart';
import 'parse.dart';

const String kAddPromoVideoCallable = 'add_promo_video';
const String kMyPromoVideosCallable = 'my_promo_videos';

/// What the server and storage.rules accept (`functions/coaching/promo.py`).
const int kPromoTargetPerMonth = 2;
const int kPromoMinSeconds = 30;
const int kPromoMaxSeconds = 180;
const int kPromoMaxBytes = 200 * 1024 * 1024;

enum PromoTopic {
  workoutTip('workout_tip'),
  eatingIdea('eating_idea'),
  trainingMyth('training_myth'),
  howCoachingWorks('how_coaching_works'),
  introduction('introduction');

  const PromoTopic(this.wire);
  final String wire;
}

enum PromoStatus {
  waiting('waiting'),
  approved('approved'),
  changes('changes');

  const PromoStatus(this.wire);
  final String wire;
}

/// Why a picked video cannot be sent, found before anything is uploaded.
enum PromoProblem { tooShort, tooLong, tooBig, unsupported }

class PromoVideoException implements Exception {
  const PromoVideoException(this.problem);
  final PromoProblem problem;

  @override
  String toString() => 'PromoVideoException(${problem.name})';
}

/// The first problem with a video of [seconds] and [bytes] in a file ending
/// [extension] ("mp4", "mov"), or null when it can be sent.
PromoProblem? promoProblem({
  required int seconds,
  required int bytes,
  required String extension,
}) {
  final ext = extension.toLowerCase();
  if (ext != 'mp4' && ext != 'mov') return PromoProblem.unsupported;
  if (bytes <= 0 || bytes > kPromoMaxBytes) return PromoProblem.tooBig;
  if (seconds < kPromoMinSeconds) return PromoProblem.tooShort;
  if (seconds > kPromoMaxSeconds) return PromoProblem.tooLong;
  return null;
}

class PromoVideo {
  const PromoVideo({
    required this.id,
    required this.topic,
    required this.status,
    this.reason = '',
  });

  final String id;
  final PromoTopic? topic;
  final PromoStatus status;

  /// Why staff asked for changes.
  final String reason;

  static PromoVideo? fromWire(Object? raw) {
    final map = asMap(raw);
    final status = PromoStatus.values.where((s) => s.wire == map?['status']);
    if (map == null || status.isEmpty) return null;
    final topic = PromoTopic.values.where((t) => t.wire == map['topic']);
    return PromoVideo(
      id: readString(map['id']),
      topic: topic.isEmpty ? null : topic.first,
      status: status.first,
      reason: readString(map['reason']),
    );
  }
}

/// This month's videos and the count that matters: the approved ones.
class PromoMonth {
  const PromoMonth({
    this.target = kPromoTargetPerMonth,
    this.approved = 0,
    this.items = const <PromoVideo>[],
  });

  final int target;
  final int approved;
  final List<PromoVideo> items;

  bool get done => approved >= target;

  static PromoMonth fromWire(Object? raw) {
    final map = asMap(raw);
    if (map == null) return const PromoMonth();
    final items = map['items'];
    return PromoMonth(
      target: readInt(map['target'], kPromoTargetPerMonth),
      approved: readInt(map['approved']),
      items: <PromoVideo>[
        if (items is List)
          for (final raw in items) ?PromoVideo.fromWire(raw),
      ],
    );
  }
}

abstract class PromoVideoStore {
  /// This month; throws [CoachingFailure] when it cannot be read.
  Future<PromoMonth> month();

  /// Uploads the file at [path] and records it. Throws [PromoVideoException]
  /// for a video the rules will not take and [CoachingFailure] when the
  /// server says no.
  Future<void> send({
    required String path,
    required String extension,
    required PromoTopic topic,
    required int seconds,
  });
}

class PromoVideos {
  PromoVideos._();

  static PromoVideoStore? override;
  static PromoVideoStore get store =>
      override ??
      (FirebaseBoot.isReady
          ? CallablePromoVideoStore()
          : InMemoryPromoVideoStore());
}

/// What `add_promo_video` takes.
Map<String, Object?> promoRequest({
  required String mediaRef,
  required PromoTopic topic,
  required int seconds,
}) => <String, Object?>{
  'mediaRef': mediaRef,
  'topic': topic.wire,
  'durationSeconds': seconds,
};

String promoPath({
  required String uid,
  required String token,
  required String extension,
}) => 'coach-docs/$uid/promo/$token.${extension.toLowerCase()}';

class CallablePromoVideoStore implements PromoVideoStore {
  CallablePromoVideoStore({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    String? Function()? uid,
  }) : _functions = functions ?? FirebaseBoot.functions,
       _storage = storage ?? FirebaseBoot.personalMedia,
       _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final String? Function() _uid;

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Object?>(payload);
      return asMap(result.data) ?? const <String, Object?>{};
    } on FirebaseFunctionsException catch (error) {
      throw CoachingFailure.fromCallable(error.code, error.message);
    }
  }

  @override
  Future<PromoMonth> month() async =>
      PromoMonth.fromWire(await _call(kMyPromoVideosCallable, const {}));

  @override
  Future<void> send({
    required String path,
    required String extension,
    required PromoTopic topic,
    required int seconds,
  }) async {
    final file = File(path);
    final problem = promoProblem(
      seconds: seconds,
      bytes: await file.length(),
      extension: extension,
    );
    if (problem != null) throw PromoVideoException(problem);
    final uid = _uid();
    if (uid == null || uid.isEmpty) {
      throw const CoachingFailure(CoachingRefusal.signedOut);
    }
    final random = Random.secure();
    final token = List<String>.generate(
      24,
      (_) => '0123456789abcdef'[random.nextInt(16)],
    ).join();
    final media = promoPath(uid: uid, token: token, extension: extension);
    try {
      // From the file, not from memory: a 3 minute clip is large.
      await _storage
          .ref(media)
          .putFile(
            file,
            SettableMetadata(
              contentType: extension.toLowerCase() == 'mov'
                  ? 'video/quicktime'
                  : 'video/mp4',
            ),
          );
    } on FirebaseException catch (error) {
      throw CoachingFailure.fromStore(error.code);
    }
    await _call(
      kAddPromoVideoCallable,
      promoRequest(mediaRef: media, topic: topic, seconds: seconds),
    );
  }
}

class InMemoryPromoVideoStore implements PromoVideoStore {
  InMemoryPromoVideoStore({this.current = const PromoMonth()});

  PromoMonth current;
  final List<({PromoTopic topic, int seconds, String path})> sent =
      <({PromoTopic topic, int seconds, String path})>[];

  /// Set to make [send] fail with this.
  Object? failure;

  @override
  Future<PromoMonth> month() async => current;

  @override
  Future<void> send({
    required String path,
    required String extension,
    required PromoTopic topic,
    required int seconds,
  }) async {
    final problem = failure;
    if (problem != null) throw problem;
    sent.add((topic: topic, seconds: seconds, path: path));
    current = PromoMonth(
      target: current.target,
      approved: current.approved,
      items: <PromoVideo>[
        ...current.items,
        PromoVideo(
          id: 'v${sent.length}',
          topic: topic,
          status: PromoStatus.waiting,
        ),
      ],
    );
  }
}
