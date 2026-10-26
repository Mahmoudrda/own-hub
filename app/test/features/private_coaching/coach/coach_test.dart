import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/pricing.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_text.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_validation.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_toggle.dart';

import 'coach_fake.dart';
import '../support/fixtures.dart';

CoachProfile _me({bool published = true, bool accepting = true}) =>
    CoachProfile(
      uid: 'me',
      displayName: 'Coach Sara',
      headline: 'Strength coach for busy women',
      approach:
          'I build a simple plan around your week and adjust it with you as '
          'you go.',
      published: published,
      acceptingClients: accepting,
    );

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: child,
);

Future<void> _open(
  WidgetTester tester,
  CoachRepo repo, {
  Locale locale = const Locale('en'),
  double scale = 1,
  VoidCallback? onInviteClient,
  void Function(String coachUid)? onShareProfile,
}) async {
  tester.view.physicalSize = const Size(390, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _host(
      CoachSpaceView(
        repository: repo,
        onPreviewPortfolio: (_) {},
        onOpenDashboard: () {},
        onOpenChats: () {},
        onInviteClient: onInviteClient,
        onShareProfile: onShareProfile,
      ),
      locale: locale,
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _numberField() => find.byWidgetPredicate(
  (w) => w is TextField && w.keyboardType == TextInputType.number,
);

void main() {
  test('the media refusals have their own words in both languages', () {
    for (final l10n in <AppL10n>[AppL10nEn(), AppL10nAr()]) {
      final generic = coachFailureText(
        l10n,
        const CoachingFailure(CoachingRefusal.unknown),
      );
      for (final refusal in [
        CoachingRefusal.mediaNotFound,
        CoachingRefusal.tooManyMedia,
      ]) {
        expect(
          coachFailureText(l10n, CoachingFailure(refusal)),
          isNot(generic),
        );
      }
    }
  });

  group('rules the forms check', () {
    test('portfolio lengths match the server', () {
      expect(
        portfolioProblems(headline: 'too short', approach: 'x' * 50),
        <String>['headline'],
      );
      expect(
        portfolioProblems(headline: 'x' * 10, approach: 'x' * 49),
        <String>['approach'],
      );
      expect(
        portfolioProblems(headline: 'x' * 121, approach: 'x' * 1501),
        <String>['headline', 'approach'],
      );
      expect(
        portfolioProblems(headline: 'x' * 120, approach: 'x' * 1500),
        isEmpty,
      );
    });

    PackageDraft ok() => PackageDraft(
      title: 'Four weeks',
      description: 'A plan made for you with live video sessions.',
      includes: const <String>['A plan', 'Live sessions'],
      coachPriceEgp: 1000,
    );

    test('a good package has no problems', () {
      expect(packageProblems(ok()), isEmpty);
    });

    test('rules stricter than PackageDraft.problems', () {
      PackageDraft with_({
        String? title,
        String? description,
        List<String>? includes,
        int? price,
      }) => PackageDraft(
        title: title ?? ok().title,
        description: description ?? ok().description,
        includes: includes ?? ok().includes,
        coachPriceEgp: price ?? 1000,
      );
      expect(packageProblems(with_(title: 'ab')), contains('title'));
      expect(packageProblems(with_(description: 'short')), ['description']);
      expect(packageProblems(with_(includes: const [])), ['includes']);
      expect(packageProblems(with_(includes: const ['a'])), ['includes']);
      expect(
        packageProblems(with_(includes: List.filled(9, 'ab'))),
        contains('includes'),
      );
      expect(packageProblems(with_(price: 199)), ['coachPriceEgp']);
      expect(packageProblems(with_(price: 30001)), ['coachPriceEgp']);
    });

    test('the final price and its inverse follow the contract vectors', () {
      final vectors = jsonDecode(
        File('../contracts/coaching_price_vectors.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final row
          in (vectors['vectors'] as List).cast<Map<String, dynamic>>()) {
        final coach = row['coach'] as int;
        final fin = row['final'] as int;
        expect(PackageDraft(coachPriceEgp: coach).priceFinalEgp, fin);
        expect(coachPriceFromFinal(fin), coach, reason: 'final $fin');
      }
      expect(coachPriceFromFinal(0), isNull);
      expect(coachPriceFromFinal(234), isNull, reason: 'no price gives 234');
      expect(finalPrice(1000), 1150);
    });
  });

  group('coach space', () {
    testWidgets('shows her, the live state and the dashboard counts', (
      tester,
    ) async {
      final repo = CoachRepo()
        ..coaches.value = [_me()]
        ..packages['me'] = Feed<List<CoachPackage>>([package('a')]);
      await _open(tester, repo);
      expect(find.text('Coach Sara'), findsOneWidget);
      expect(find.text('Your portfolio is live'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('0 new requests'), findsOneWidget);
      expect(find.text('0 unread chats'), findsOneWidget);
      expect(find.text('0 clients'), findsOneWidget);
      expect(find.text('My portfolio'), findsOneWidget);
      expect(find.text('My packages'), findsOneWidget);
      expect(find.text('Preview my portfolio'), findsOneWidget);
      expect(find.text('My application'), findsOneWidget);
      expect(
        find.text(
          'Members can ask to join your packages. Coaching is free until Own '
          'Hub opens payments.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Booking and payments'), findsNothing);
    });

    testWidgets('says to turn a package on while not published', (
      tester,
    ) async {
      final repo = CoachRepo()
        ..coaches.value = [_me(published: false)]
        ..packages['me'] = Feed<List<CoachPackage>>([package('a')]);
      await _open(tester, repo);
      expect(find.text('Your portfolio is not live yet'), findsOneWidget);
      expect(
        find.text('Turn on one package and members can see your portfolio.'),
        findsOneWidget,
      );
    });

    testWidgets('with no active package she is not visible and cannot accept', (
      tester,
    ) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      await _open(tester, repo);
      expect(find.text('Your portfolio is live'), findsNothing);
      expect(find.text('Not visible yet: add a package'), findsWidgets);
      expect(tester.widget<AppToggle>(find.byType(AppToggle)).value, isFalse);
      await tester.tap(find.text('Accepting new clients'));
      await tester.pumpAndSettle();
      expect(repo.updates, isEmpty);
    });

    testWidgets('the accepting switch saves only that field', (tester) async {
      final repo = CoachRepo()
        ..coaches.value = [_me()]
        ..packages['me'] = Feed<List<CoachPackage>>([package('a')]);
      await _open(tester, repo);
      await tester.tap(find.text('Accepting new clients'));
      await tester.pumpAndSettle();
      expect(repo.updates, [
        {'acceptingClients': false},
      ]);
    });

    testWidgets('a refused switch says why and puts it back', (tester) async {
      final repo = CoachRepo()
        ..coaches.value = [_me()]
        ..packages['me'] = Feed<List<CoachPackage>>([package('a')])
        ..failWith['updateCoachProfile'] = const CoachingFailure(
          CoachingRefusal.unreachable,
        );
      await _open(tester, repo);
      await tester.tap(find.text('Accepting new clients'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'We could not reach Own Hub. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<AppToggle>(find.byType(AppToggle)).value, isTrue);
    });

    testWidgets('a suspended coach sees one calm message and nothing to edit', (
      tester,
    ) async {
      final repo = CoachRepo()
        ..coaches.value = [_me()]
        ..coachPrivate.value = const CoachPrivateSummary(suspended: true);
      await _open(tester, repo);
      expect(find.text('Your coach space is paused'), findsOneWidget);
      expect(find.text('My portfolio'), findsNothing);
      expect(find.text('My packages'), findsNothing);
      expect(find.byType(AppToggle), findsNothing);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('someone who is not approved sees that it is not ready', (
      tester,
    ) async {
      final repo = CoachRepo();
      await _open(tester, repo);
      expect(find.text('Your coach space is not ready yet'), findsOneWidget);
      expect(find.text('My portfolio'), findsNothing);
    });

    testWidgets('offline shows a message and a retry that reconnects', (
      tester,
    ) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      tester.view.physicalSize = const Size(390, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(CoachSpaceView(repository: repo)));
      repo.coaches.fail(const CoachingFailure(CoachingRefusal.unreachable));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Coach Sara'), findsOneWidget);
    });

    testWidgets('K18 offers Invite a client first and calls back once', (
      tester,
    ) async {
      final repo = CoachRepo()
        ..coaches.value = [_me()]
        ..packages['me'] = Feed<List<CoachPackage>>([package('a')]);
      var taps = 0;
      await _open(tester, repo, onInviteClient: () => taps++);
      expect(find.text('Invite a client'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Invite a client')).dy,
        lessThan(tester.getTopLeft(find.text('My portfolio')).dy),
      );
      await tester.tap(find.text('Invite a client'));
      expect(taps, 1);

      await _open(tester, repo);
      expect(find.text('Invite a client'), findsNothing);
    });

    testWidgets(
      'K18 shows Share my profile link only when live, and passes her uid',
      (tester) async {
        final repo = CoachRepo()
          ..coaches.value = [_me()]
          ..packages['me'] = Feed<List<CoachPackage>>([package('a')]);
        String? got;
        await _open(tester, repo, onShareProfile: (u) => got = u);
        expect(find.text('Share my profile link'), findsOneWidget);
        await tester.tap(find.text('Share my profile link'));
        expect(got, 'me');

        repo.coaches.value = [_me(published: false)];
        await _open(tester, repo, onShareProfile: (u) => got = u);
        expect(find.text('Share my profile link'), findsNothing);
      },
    );
  });

  group('portfolio', () {
    Future<CoachRepo> openPortfolio(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      double scale = 1,
    }) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      await _open(tester, repo, locale: locale, scale: scale);
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('save is off until something changes, then sends only that', (
      tester,
    ) async {
      final repo = await openPortfolio(tester);
      expect(find.text('Save changes'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.updates, isEmpty);

      await tester.enterText(
        find.byType(TextField).at(0),
        'Strength coaching for busy women',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.updates, [
        {'headline': 'Strength coaching for busy women'},
      ]);
      expect(find.text('Your portfolio is saved.'), findsOneWidget);
      expect(find.widgetWithText(SnackBar, 'Saved'), findsOneWidget);
    });

    testWidgets('a headline that is too short is not sent', (tester) async {
      final repo = await openPortfolio(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Short');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.updates, isEmpty);
      expect(find.text('Use 10 to 120 characters.'), findsWidgets);
    });

    testWidgets('auto-accept and the client limit are live and sent', (
      tester,
    ) async {
      final repo = await openPortfolio(tester);
      await tester.tap(find.text('Accept requests automatically'));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.updates, [
        {'autoAccept': true, 'maxActiveClients': 16},
      ]);
    });

    testWidgets('a new photo is uploaded as a coach photo, then attached', (
      tester,
    ) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      tester.view.physicalSize = const Size(390, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          CoachSpaceView(
            repository: repo,
            photoChooser: (_) async => Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a photo'));
      await tester.pumpAndSettle();
      expect(repo.uploads, ['photo:image/png']);
      expect(repo.updates, [
        {'photoPath': 'coach-docs/me/photo/new.png'},
      ]);
      expect(find.text('Your photo is saved.'), findsOneWidget);
    });
  });

  group('packages', () {
    Future<CoachRepo> openPackages(
      WidgetTester tester, {
      List<CoachPackage> existing = const [],
      Locale locale = const Locale('en'),
      double scale = 1,
    }) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      repo.packages['me'] = Feed<List<CoachPackage>>(existing);
      await _open(tester, repo, locale: locale, scale: scale);
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('empty: invites her to start from a template', (tester) async {
      await openPackages(tester);
      expect(find.text('No packages yet'), findsOneWidget);
      expect(find.text('Add a package'), findsOneWidget);
    });

    testWidgets('lists hers with the price members see and a switch hint', (
      tester,
    ) async {
      await openPackages(
        tester,
        existing: [package('a', price: 1150, active: false)],
      );
      expect(find.text('Package a'), findsOneWidget);
      expect(
        find.textContaining('EGP 1,150 when payments open'),
        findsOneWidget,
      );
      expect(find.text('Off'), findsOneWidget);
      expect(
        find.text(
          'Turn on at least one package to show your portfolio to members.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with payments off her list says one thing about price', (
      tester,
    ) async {
      await openPackages(tester, existing: [package('a', price: 2000)]);
      expect(
        find.textContaining(
          'Free for members until payments open · EGP 2,000 when payments open · 28 days',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Members see EGP'), findsNothing);
    });

    testWidgets('six packages: no more to add', (tester) async {
      await openPackages(
        tester,
        existing: [for (var i = 0; i < 6; i++) package('p$i')],
      );
      expect(find.text('Add a package'), findsNothing);
      expect(find.text('You have all 6 packages.'), findsOneWidget);
    });

    testWidgets('a template, a price and Save send the right fields', (
      tester,
    ) async {
      final repo = await openPackages(tester);
      await tester.tap(find.text('Add a package'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 weeks, 2 live sessions a month'));
      await tester.pumpAndSettle();
      await tester.enterText(_numberField(), '1000');
      await tester.pumpAndSettle();
      expect(find.text('Members see EGP 1,150'), findsWidgets);

      await tester.tap(find.text('Save package'));
      await tester.pumpAndSettle();

      final call = repo.calls.singleWhere((c) => c.$1 == 'saveCoachPackage').$2;
      expect(call['title'], '4 weeks of coaching with me');
      expect(call['durationDays'], 28);
      expect(call['liveSessionsPerMonth'], 2);
      expect(call['sessionMinutes'], 30);
      expect(call['coachPriceEgp'], 1000);
      expect(call['active'], isTrue);
      expect(call['order'], 0);
      expect((call['includes']! as List).length, 3);
      expect(call.containsKey('packageId'), isFalse);
      expect(find.text('Saved. You receive EGP 1,000.'), findsOneWidget);
      expect(find.widgetWithText(SnackBar, 'Saved'), findsOneWidget);
    });

    testWidgets('a price out of range is not sent', (tester) async {
      final repo = await openPackages(tester);
      await tester.tap(find.text('Add a package'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 weeks, 4 live sessions a month'));
      await tester.enterText(_numberField(), '150');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save package'));
      await tester.pumpAndSettle();
      expect(repo.callNames, isNot(contains('saveCoachPackage')));
      expect(find.text('Whole pounds, from 200 to 30,000.'), findsWidgets);
      expect(find.textContaining('Members see EGP'), findsNothing);
    });

    testWidgets('editing brings her own price back from the final one', (
      tester,
    ) async {
      final repo = await openPackages(
        tester,
        existing: [package('a', price: 1150)],
      );
      await tester.tap(find.text('Package a'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_numberField()).controller!.text, '1000');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Updated words for the package that are long enough.',
      );
      await tester.tap(find.text('Add a line'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), 'A plan for you');
      await tester.tap(find.text('Save package'));
      await tester.pumpAndSettle();
      final call = repo.calls.singleWhere((c) => c.$1 == 'saveCoachPackage').$2;
      expect(call['packageId'], 'a');
      expect(call['coachPriceEgp'], 1000);
    });

    testWidgets('editing shows the price she saved, not one worked back', (
      tester,
    ) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      repo.packages['me'] = Feed<List<CoachPackage>>([
        package('a', price: 1000),
      ]);
      repo.prices.value = {'a': 870};
      await _open(tester, repo);
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Package a'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_numberField()).controller!.text, '870');
    });

    testWidgets('a price that arrives late fills the field until she types', (
      tester,
    ) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      repo.packages['me'] = Feed<List<CoachPackage>>([
        package('a', price: 1000),
      ]);
      await _open(tester, repo);
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Package a'));
      await tester.pumpAndSettle();
      repo.prices.value = {'a': 870};
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_numberField()).controller!.text, '870');
      await tester.enterText(_numberField(), '900');
      repo.prices.value = {'a': 880};
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_numberField()).controller!.text, '900');
    });

    testWidgets('a server refusal is said in plain words', (tester) async {
      final repo = await openPackages(tester);
      repo.failWith['saveCoachPackage'] = const CoachingFailure(
        CoachingRefusal.tooManyPackages,
      );
      await tester.tap(find.text('Add a package'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8 weeks, 4 live sessions a month'));
      await tester.enterText(_numberField(), '1500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save package'));
      await tester.pumpAndSettle();
      expect(
        find.text('You already have 6 packages. Edit one of them instead.'),
        findsOneWidget,
      );
      expect(find.textContaining('tooManyPackages'), findsNothing);
      expect(find.textContaining('too_many'), findsNothing);
    });

    testWidgets('the member preview never shows the margin', (tester) async {
      await openPackages(tester);
      await tester.tap(find.text('Add a package'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 weeks, 2 live sessions a month'));
      await tester.enterText(_numberField(), '1000');
      await tester.pumpAndSettle();
      expect(find.text('Ask to join'), findsOneWidget);
      expect(find.textContaining('15%'), findsNothing);
      expect(find.textContaining('ommission'), findsNothing);
    });
  });

  group('every screen at text scale 2.0', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('${locale.languageCode}: space, portfolio, packages, edit', (
        tester,
      ) async {
        final repo = CoachRepo()..coaches.value = [_me(published: false)];
        repo.packages['me'] = Feed<List<CoachPackage>>([package('a')]);
        await _open(tester, repo, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(CoachSpaceView))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );

        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.text('Package a').evaluate().isNotEmpty
              ? find.text('Package a')
              : find.byIcon(Icons.chevron_right).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ar: the price line uses Western digits', (tester) async {
      final repo = CoachRepo()..coaches.value = [_me()];
      repo.packages['me'] = Feed<List<CoachPackage>>(const []);
      await _open(tester, repo, locale: const Locale('ar'));
      await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.enterText(_numberField(), '1000');
      await tester.pumpAndSettle();
      expect(find.text('الأعضاء بيشوفوا 1,150 جنيه'), findsWidgets);
    });
  });
}
