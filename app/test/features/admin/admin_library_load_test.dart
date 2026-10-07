// The console's first read: her book's sections, for placing a recipe, and
// the library as the server holds it, laid over the bundled seed. Once a run.
//
// A plain test, not a widget test: the read goes through the asset bundle,
// and real asset I/O never completes inside a widget test's fake clock.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_documents.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/media_bundle.dart';
import 'package:own_hub/routing/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the sections and the server library arrive, once', () async {
    final docs = InMemoryContentDocuments()
      ..docs['foods/feteer'] = {
        'foodId': 'feteer',
        'name_en': 'Feteer',
        'name_ar': 'fetir',
        'portions': ['slice'],
        'kcal': 300,
        'proteinG': 6,
        'carbsG': 30,
        'fatG': 17,
        'allergens': ['gluten', 'dairy'],
        'dietTags': ['vegetarian'],
      }
      // What tools/upload_media.py registers.
      ..docs['mediaLibrary/recipes__om_ali__om_ali.webp'] = {
        'collection': 'recipes',
        'docId': 'om_ali',
        'name': 'om_ali.webp',
        'path': 'content/recipes/om_ali/om_ali.webp',
        'kind': 'picture',
        'bytes': 41000,
      }
      ..docs['mediaLibrary/exercises__glute_bridge__bridge.mp4'] = {
        'name': 'bridge.mp4',
        'kind': 'video',
        'bytes': 900000,
      };
    AppRouter.contentDocumentsOverride = docs;
    addTearDown(() => AppRouter.contentDocumentsOverride = null);

    final first = AppRouter.ensureAdminLibraryLoaded();
    expect(identical(first, AppRouter.ensureAdminLibraryLoaded()), isTrue);
    await first;

    expect(AppRouter.adminRecipeSections, isNotEmpty);
    final row = AppRouter.contentRepository
        .rowsNow(ContentCollection.foods)
        .firstWhere((r) => r.id == 'feteer');
    expect(row.value('allergens'), 'gluten|dairy');
    expect(row.value('kcal'), '300');

    // The media library lists every uploaded file, ready to be chosen.
    expect(AppRouter.adminMediaBundle.names, {'om_ali.webp', 'bridge.mp4'});
    expect(
      AppRouter.adminMediaBundle.ofKind(MediaKind.video).single.name,
      'bridge.mp4',
    );
  });
}
