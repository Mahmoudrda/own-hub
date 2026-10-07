// The owner's operations through the REAL router: Z01 -> Z15 dashboard, Z16
// logs, Z17 events -> Z18, a recipe saved from Z12 into the library, and the
// one door into the console from her profile.
//
// The widget tests prove each screen draws what it is handed. These prove the
// router hands them the right thing and that every save lands in a store a
// test can read, rather than in a callback nothing keeps.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/admin/domain/console_report.dart';
import 'package:own_hub/features/admin/domain/console_source.dart';
import 'package:own_hub/features/admin/domain/content_documents.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/events/domain/event_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _app(String screenId) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
  initialRoute: appRoutes[screenId]!.name,
);

class _Console implements ConsoleSource {
  int dashboards = 0;
  final List<ConsoleLogKind> logKinds = [];

  @override
  Future<ConsoleDashboard> dashboard({bool refresh = false}) async {
    dashboards++;
    return ConsoleDashboard.fromJson(const {
      'generatedAt': '2026-10-07T12:00:00+00:00',
      'members': {'total': 42, 'verified': 40},
    });
  }

  @override
  Future<ConsoleLogPage> logs(
    ConsoleLogKind kind, {
    String? before,
    String? outcome,
  }) async {
    logKinds.add(kind);
    return ConsoleLogPage(kind: kind);
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String value) async {
  final semantics = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );
  expect(semantics, findsOneWidget, reason: 'no field labelled "$label"');
  final field = find.descendant(
    of: semantics,
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  // A recipe save reads the bundled seed for its version and sections. Read
  // here, on the real clock: asset I/O never finishes on a widget test's
  // fake one.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppRouter.seedRecipesJson();
  });

  final savedFlags = AppRouter.featureFlags;
  late _Console console;
  late InMemoryEvents events;
  late InMemoryContentDocuments docs;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    console = _Console();
    events = InMemoryEvents();
    docs = InMemoryContentDocuments();
    AppRouter.consoleSourceOverride = console;
    AppRouter.eventAdminStoreOverride = events;
    AppRouter.contentDocumentsOverride = docs;
    AppRouter.adminEditingEvent = null;
    AppRouter.adminEditingRow = const <String, String>{};
    final seed = jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map;
    AppRouter.adminRecipeSections = [
      for (final s in seed['sections'] as List)
        ((s as Map)['sectionId'] as String, s['titleEn'] as String),
    ];
  });
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.consoleSourceOverride = null;
    AppRouter.eventAdminStoreOverride = null;
    AppRouter.contentDocumentsOverride = null;
    AppRouter.adminEditingEvent = null;
    AppRouter.adminEditingRow = const <String, String>{};
  });

  testWidgets('Z01 leads to the dashboard, which reads the console', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app('Z01'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Dashboard'));
    expect(console.dashboards, 1);
    expect(find.text('42'), findsOneWidget);

    await _tap(tester, find.text('Logs'));
    expect(console.logKinds, [ConsoleLogKind.decisions]);
    expect(find.text('Nothing logged yet'), findsOneWidget);
  });

  testWidgets('Z01 -> Z17 -> Z18: a new event is stored and listed', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app('Z01'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Events'));
    expect(find.text('No events yet'), findsOneWidget);

    await _tap(tester, find.text('Add an event'));
    await _type(tester, 'Title (English)', 'Morning stretch');
    await _type(tester, 'Title (Arabic)', 'tamaddud');
    await _type(tester, 'Starts, Cairo time', '2026-11-05 18:30');
    await _type(tester, 'Ends, Cairo time', '2026-11-05 19:30');
    await _type(
      tester,
      'Link, starting with https://',
      'https://meet.example.com/x',
    );
    await _tap(tester, find.text('Publish'));

    expect(events.events.values.single.status, EventStatus.published);
    // Back on Z17, which read its list again after the save.
    expect(find.text('Morning stretch'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('Z06 -> Z12: a recipe saved from the console is in the library '
      'the member app reads', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app('Z12'));
    await tester.pumpAndSettle();

    await _type(tester, 'Recipe id', 'om_ali_journey');
    await _type(tester, 'Name (English)', 'Om Ali');
    await _type(tester, 'Name (Arabic)', 'om ali ar');
    await _type(tester, 'Minutes', '45');
    await _type(tester, 'Ingredients', 'pastry|milk|nuts');
    await _type(tester, 'Allergens', 'nuts|dairy');
    await _type(tester, 'Diet tags', 'vegetarian');
    await _type(tester, 'Author', 'content_team');
    await _type(tester, 'Allergens checked by', 'qa_reviewer');

    // The sections come from her book, loaded when the console first opens
    // (admin_library_load_test.dart proves the load; a widget test cannot
    // wait on real asset I/O).
    final section = AppRouter.adminRecipeSections;
    expect(section, isNotEmpty);
    await _tap(tester, find.text(section.first.$2));
    await _type(tester, 'Method, one step a line, in Arabic', 'one\ntwo');
    await _tap(tester, find.text('Show this recipe to members'));
    await _tap(tester, find.text('Save'));

    final doc = docs.docs['recipes/om_ali_journey'];
    expect(doc, isNotNull, reason: 'nothing reached the library');
    expect(doc!['status'], 'review');
    expect(doc['sectionId'], section.first.$1);
    expect(docs.docs['meta/recipes'], isNotNull);
    expect(
      AppRouter.contentRepository
          .rowsNow(ContentCollection.recipes)
          .any((r) => r.id == 'om_ali_journey'),
      isTrue,
    );
  });

  group('the door from her profile', () {
    testWidgets('absent while the console is switched off', (tester) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.adminConsole: false,
      });
      await tester.pumpWidget(_app('A02'));
      await tester.pumpAndSettle();
      expect(find.text('Admin console'), findsNothing);
      expect(AppRouter.adminConsoleOffered, isFalse);
    });

    testWidgets('present in a build that carries it, and opens Z01', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app('A02'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Admin console'));
      expect(find.text('Content library'), findsWidgets);
    });
  });
}
