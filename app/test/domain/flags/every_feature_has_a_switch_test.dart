// Every feature has a switch, and so does every new one.
//
// The owner's rule: each thing a woman can do ships behind its own flag, so it
// can arrive dark, be switched on when it is ready, and be switched off on its
// own when it breaks. These tests are what make it a rule rather than a habit.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/remote_features.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

void main() {
  group('every screen has a switch', () {
    test('each screen is in the table or named as ungated, never both', () {
      for (final id in appRoutes.keys) {
        final switched = AppRouter.screenFeatures.containsKey(id);
        final ungated = AppRouter.ungatedScreens.contains(id);
        expect(
          switched != ungated,
          isTrue,
          reason:
              '$id must have exactly one answer: a Feature in '
              'lib/routing/screen_features.dart, or a reasoned place in '
              'AppRouter.ungatedScreens. A new screen has no default.',
        );
      }
    });

    test('the table names no screen that no longer exists', () {
      for (final id in AppRouter.screenFeatures.keys) {
        expect(appRoutes, contains(id), reason: '$id is stale');
      }
    });

    test('only her way out and the setup questions are ungated', () {
      // Growing this list is a decision to read out to the owner: every
      // entry is a screen no switch can close.
      expect(AppRouter.ungatedScreens, {
        'C02',
        'A01',
        'A02',
        'A03',
        'A04',
        'O01',
        'O02',
        'O03',
        'O04',
        'O05',
        'O06',
      });
      for (final id in AppRouter.ungatedScreens.where((id) => id != 'C02')) {
        expect(
          AppRouter.featureForFlow(appRoutes[id]!.flow),
          isNull,
          reason: id,
        );
      }
    });
  });

  group('every switch does something', () {
    test('each feature opens a screen, or says why it does not', () {
      final opening = AppRouter.screenFeatures.values.toSet();
      for (final f in Feature.values) {
        final explained = Feature.gatesNoScreen.containsKey(f);
        expect(
          opening.contains(f) != explained,
          isTrue,
          reason: opening.contains(f)
              ? '${f.name} opens a screen, so it needs no entry in '
                    'Feature.gatesNoScreen'
              : '${f.name} opens no screen. Give it one in '
                    'screen_features.dart, or a reason in '
                    'Feature.gatesNoScreen. A switch that does nothing is a '
                    'lie on Z14.',
        );
      }
    });

    test('the shipped build decides every feature, by name', () {
      for (final f in Feature.values) {
        expect(
          FeatureFlags.shipped.decides(f),
          isTrue,
          reason:
              '${f.name} is missing from FeatureFlags.shipped. Say whether '
              'the release carries it.',
        );
      }
    });

    test('a part never ships on under a parent that ships off', () {
      for (final f in Feature.values) {
        if (f.parent == null || !FeatureFlags.shipped.isSetOn(f)) continue;
        expect(
          FeatureFlags.shipped.isOn(f.parent!),
          isTrue,
          reason: '${f.name} is set on under ${f.parent!.name}, which is off',
        );
      }
    });
  });

  group('what the server may switch', () {
    test('it can never open the app to anyone, or close the way out', () {
      for (final f in [
        Feature.accountRequired,
        Feature.signUp,
        Feature.verification,
        Feature.today,
        Feature.privacyCentre,
        Feature.adminConsole,
      ]) {
        expect(f.serverMayTurnOff, isFalse, reason: f.name);
        expect(f.serverMayTurnOn, isFalse, reason: f.name);
      }
    });

    test('it can switch on only what the owner runs herself', () {
      expect(
        [
          for (final f in Feature.values)
            if (f.serverMayTurnOn) f,
        ],
        [Feature.events],
      );
    });

    test('a stop is taken, a start beyond the build is not', () {
      final overrides = RemoteFeatures.overridesFrom({
        'recipes': false,
        'shareCard': false,
        'events': true,
        // None of these can be moved from a document.
        'community': true,
        'coachApp': true,
        'assistant': true,
        'accountRequired': false,
        'verification': false,
        'today': false,
        // Not a bool, and not a feature.
        'train': 'off',
        'pro': true,
      });
      expect(overrides, {
        Feature.recipes: false,
        Feature.shareCard: false,
        Feature.events: true,
      });
    });

    test('a stopped part closes its screens and leaves the rest open', () {
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);
      AppRouter.featureFlags = FeatureFlags.shipped.with_(
        RemoteFeatures.overridesFrom({'recipes': false}),
      );
      expect(AppRouter.screenIsOn('E05'), isFalse);
      expect(AppRouter.screenIsOn('E06'), isFalse);
      // The week plan is built from recipes, and the list from the plan.
      expect(AppRouter.screenIsOn('E07'), isFalse);
      expect(AppRouter.screenIsOn('E08'), isFalse);
      expect(AppRouter.screenIsOn('E01'), isTrue);
      expect(AppRouter.screenIsOn('E02'), isTrue);
    });

    test('a screen needs its flow and its own switch both on', () {
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);
      // The planner's drafts are the assistant's: planner on, assistant off.
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.coachPlanning: true,
      });
      expect(AppRouter.screenIsOn('W03'), isTrue);
      expect(AppRouter.screenIsOn('K26'), isFalse);
      expect(AppRouter.screenIsOn('K27'), isFalse);
      // "I already did it" opens from Home but is Train's.
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.recordFromMemory: true,
      });
      expect(AppRouter.screenIsOn('T02'), isFalse);
    });
  });

  test('the assistant ships off, and nothing in the launch is paid', () {
    expect(FeatureFlags.shipped.isOn(Feature.assistant), isFalse);
    expect(FeatureFlags.shipped.isOn(Feature.payments), isFalse);
    expect(FeatureFlags.shipped.isOn(Feature.recipeTiering), isFalse);
  });
}
