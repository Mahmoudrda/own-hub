// The localisation host and the fixtures the eleven B-screen widget tests share.
//
// Not a `_test.dart` file, so the runner does not try to execute it. It exists
// because eleven copies of the same MaterialApp is eleven places for the locale
// wiring to drift, and a screen tested under a host that does not match the app
// is a screen tested against nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/consent.dart';
import 'package:own_hub/features/coachbrand/domain/derived_numbers.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_theme.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// One fixed moment, so consent — which is a function of time — is decidable.
final DateTime at = DateTime(2026, 9, 19, 11, 30);

/// A 390×844 logical phone, the size the prototype draws.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// The app's own localisation wiring, exactly as `main.dart` supplies it.
Widget host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

/// The starter theme, stamped at [at] so the validation is deterministic.
PortfolioTheme theme() => PortfolioTheme.starter(now: at);

PortfolioBlock block(
  String id,
  BlockPayload payload, {
  bool visible = true,
}) => PortfolioBlock(id: id, payload: payload, visible: visible);

Portfolio draft({List<PortfolioBlock> blocks = const <PortfolioBlock>[]}) =>
    Portfolio(
      versionId: PortfolioVersionIds.draft,
      version: 1,
      published: false,
      theme: theme(),
      blocks: blocks,
    );

/// A result in `requested`: no media, no numbers, no quote. The only shape a
/// coach can create.
ClientResult requested(String id) => ClientResult.fromRequest(
  ResultRequest(
    resultId: id,
    clientUid: 'client-$id',
    relationshipId: 'rel-$id',
    requestedAt: at.subtract(const Duration(days: 3)),
  ),
);

/// The client's own yes, with everything she might tick.
ClientResult granted(
  String id, {
  bool photos = true,
  bool numbers = true,
  bool quote = true,
  bool faceVisible = false,
  List<String> mediaIds = const <String>['m1'],
  String? sentence = 'Carried both kids up the stairs.',
  List<ClientBest> bests = const <ClientBest>[
    ClientBest(measureId: 'plankSec', from: 20, to: 75, unit: 's'),
  ],
}) => requested(id)
    .grantedByClient(
      at: at.subtract(const Duration(days: 2)),
      scope: ConsentScope(
        photos: photos,
        numbers: numbers,
        quote: quote,
        faceVisible: faceVisible,
      ),
      mediaIds: mediaIds,
      quote: sentence,
    )
    .withDerivedNumbers(bests);

/// Her taking it back. Terminal, and the content goes in the same write.
ClientResult withdrawn(String id) =>
    granted(id).withdrawnByClient(at: at.subtract(const Duration(hours: 1)));
