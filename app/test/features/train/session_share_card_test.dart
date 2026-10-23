// The workout share card and the panel that shares it: both shapes, all three
// grounds, English and Arabic at the biggest text size, a switch for each
// figure, and a PNG of exactly the right shape handed to the share sheet.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/presentation/session_share_card.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';
import 'package:own_hub/ui/hand/mascot/kitten_painter.dart';

final _data = ShareCardData(
  title: 'Legs and glutes',
  date: DateTime(2026, 10, 21),
  minutes: 42,
  kcal: 214,
  volumeKg: 1240,
  reps: 96,
  moves: 5,
  sets: 15,
  bests: 2,
  name: 'Mai',
);

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Finder _inCard(Finder f) =>
    find.descendant(of: find.byType(SessionShareCard), matching: f);

/// Taps Share and waits, in real time, for the sharer to be handed a PNG.
Future<void> _share(WidgetTester tester, List<Uint8List> sent) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Share'));
    await tester.pump();
    for (var i = 0; i < 100 && sent.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}

Future<({int w, int h, int alphaAtRightEdge})> _decode(
  WidgetTester tester,
  Uint8List png,
) async {
  late ({int w, int h, int alphaAtRightEdge}) out;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    // Middle of the right edge: ribbon-free and clear of the type.
    final x = image.width - 3;
    final y = image.height ~/ 2;
    final alpha = raw!.getUint8((y * image.width + x) * 4 + 3);
    out = (w: image.width, h: image.height, alphaAtRightEdge: alpha);
    image.dispose();
    codec.dispose();
  });
  return out;
}

void main() {
  group('the card draws', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final format in ShareFormat.values) {
        for (final background in ShareBackground.values) {
          testWidgets(
            '${locale.languageCode} ${format.name} ${background.name} at 2.0x text without overflow',
            (tester) async {
              _tall(tester);
              await tester.pumpWidget(
                _host(
                  SessionShareCard(
                    data: _data,
                    format: format,
                    background: background,
                    shown: ShareStat.values.toSet(),
                  ),
                  locale: locale,
                  textScale: 2.0,
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              final size = tester.getSize(find.byType(SessionShareCard));
              expect(size.width, 360);
              expect(size.height, format.height);
            },
          );
        }
      }
    }

    testWidgets('draws no kitten: R10 already has its one', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          SessionShareCard(
            data: _data,
            format: ShareFormat.story,
            background: ShareBackground.linen,
            shown: ShareStat.values.toSet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Kitten), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SessionShareCard),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is KittenPainter,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('a long workout name and a long name still fit', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          SessionShareCard(
            data: ShareCardData(
              title: 'Lower body strength with glute focus and a long finisher',
              date: DateTime(2026, 10, 21),
              minutes: 1234,
              kcal: 98765,
              volumeKg: 123456,
              moves: 12,
              sets: 48,
              bests: 5,
              name: 'Mariam Abdelrahman El-Sayed El-Shafei',
            ),
            format: ShareFormat.square,
            shown: ShareStat.values.toSet(),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('says what the figures are, with calories as an estimate', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          SessionShareCard(
            data: _data,
            shown: const {
              ShareStat.calories,
              ShareStat.minutes,
              ShareStat.weight,
              ShareStat.moves,
              ShareStat.bests,
            },
          ),
        ),
      );
      expect(_inCard(find.text('Calories (est.)')), findsOneWidget);
      expect(_inCard(find.text('214')), findsOneWidget);
      expect(_inCard(find.text('Minutes')), findsOneWidget);
      expect(_inCard(find.text('Weight lifted')), findsOneWidget);
      expect(_inCard(find.text('1,240 kg')), findsOneWidget);
      expect(_inCard(find.text('Moves')), findsOneWidget);
      expect(_inCard(find.text('Sets')), findsOneWidget);
      expect(_inCard(find.text('Personal bests')), findsOneWidget);
      expect(_inCard(find.text('Legs and glutes')), findsOneWidget);
      expect(_inCard(find.text('21 October 2026')), findsOneWidget);
      // Never a name or a place unless she turned the name on.
      expect(_inCard(find.text('Mai')), findsNothing);
    });

    testWidgets('a bodyweight session shows reps where weight would be', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          SessionShareCard(
            data: ShareCardData(
              title: 'Home',
              date: DateTime(2026, 10, 21),
              minutes: 20,
              kcal: 90,
              reps: 96,
              moves: 4,
              sets: 12,
            ),
            shown: ShareStat.values.toSet(),
          ),
        ),
      );
      expect(_inCard(find.text('Weight lifted')), findsNothing);
      expect(_inCard(find.textContaining('kg')), findsNothing);
      expect(_inCard(find.text('Reps')), findsOneWidget);
      expect(_inCard(find.text('96')), findsOneWidget);
    });
  });

  group('each switch hides its figure', () {
    final cases = <ShareStat, List<String>>{
      ShareStat.calories: ['Calories (est.)'],
      ShareStat.minutes: ['Minutes'],
      ShareStat.weight: ['Weight lifted'],
      ShareStat.moves: ['Moves', 'Sets'],
      ShareStat.bests: ['Personal bests'],
    };
    for (final entry in cases.entries) {
      testWidgets(entry.key.name, (tester) async {
        _tall(tester);
        await tester.pumpWidget(
          _host(SessionSharePanel(data: _data, onShare: (_, _) async {})),
        );
        await tester.pumpAndSettle();
        for (final label in entry.value) {
          expect(_inCard(find.text(label)), findsOneWidget);
        }

        await tester.tap(
          find.byKey(ValueKey('share-switch-${entry.key.name}')),
        );
        await tester.pumpAndSettle();

        for (final label in entry.value) {
          expect(_inCard(find.text(label)), findsNothing);
        }
        // The others stay.
        for (final other in cases.entries.where((e) => e.key != entry.key)) {
          for (final label in other.value) {
            expect(_inCard(find.text(label)), findsOneWidget);
          }
        }

        await tester.tap(
          find.byKey(ValueKey('share-switch-${entry.key.name}')),
        );
        await tester.pumpAndSettle();
        for (final label in entry.value) {
          expect(_inCard(find.text(label)), findsOneWidget);
        }
      });
    }

    testWidgets('the name is off until she turns it on', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(SessionSharePanel(data: _data, onShare: (_, _) async {})),
      );
      await tester.pumpAndSettle();
      expect(_inCard(find.text('Mai')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('share-switch-name')));
      await tester.pumpAndSettle();
      expect(_inCard(find.text('Mai')), findsOneWidget);
    });

    testWidgets('no name, no name switch; no calories, no estimate note', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          SessionSharePanel(
            data: ShareCardData(
              title: 'Home',
              date: DateTime(2026, 10, 21),
              minutes: 20,
              moves: 3,
              sets: 9,
            ),
            onShare: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('share-switch-name')), findsNothing);
      expect(find.byKey(const ValueKey('share-switch-calories')), findsNothing);
      expect(find.byKey(const ValueKey('share-calorie-note')), findsNothing);
    });

    testWidgets('the calorie line says it is an estimate, not advice', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(SessionSharePanel(data: _data, onShare: (_, _) async {})),
      );
      expect(
        find.text(
          'Calories are a rough estimate from your time and your weight, not medical advice.',
        ),
        findsOneWidget,
      );
    });
  });

  group('sharing', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        '${locale.languageCode}: Story is 1080 x 1920 and Square 1080 x 1350',
        (tester) async {
          _tall(tester);
          final sent = <Uint8List>[];
          Rect? anchor;
          await tester.pumpWidget(
            _host(
              SessionSharePanel(
                data: _data,
                onShare: (png, origin) async {
                  sent.add(png);
                  anchor = origin;
                },
              ),
              locale: locale,
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppL10n.of(
            tester.element(find.byType(SessionSharePanel)),
          );

          // Square is the first shape.
          await tester.tap(find.text(l10n.share));
          await tester.pump();
          await tester.runAsync(() async {
            for (var i = 0; i < 100 && sent.isEmpty; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              await tester.pump();
            }
          });
          await tester.pumpAndSettle();
          expect(sent, hasLength(1));
          expect(sent[0].sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
          final square = await _decode(tester, sent[0]);
          expect((square.w, square.h), (1080, 1350));
          expect(anchor!.width, greaterThan(0));

          await tester.tap(find.text(l10n.story));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.share));
          await tester.pump();
          await tester.runAsync(() async {
            for (var i = 0; i < 100 && sent.length < 2; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              await tester.pump();
            }
          });
          await tester.pumpAndSettle();
          expect(sent, hasLength(2));
          final story = await _decode(tester, sent[1]);
          expect((story.w, story.h), (1080, 1920));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('linen and petrol are opaque, transparent keeps its alpha', (
      tester,
    ) async {
      _tall(tester);
      final sent = <Uint8List>[];
      await tester.pumpWidget(
        _host(
          SessionSharePanel(
            data: _data,
            onShare: (png, origin) async => sent.add(png),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _share(tester, sent);
      expect((await _decode(tester, sent.last)).alphaAtRightEdge, 255);

      await tester.tap(find.text('Petrol'));
      await tester.pumpAndSettle();
      sent.clear();
      await _share(tester, sent);
      expect((await _decode(tester, sent.last)).alphaAtRightEdge, 255);

      await tester.tap(find.text('Transparent'));
      await tester.pumpAndSettle();
      sent.clear();
      await _share(tester, sent);
      expect((await _decode(tester, sent.last)).alphaAtRightEdge, 0);
    });

    testWidgets('a switched-off figure is not in the PNG she shares', (
      tester,
    ) async {
      _tall(tester);
      final sent = <Uint8List>[];
      await tester.pumpWidget(
        _host(
          SessionSharePanel(
            data: _data,
            onShare: (png, origin) async => sent.add(png),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _share(tester, sent);
      final all = sent.single;

      await tester.tap(find.byKey(const ValueKey('share-switch-calories')));
      await tester.pumpAndSettle();
      sent.clear();
      await _share(tester, sent);
      // The picture changed, because the figure left it.
      expect(sent.single.length, isNot(all.length));
    });

    testWidgets('a share sheet that fails costs her nothing she can see', (
      tester,
    ) async {
      _tall(tester);
      var shared = 0;
      await tester.pumpWidget(
        _host(
          SessionSharePanel(
            data: _data,
            onShare: (_, _) async => throw StateError('no sheet'),
            onShared: () => shared++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Share'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(shared, 0);
    });

    testWidgets('the controls around the card keep a 48 tap target', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(SessionSharePanel(data: _data, onShare: (_, _) async {})),
      );
      await tester.pumpAndSettle();
      for (final stat in _data.available) {
        final row = find.byKey(ValueKey('share-switch-${stat.name}'));
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      }
    });
  });
}
