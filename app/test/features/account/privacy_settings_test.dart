// A03's switches: independent, default off, and honest about offline.
//
// The figures and keys here deliberately avoid the prototype's own defaults, so
// a constant cannot pass for a computation — PHASE1-FIXES.md §13 records four
// screens that shipped the mockup's samples as a woman's personal facts, and
// #8's note is the reason: "Only a DIFFERENT prescription distinguishes a real
// label from a constant one."

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/media_blur_policy.dart';
import 'package:own_hub/features/account/domain/privacy_settings.dart';

void main() {
  group('defaults — every sharing switch is OFF, and the blur is ON', () {
    test('a new account shares nothing', () {
      const settings = PrivacySettings.initial;

      expect(settings.profileVisible, isFalse);
      expect(settings.showBests, isFalse);
      expect(settings.shareLogsWithCoach, isFalse);
    });

    test('blurFacesDefault is the one default that is on', () {
      // Rule 6 / HANDOFF 8 / spine C11. The asymmetry IS the rule: a default
      // that protects her is on, a default that exposes her is off.
      expect(PrivacySettings.initial.blurFacesDefault, isTrue);

      expect(PrivacySettings.initial.onKeys, {
        PrivacyKey.blurFacesDefault,
      }, reason: 'exactly one switch starts on, and it is the protective one');
    });
  });

  group('independence — one switch, one key', () {
    test('flipping one switch writes exactly one field path', () async {
      final repository = InMemoryPrivacyRepository();
      final privacy = PrivacySettingsService(repository);
      await privacy.setSwitch(PrivacyKey.showBests, true);

      expect(
        repository.writes,
        ['privacy.showBests'],
        reason:
            'a field-path merge, not a whole-map write. Two devices flipping '
            'two different switches offline must merge on distinct keys '
            '(spine §5) rather than one clobbering the other.',
      );
    });

    test(
      'turning one on leaves every other switch exactly where it was',
      () async {
        final repository = InMemoryPrivacyRepository();
        final privacy = PrivacySettingsService(repository);

        final outcome = await privacy.setSwitch(
          PrivacyKey.shareLogsWithCoach,
          true,
        );

        expect(outcome.settings.shareLogsWithCoach, isTrue);
        // The other three are untouched — including the blur, which must not be
        // dragged off by a neighbouring switch.
        expect(outcome.settings.profileVisible, isFalse);
        expect(outcome.settings.showBests, isFalse);
        expect(outcome.settings.blurFacesDefault, isTrue);
      },
    );

    test(
      'four switches, flipped one at a time, compose independently',
      () async {
        final repository = InMemoryPrivacyRepository();
        final privacy = PrivacySettingsService(repository);

        await privacy.setSwitch(PrivacyKey.profileVisible, true);
        await privacy.setSwitch(PrivacyKey.showBests, true);
        await privacy.setSwitch(PrivacyKey.blurFacesDefault, false);
        await privacy.setSwitch(PrivacyKey.shareLogsWithCoach, true);

        expect(repository.writes, [
          'privacy.profileVisible',
          'privacy.showBests',
          'privacy.blurFacesDefault',
          'privacy.shareLogsWithCoach',
        ]);

        // And turning one back off removes only itself.
        final outcome = await privacy.setSwitch(PrivacyKey.showBests, false);
        expect(outcome.settings.onKeys, {
          PrivacyKey.profileVisible,
          PrivacyKey.shareLogsWithCoach,
        });
      },
    );

    test('there is no API that sets two switches at once', () {
      // Independence is a property of the write shape. `withKey` takes ONE key,
      // and PrivacyRepository has no method accepting a whole PrivacySettings —
      // so "turning on X quietly turned on Y" is not expressible.
      const settings = PrivacySettings.initial;
      final changed = settings.withKey(PrivacyKey.profileVisible, true);

      expect(changed.profileVisible, isTrue);
      expect(changed.showBests, settings.showBests);
      expect(changed.blurFacesDefault, settings.blurFacesDefault);
      expect(changed.shareLogsWithCoach, settings.shareLogsWithCoach);
    });
  });

  group('offline — the revocation promise, stated honestly', () {
    test('a switch flipped with no signal reports that it is queued', () async {
      final repository = InMemoryPrivacyRepository()..goOffline();
      final privacy = PrivacySettingsService(repository);

      // She revokes her coach's access from a lift with no signal.
      final outcome = await privacy.setSwitch(
        PrivacyKey.shareLogsWithCoach,
        false,
      );

      // It flips locally at once — she is not blocked on the network.
      expect(outcome.settings.shareLogsWithCoach, isFalse);

      // But the product must not claim it applies everywhere. HANDOFF rule 6
      // says revocation is "immediate"; offline the server cannot deny a read
      // it has not heard about. G7 §4 resolves it as a latency, not a promise.
      expect(outcome.queuedLocally, isTrue);
      expect(
        outcome.appliesEverywhereNow,
        isFalse,
        reason:
            'P0-SHARE-03: the copy says it applies once she has signal and '
            'does NOT say immediately',
      );
    });

    test('online, the same flip applies everywhere at once', () async {
      final repository = InMemoryPrivacyRepository();
      final privacy = PrivacySettingsService(repository);

      final outcome = await privacy.setSwitch(
        PrivacyKey.shareLogsWithCoach,
        false,
      );

      expect(outcome.queuedLocally, isFalse);
      expect(outcome.appliesEverywhereNow, isTrue);
    });
  });

  group('rule 6 — MediaBlurPolicy', () {
    test('no per-image choice falls back to her default, which is on', () {
      expect(
        MediaBlurPolicy.resolve(
          perImage: null,
          settings: PrivacySettings.initial,
        ),
        isTrue,
        reason:
            'the defect this prevents is `blurred: someBool ?? false`, which '
            'is one character and ships an unblurred face',
      );
    });

    test('an explicit per-image choice wins in both directions', () {
      expect(
        MediaBlurPolicy.resolve(
          perImage: false,
          settings: PrivacySettings.initial,
        ),
        isFalse,
      );

      // Her default is off, but she blurred this one.
      const off = PrivacySettings(blurFacesDefault: false);
      expect(MediaBlurPolicy.resolve(perImage: true, settings: off), isTrue);
    });

    test('a null choice never reads as false while the default is true', () {
      // The guarantee in one assertion: there is no combination of a null
      // per-image value and the shipped default that produces "do not blur".
      expect(
        MediaBlurPolicy.resolve(
          perImage: null,
          settings: PrivacySettings.initial,
        ),
        isTrue,
      );
    });

    test(
      'turning blur off needs the consequence stated; turning it on does not',
      () {
        expect(MediaBlurPolicy.needsConsequenceSheet(turningOn: false), isTrue);
        expect(
          MediaBlurPolicy.needsConsequenceSheet(turningOn: true),
          isFalse,
          reason: 'nobody has to be warned about becoming more private',
        );
      },
    );
  });

  group('notify — quiet hours wrap midnight', () {
    test('22:00 to 08:00 is quiet, and the middle of the day is not', () {
      const notify = NotifySettings.initial;

      // A02's copy: "One a day, quiet 10pm-8am".
      expect(notify.quietStart, 22 * 60);
      expect(notify.quietEnd, 8 * 60);

      expect(notify.isQuietAt(23 * 60), isTrue, reason: '11pm is quiet');
      expect(notify.isQuietAt(3 * 60), isTrue, reason: '3am is quiet');
      expect(notify.isQuietAt(7 * 60 + 59), isTrue);
      expect(notify.isQuietAt(8 * 60), isFalse, reason: '8am ends it');
      expect(notify.isQuietAt(13 * 60), isFalse);
      expect(notify.isQuietAt(21 * 60 + 59), isFalse);
    });

    test('a non-wrapping window still works', () {
      // Not the shipped default — deliberately a different shape, so the
      // wrapping branch is not the only one exercised.
      const notify = NotifySettings(quietStart: 600, quietEnd: 800);

      expect(notify.isQuietAt(700), isTrue);
      expect(notify.isQuietAt(500), isFalse);
      expect(notify.isQuietAt(900), isFalse);
    });
  });
}
