// F2: saying a meal. The screen against a fake speech service, so what is
// tested is what Own Hub asks of the phone and what it does with the answer:
//
//   * nothing prompts or listens by itself while a permission is still unasked;
//   * a denied permission, no speech, noise and an offline phone each end in one
//     calm line and the keyboard, never a spinner or a wrong log;
//   * nothing is logged until she taps Add it, and she can fix a word first;
//   * the microphone is closed when she leaves.

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/first_run_moments.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_speech.dart';
import 'package:own_hub/features/eat/presentation/say_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'fake_meal_speech.dart';

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);

/// Egyptian dialect, as she would say it: koshari and eggs.
const String _dialect = 'كشري و بيض';

final _mic = find.byKey(const ValueKey('voice-mic'));

void _phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('ar'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

SayItView _view(
  FakeMealSpeech engine, {
  MealRepository? repository,
  LogCommandBus? bus,
  DietaryConstraints constraints = DietaryConstraints.none,
  VoidCallback? onTypeInstead,
  ValueChanged<MealLogRefused>? onBlocked,
  VoidCallback? onClose,
}) {
  return SayItView(
    constraints: constraints,
    repository: repository,
    bus: bus,
    now: _lunchtime,
    engine: engine,
    onClose: onClose ?? () {},
    onTypeInstead: onTypeInstead ?? () {},
    onBlocked: onBlocked,
  );
}

AppL10n _l10n(WidgetTester tester) =>
    AppL10n.of(tester.element(find.byType(SayItView)));

Future<void> _open(
  WidgetTester tester,
  FakeMealSpeech engine, {
  Locale locale = const Locale('ar'),
  MealRepository? repository,
  LogCommandBus? bus,
  DietaryConstraints constraints = DietaryConstraints.none,
  VoidCallback? onTypeInstead,
  ValueChanged<MealLogRefused>? onBlocked,
  double textScale = 1.0,
}) async {
  _phone(tester);
  await tester.pumpWidget(
    _host(
      _view(
        engine,
        repository: repository,
        bus: bus,
        constraints: constraints,
        onTypeInstead: onTypeInstead,
        onBlocked: onBlocked,
      ),
      locale: locale,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the microphone and lets the phone answer.
Future<void> _tapMic(WidgetTester tester) async {
  await tester.tap(_mic);
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    // By default she has already read the sentence on this screen once.
    FirstRunMoments.instance.debugSet(voiceSeen: true);
  });
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    FirstRunMoments.instance.debugSet(loaded: false);
  });

  group('a permission that has not been asked', () {
    setUp(() => FirstRunMoments.instance.debugSet(voiceSeen: false));

    testWidgets('opening the screen prompts nothing and listens to nothing', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: false);
      await _open(tester, engine);

      expect(engine.isAllowedCalls, 1, reason: 'it only reads');
      expect(engine.prepareCalls, 0, reason: 'prepare raises the prompts');
      expect(engine.listenCalls, 0);
      // One sentence says why, before any prompt.
      expect(
        find.text(_l10n(tester).ownHubListensOnlyWhileYouSpeak),
        findsOneWidget,
      );
    });

    testWidgets('her tap asks, and the answer waits for her next tap', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: false);
      await _open(tester, engine);

      await _tapMic(tester);
      expect(engine.prepareCalls, 1);
      expect(
        engine.listenCalls,
        0,
        reason: 'the system prompt has just been answered; she taps again',
      );
      expect(
        find.text(_l10n(tester).ownHubListensOnlyWhileYouSpeak),
        findsNothing,
      );

      await _tapMic(tester);
      expect(engine.listenCalls, 1);
      expect(engine.isListening, isTrue);
    });
  });

  group('a phone that already lets Own Hub listen', () {
    testWidgets('but she has not read the sentence yet: it waits for a tap', (
      tester,
    ) async {
      // Allowed for a voice note in chat, never told about saying a meal.
      FirstRunMoments.instance.debugSet(voiceSeen: false);
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine);

      expect(engine.listenCalls, 0);
      expect(engine.prepareCalls, 0);
      expect(
        find.text(_l10n(tester).ownHubListensOnlyWhileYouSpeak),
        findsOneWidget,
      );

      await _tapMic(tester);
      expect(engine.listenCalls, 1, reason: 'one tap, no prompt to wait for');
      expect(FirstRunMoments.instance.voiceExplained, isTrue);
      expect(
        find.text(_l10n(tester).ownHubListensOnlyWhileYouSpeak),
        findsNothing,
      );
    });

    testWidgets('it starts on its own, in Egyptian Arabic for the Arabic app', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine);

      expect(engine.listenCalls, 1);
      expect(engine.lastLocale, 'ar_EG');
      expect(find.text(_l10n(tester).listeningTapWhenYouAreDone), findsWidgets);
    });

    testWidgets('and in English for the English app', (tester) async {
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine, locale: const Locale('en'));

      expect(engine.lastLocale, 'en_US');
    });

    testWidgets('she can listen for the other language than the app', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: false);
      await _open(tester, engine, locale: const Locale('en'));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.arabic));
      await tester.pumpAndSettle();
      await _tapMic(tester);
      await _tapMic(tester);

      expect(engine.lastLocale, 'ar_EG');
    });
  });

  group('the transcript comes before the log', () {
    testWidgets('words so far are shown dimly and cannot be logged', (
      tester,
    ) async {
      final repository = InMemoryMealRepository();
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine, repository: repository);

      engine.say(_dialect);
      await tester.pumpAndSettle();

      expect(find.text(_dialect), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-transcript')), findsNothing);
      await tester.tap(find.text(_l10n(tester).addIt));
      await tester.pump(const Duration(seconds: 6));
      expect(repository.writes, isEmpty);
    });

    testWidgets('the final words become a transcript she can fix', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine);

      engine.finish(_dialect);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('voice-transcript')), findsOneWidget);
      expect(find.text(_dialect), findsOneWidget);
      expect(find.text('طبق كشري'), findsOneWidget);
      expect(find.text('بيض مسلوق'), findsOneWidget);
    });

    testWidgets('nothing is logged until she taps Add it', (tester) async {
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine, repository: repository, bus: bus);

      engine.finish(_dialect);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(repository.writes, isEmpty, reason: 'she has not confirmed');

      await tester.tap(find.text(_l10n(tester).addIt));
      await tester.pump(const Duration(seconds: 6));
      expect(repository.writes, hasLength(1));
      bus.dispose();
    });

    testWidgets(
      'edit a word, then confirm: the fixed sentence is what is logged',
      (tester) async {
        final repository = InMemoryMealRepository();
        final bus = LogCommandBus();
        final engine = FakeMealSpeech(allowed: true);
        await _open(tester, engine, repository: repository, bus: bus);

        engine.finish('كشري');
        await tester.pumpAndSettle();
        expect(find.text('بيض مسلوق'), findsNothing);

        await tester.enterText(
          find.byKey(const ValueKey('voice-transcript')),
          _dialect,
        );
        await tester.pumpAndSettle();
        expect(find.text('بيض مسلوق'), findsOneWidget);

        await tester.tap(find.text(_l10n(tester).addIt));
        await tester.pump(const Duration(seconds: 6));

        expect(repository.writes.single.added, hasLength(2));
        expect(repository.writes.single.added.first.source, MealSource.voice);
        expect(repository.writes.single.added.first.origin, MealOrigin.voice);
        bus.dispose();
      },
    );

    testWidgets('an allergy never stops her logging what she already ate', (
      tester,
    ) async {
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();
      MealLogRefused? refused;
      final engine = FakeMealSpeech(allowed: true);
      await _open(
        tester,
        engine,
        repository: repository,
        bus: bus,
        constraints: const DietaryConstraints(
          allergies: {'egg'},
          dietary: <String>{},
        ),
        onBlocked: (r) => refused = r,
      );

      engine.finish('بيضتين');
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(tester).addIt));
      await tester.pump(const Duration(seconds: 6));

      expect(refused, isNull, reason: 'a log records what she ate');
      expect(repository.writes, hasLength(1));
      bus.dispose();
    });
  });

  group('when there is nothing to confirm', () {
    for (final noise in const ['', '   ', 'um', 'mmm']) {
      testWidgets('"$noise" is no speech, said calmly', (tester) async {
        final engine = FakeMealSpeech(allowed: true);
        await _open(tester, engine);

        engine.finish(noise);
        await tester.pumpAndSettle();

        final l10n = _l10n(tester);
        expect(find.text(l10n.weDidntCatchAnythingTryAgainA), findsOneWidget);
        expect(find.byKey(const ValueKey('voice-transcript')), findsNothing);
      });
    }

    testWidgets('a phone that heard nothing says so and she can try again', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine);

      engine.fail(SpeechFailure.noSpeech);
      await tester.pumpAndSettle();
      expect(
        find.text(_l10n(tester).weDidntCatchAnythingTryAgainA),
        findsOneWidget,
      );

      await _tapMic(tester);
      expect(engine.listenCalls, 2);
    });

    testWidgets('a food that is not in the pack is a chip and nothing to log', (
      tester,
    ) async {
      final repository = InMemoryMealRepository();
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine, repository: repository);

      engine.finish('qqq zzz');
      await tester.pumpAndSettle();

      final l10n = _l10n(tester);
      expect(find.text('qqq zzz'), findsWidgets);
      expect(find.text(l10n.weHeardYouButNoneOfIt), findsOneWidget);
      await tester.tap(find.text(l10n.addIt));
      await tester.pump(const Duration(seconds: 6));
      expect(repository.writes, isEmpty);
    });

    testWidgets(
      'an offline phone says it needs a connection and offers typing',
      (tester) async {
        var typed = 0;
        final engine = FakeMealSpeech(allowed: true);
        await _open(tester, engine, onTypeInstead: () => typed++);

        engine.fail(SpeechFailure.offline);
        await tester.pumpAndSettle();

        final l10n = _l10n(tester);
        expect(
          find.text(l10n.sayingYourMealNeedsAnInternetConnection),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.typeWhatYouAte));
        expect(typed, 1);
      },
    );

    testWidgets('a phone with no speech service refuses and offers typing', (
      tester,
    ) async {
      var typed = 0;
      final engine = FakeMealSpeech(
        allowed: false,
        prepareResult: SpeechFailure.unavailable,
      );
      await _open(tester, engine, onTypeInstead: () => typed++);

      await _tapMic(tester);

      final l10n = _l10n(tester);
      expect(find.text(l10n.thisPhoneCantTurnSpeechIntoText), findsOneWidget);
      expect(_mic, findsNothing);
      await tester.tap(find.text(l10n.typeWhatYouAte));
      expect(typed, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('a denied permission', () {
    testWidgets('is one calm line, a way to Settings and the keyboard', (
      tester,
    ) async {
      var typed = 0;
      final engine = FakeMealSpeech(
        allowed: false,
        prepareResult: SpeechFailure.denied,
      );
      await _open(tester, engine, onTypeInstead: () => typed++);

      await _tapMic(tester);

      final l10n = _l10n(tester);
      expect(find.text(l10n.ownHubCantUseTheMicrophoneOr), findsOneWidget);
      expect(find.text(l10n.openSettings), findsOneWidget);
      expect(_mic, findsNothing, reason: 'nothing to press that cannot work');
      expect(engine.listenCalls, 0);
      await tester.tap(find.text(l10n.typeWhatYouAte));
      expect(typed, 1);
    });

    testWidgets('a denial that arrives mid-session ends the same way', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine);

      engine.fail(SpeechFailure.denied);
      await tester.pumpAndSettle();

      expect(find.text(_l10n(tester).openSettings), findsOneWidget);
    });
  });

  group('the microphone is never left open', () {
    testWidgets('leaving the screen cancels the session and logs nothing', (
      tester,
    ) async {
      final repository = InMemoryMealRepository();
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine, repository: repository);
      expect(engine.isListening, isTrue);

      engine.say(_dialect);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));

      expect(engine.cancelCalls, greaterThanOrEqualTo(1));
      expect(engine.isListening, isFalse);
      expect(repository.writes, isEmpty);
    });

    testWidgets('sending the app to the background cancels it too', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(engine.cancelCalls, 1);
      expect(engine.isListening, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });

  group('press and hold, or tap', () {
    testWidgets('holding starts, letting go stops, and the words follow', (
      tester,
    ) async {
      final engine = FakeMealSpeech(allowed: true, localeIds: ['en_US']);
      await _open(tester, engine);
      // The auto-start ran; end that session so the hold is the only one.
      engine.finish('');
      await tester.pumpAndSettle();
      final before = engine.listenCalls;

      final gesture = await tester.startGesture(tester.getCenter(_mic));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(engine.listenCalls, before + 1);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(engine.stopCalls, 1);

      engine.finish(_dialect);
      await tester.pumpAndSettle();
      expect(find.text(_dialect), findsOneWidget);
    });

    testWidgets('speak and confirm takes three taps or fewer', (tester) async {
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();
      final engine = FakeMealSpeech(allowed: true);
      await _open(tester, engine, repository: repository, bus: bus);

      var taps = 0;
      // 1: tap when done. The phone answers.
      await tester.tap(_mic);
      taps++;
      await tester.pumpAndSettle();
      engine.finish(_dialect);
      await tester.pumpAndSettle();
      // 2: confirm.
      await tester.tap(find.text(_l10n(tester).addIt));
      taps++;
      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes, hasLength(1));
      expect(taps, lessThanOrEqualTo(3));
      bus.dispose();
    });
  });

  group('the budget: one primary, five controls', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        final name =
            '${locale.languageCode} ${size.width.toInt()}x'
            '${size.height.toInt()}';

        Future<void> expectBudget(WidgetTester tester) async {
          expect(
            countControlsAboveFold(tester, includeChrome: false),
            lessThanOrEqualTo(5),
          );
          expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
          expect(tester.takeException(), isNull);
        }

        testWidgets('before she speaks, $name', (tester) async {
          _phone(tester, size: size);
          await tester.pumpWidget(
            _host(_view(FakeMealSpeech(allowed: false)), locale: locale),
          );
          await tester.pumpAndSettle();
          await expectBudget(tester);
        });

        testWidgets('while she speaks, $name', (tester) async {
          _phone(tester, size: size);
          await tester.pumpWidget(
            _host(_view(FakeMealSpeech(allowed: true)), locale: locale),
          );
          await tester.pumpAndSettle();
          await expectBudget(tester);
        });

        testWidgets('when the phone says no, $name', (tester) async {
          _phone(tester, size: size);
          await tester.pumpWidget(
            _host(
              _view(
                FakeMealSpeech(
                  allowed: false,
                  prepareResult: SpeechFailure.denied,
                ),
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(_mic);
          await tester.pumpAndSettle();
          await expectBudget(tester);
        });

        testWidgets('with a transcript, one primary and no overflow, $name', (
          tester,
        ) async {
          final engine = FakeMealSpeech(allowed: true);
          _phone(tester, size: size);
          await tester.pumpWidget(_host(_view(engine), locale: locale));
          await tester.pumpAndSettle();
          engine.finish(_dialect);
          await tester.pumpAndSettle();
          expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('largest text, ${locale.languageCode}', (tester) async {
        final engine = FakeMealSpeech(allowed: true);
        _phone(tester, size: const Size(375, 667));
        await tester.pumpWidget(
          _host(_view(engine), locale: locale, textScale: 1.6),
        );
        await tester.pumpAndSettle();
        engine.finish(_dialect);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
