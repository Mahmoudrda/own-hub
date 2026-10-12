import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/exercise_video_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_media.dart';

class AvailableVideo implements WorkoutVideoRepository {
  String? requested;
  @override
  Uri? urlFor(String assetId) {
    requested = assetId;
    return Uri.parse('file:///synthetic-fixture/demo.mp4');
  }

  @override
  bool isDownloaded(String assetId) => true;
}

void main() {
  testWidgets(
    'F2 an available demo mounts media content, not an empty placeholder',
    (tester) async {
      final videos = AvailableVideo();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: buildTheme(const Locale('en')),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ExerciseVideoView(
            videos: videos,
            move: const PlannedMove(
              exerciseId: 'row',
              name: 'Row',
              prescriptionLabel: '',
              sets: [],
              videoAssetId: 'row-demo',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(videos.requested, 'row-demo');
      final media = tester.widget<AppMedia>(find.byType(AppMedia));
      expect(
        media.child,
        isNotNull,
        reason: 'source-present must mount real media content',
      );
    },
  );
}
