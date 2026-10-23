// M1: Terms and Privacy accepted at C06, in the same tap as the send.
//
// No code goes out before she taps; her tap writes the acceptance to the
// phone first; the router sends it once her code is accepted; and a version
// the server has not recorded asks her again.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/config/legal_links.dart';
import 'package:own_hub/features/account/presentation/legal_update_sheet.dart';
import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/domain/legal_acceptance.dart';
import 'package:own_hub/features/signup/presentation/phone_number_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

/// Records the order things happen in.
class _OrderedAuth extends FakeAuthRepository {
  _OrderedAuth(this.log);

  final List<String> log;

  @override
  Future<void> sendCode(String phoneNumber) async {
    final pending = await PendingLegalAcceptance.read();
    log.add(
      pending == null ? 'sent without acceptance' : 'sent after acceptance',
    );
    await super.sendCode(phoneNumber);
  }
}

/// A store that fails until told otherwise.
class _FlakyStore implements LegalAcceptanceStore {
  bool online = false;
  final List<LegalAcceptance> recorded = <LegalAcceptance>[];
  bool serverHasCurrent = false;

  @override
  Future<void> record(LegalAcceptance acceptance) async {
    if (!online) throw StateError('offline');
    recorded.add(acceptance);
    serverHasCurrent = acceptance.isCurrent;
  }

  @override
  Future<bool> hasCurrent(String uid) async {
    if (!online) throw StateError('offline');
    return serverHasCurrent;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('C06: the tap is the acceptance', () {
    testWidgets('no code is sent before the tap, and none without acceptance', (
      tester,
    ) async {
      final log = <String>[];
      final auth = _OrderedAuth(log);
      bool? crash;
      await tester.pumpWidget(
        _host(
          PhoneNumberView(
            repository: auth,
            now: () => DateTime.utc(2026, 10, 6, 9),
            onCrashReportsChosen: (allowed) async {
              crash = allowed;
              log.add('crash choice applied');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '01001234567');
      await tester.pumpAndSettle();
      expect(auth.sentTo, isEmpty, reason: 'typing sends nothing');
      expect(await PendingLegalAcceptance.read(), isNull);

      await tester.tap(find.text('Agree and send me a code'));
      await tester.pumpAndSettle();

      expect(log, ['crash choice applied', 'sent after acceptance']);
      expect(
        crash,
        isFalse,
        reason: 'crash reports are off unless she opts in',
      );
      final pending = await PendingLegalAcceptance.read();
      expect(pending, isNotNull);
      expect(pending!.termsVersion, kTermsVersion);
      expect(pending.privacyVersion, kPrivacyVersion);
      expect(pending.locale, 'en');
      expect(
        pending.acceptedAtMs,
        DateTime.utc(2026, 10, 6, 9).millisecondsSinceEpoch,
      );
    });

    testWidgets('crash reports are optional and off until she turns them on', (
      tester,
    ) async {
      bool? crash;
      await tester.pumpWidget(
        _host(
          PhoneNumberView(
            repository: FakeAuthRepository(),
            onCrashReportsChosen: (allowed) async => crash = allowed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Send crash reports'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('phone-crash-reports')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('phone-crash-reports')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '01001234567');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and send me a code'));
      await tester.pumpAndSettle();
      expect(crash, isTrue);
    });

    testWidgets('in Arabic the acceptance is recorded in Arabic', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PhoneNumberView(repository: FakeAuthRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'لما تضغطي على «موافقة وعايزة الكود»، بتقبلي شروط الاستخدام وسياسة الخصوصية.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(EditableText), '01001234567');
      await tester.pumpAndSettle();
      await tester.tap(find.text('موافقة وعايزة الكود'));
      await tester.pumpAndSettle();
      expect((await PendingLegalAcceptance.read())!.locale, 'ar');
    });

    testWidgets('the two names open the two documents', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        _host(
          PhoneNumberView(
            repository: FakeAuthRepository(),
            onOpenTerms: () => opened.add('terms'),
            onOpenPrivacy: () => opened.add('privacy'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final line = find.byKey(const ValueKey('legal-acceptance-line'));
      final rich = tester.widget<Text>(line).textSpan! as TextSpan;
      final links = rich.children!
          .whereType<TextSpan>()
          .where((span) => span.recognizer != null)
          .toList();
      expect(links.map((s) => s.text), ['Terms of Use', 'Privacy Policy']);
      for (final span in links) {
        (span.recognizer! as dynamic).onTap();
      }
      expect(opened, ['terms', 'privacy']);
    });
  });

  group('after the code: the pending acceptance reaches the server', () {
    test('a pending acceptance is sent and then cleared', () async {
      await PendingLegalAcceptance.write(
        LegalAcceptance.now('ar', clock: () => DateTime.utc(2026, 10, 6)),
      );
      final store = _FlakyStore()..online = true;
      final status = await reconcileLegalAcceptance(store: store, uid: 'u1');
      expect(status, LegalStatus.accepted);
      expect(store.recorded.single.locale, 'ar');
      expect(await PendingLegalAcceptance.read(), isNull);
    });

    test('offline, the pending acceptance is kept for the next try', () async {
      await PendingLegalAcceptance.write(LegalAcceptance.now('en'));
      final store = _FlakyStore();
      expect(
        await reconcileLegalAcceptance(store: store, uid: 'u1'),
        LegalStatus.unknown,
      );
      expect(await PendingLegalAcceptance.read(), isNotNull);
      store.online = true;
      expect(
        await reconcileLegalAcceptance(store: store, uid: 'u1'),
        LegalStatus.accepted,
      );
    });

    test('a version bump asks her again', () async {
      // She accepted an older material version: the server has nothing for
      // the versions in force, and her old pending record is not sent.
      SharedPreferences.setMockInitialValues(<String, Object>{
        kLegalPendingKey: jsonEncode(<String, Object>{
          't': kTermsVersion - 1,
          'p': kPrivacyVersion - 1,
          'locale': 'en',
          'acceptedAtMs': 1,
        }),
      });
      final store = _FlakyStore()..online = true;
      expect(
        await reconcileLegalAcceptance(store: store, uid: 'u1'),
        LegalStatus.needsAgreement,
      );
      expect(store.recorded, isEmpty, reason: 'older wording is never sent');
      expect(await PendingLegalAcceptance.read(), isNull);
    });

    test('accepted on the server means nothing to ask', () async {
      final store = _FlakyStore()
        ..online = true
        ..serverHasCurrent = true;
      expect(
        await reconcileLegalAcceptance(store: store, uid: 'u1'),
        LegalStatus.accepted,
      );
    });

    test('the body the callable receives', () {
      final acceptance = LegalAcceptance(
        termsVersion: kTermsVersion,
        privacyVersion: kPrivacyVersion,
        locale: 'ar',
        acceptedAtMs: 5,
      );
      expect(acceptance.payload(appVersion: '1.0.0+1', platform: 'ios'), {
        'termsVersion': kTermsVersion,
        'privacyVersion': kPrivacyVersion,
        'locale': 'ar',
        'appVersion': '1.0.0+1',
        'platform': 'ios',
        'acceptedAtMs': 5,
      });
      expect(legalAcceptanceDocId(), 'legal-t3-p3');
    });
  });

  group('the legal update sheet', () {
    testWidgets('it blocks, names what changed, and agreeing records', (
      tester,
    ) async {
      var agreed = 0;
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showLegalUpdateSheet(
                  context,
                  onAgree: () async {
                    agreed++;
                    return true;
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text('We have updated our Terms and Privacy Policy'),
        findsOneWidget,
      );
      expect(find.text('Delete my account instead'), findsOneWidget);
      // Cannot be dismissed by tapping outside it.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Agree and continue'), findsOneWidget);

      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(agreed, 1);
      expect(result, isTrue);
    });

    testWidgets('a failed save keeps it open and says so', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showLegalUpdateSheet(context, onAgree: () async => false),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-update-error')), findsOneWidget);
      expect(find.text('Agree and continue'), findsOneWidget);
    });

    testWidgets('choosing deletion answers false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showLegalUpdateSheet(
                  context,
                  onAgree: () async => true,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account instead'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('links in her language', () {
    test('Arabic pages live under /ar/', () {
      expect(
        LegalLinks.localised('https://ownhub.example/privacy', 'ar'),
        'https://ownhub.example/ar/privacy',
      );
      expect(
        LegalLinks.localised('https://ownhub.example/privacy', 'en'),
        'https://ownhub.example/privacy',
      );
      expect(
        LegalLinks.localised('https://ownhub.example/ar/terms', 'ar'),
        'https://ownhub.example/ar/terms',
      );
      expect(LegalLinks.localised('', 'ar'), '');
    });

    test('a release build refuses empty links', () {
      if (LegalLinks.allSet) return;
      expect(
        () => LegalLinks.requireForRelease(release: true),
        throwsStateError,
      );
      LegalLinks.requireForRelease(release: false);
    });
  });
}
