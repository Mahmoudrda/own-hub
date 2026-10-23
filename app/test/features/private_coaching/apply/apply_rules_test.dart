import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_labels.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_rules.dart';
import 'package:own_hub/l10n/app_l10n.dart';

import '../support/fixtures.dart';
import 'support/apply_support.dart';

void main() {
  final now = kNow;
  final full = draftApplication();

  ApplyProblems at(int step, CoachApplication app) =>
      applyProblems(step, app, now: now);

  group('a finished application', () {
    test('has no problem on any step and nothing missing', () {
      for (var step = 1; step <= kApplyStepCount; step++) {
        expect(at(step, full), isEmpty, reason: 'step $step');
      }
      expect(applyStepsNeeded(full, now: now), isEmpty);
      expect(full.missingSections(now: now), isEmpty);
    });

    test('leaves the payout out of the request', () {
      final body = full.toRequest(locale: 'en');
      expect(body.containsKey('payout'), isFalse);
      expect(
        completeApplication().toRequest(locale: 'en')['payout'],
        isNotNull,
      );
    });
  });

  group('each step asks what the server asks', () {
    test('step 1 limits', () {
      final p = full.personal;
      expect(at(1, full.copyWith(personal: p.copyWith(fullName: 'Ab'))).keys, [
        'fullName',
      ]);
      expect(
        at(
          1,
          full.copyWith(personal: p.copyWith(fullName: '')),
        ).values.single.issue,
        ApplyIssue.required,
      );
      expect(
        at(1, full.copyWith(personal: p.copyWith(displayName: 'A'))).keys,
        ['displayName'],
      );
      expect(
        at(
          1,
          full.copyWith(personal: p.copyWith(displayName: 'x' * 41)),
        ).values.single,
        const ApplyProblem(ApplyIssue.tooLong, 40),
      );
      expect(
        at(1, full.copyWith(personal: p.copyWith(governorate: 'mars'))).keys,
        ['governorate'],
      );
      expect(at(1, full.copyWith(personal: p.copyWith(languages: []))).keys, [
        'languages',
      ]);
      expect(
        at(1, full.copyWith(personal: p.copyWith(headline: 'too short'))).keys,
        ['headline'],
      );
      expect(
        at(1, full.copyWith(personal: p.copyWith(headline: 'x' * 121))).keys,
        ['headline'],
      );
      expect(at(1, full.copyWith(personal: p.copyWith(photoPath: ''))).keys, [
        'photo',
      ]);
    });

    test('step 2 counts and fields', () {
      expect(at(2, full.copyWith(education: [])).keys, ['education']);
      final row = full.education.first;
      expect(at(2, full.copyWith(education: List.filled(7, row))).keys, [
        'education',
      ]);
      expect(at(2, full.copyWith(education: List.filled(6, row))), isEmpty);
      expect(
        at(
          2,
          full.copyWith(
            education: [
              const CoachEducation(
                degree: 'BSc',
                institution: 'Cairo',
                year: 1959,
              ),
            ],
          ),
        ).keys,
        ['education.0.year'],
      );
      expect(
        at(
          2,
          full.copyWith(
            education: [
              const CoachEducation(
                degree: 'BSc',
                institution: 'Cairo',
                year: 2027,
              ),
            ],
          ),
        ).keys,
        ['education.0.year'],
      );
      expect(
        at(
          2,
          full.copyWith(
            education: [
              const CoachEducation(degree: 'B', institution: '', year: 2000),
            ],
          ),
        ).keys.toSet(),
        {'education.0.degree', 'education.0.institution'},
      );
    });

    test('step 3 needs a photo, a known type and 1 to 10 rows', () {
      final c = full.certificates.first;
      expect(at(3, full.copyWith(certificates: [])).keys, ['certificates']);
      expect(at(3, full.copyWith(certificates: List.filled(11, c))).keys, [
        'certificates',
      ]);
      expect(
        at(
          3,
          full.copyWith(
            certificates: [
              CoachCertificate(
                id: 'c-1',
                title: c.title,
                issuer: c.issuer,
                year: c.year,
                path: '',
                mime: 'image/jpeg',
              ),
            ],
          ),
        ).keys,
        ['certificates.0.photo'],
      );
      expect(
        at(
          3,
          full.copyWith(
            certificates: [
              CoachCertificate(
                id: 'c-1',
                title: c.title,
                issuer: c.issuer,
                year: c.year,
                path: 'a',
                mime: 'image/gif',
              ),
            ],
          ),
        ).keys,
        ['certificates.0.photo'],
      );
    });

    test('step 4 specialties, years and qualifications', () {
      expect(at(4, full.copyWith(specialties: [])).keys, ['specialties']);
      expect(
        at(
          4,
          full.copyWith(
            specialties: CoachingEnums.specialties.take(6).toList(),
          ),
        ).keys,
        ['specialties'],
      );
      expect(at(4, full.copyWith(qualifications: 'x' * 19)).keys, [
        'qualifications',
      ]);
      expect(at(4, full.copyWith(qualifications: 'x' * 1001)).keys, [
        'qualifications',
      ]);
      expect(
        at(
          4,
          CoachApplication(
            payoutOptional: true,
            specialties: full.specialties,
            qualifications: full.qualifications,
          ),
        ).keys,
        ['years'],
      );
      expect(
        at(
          4,
          CoachApplication(
            payoutOptional: true,
            specialties: full.specialties,
            qualifications: full.qualifications,
            yearsExperience: 51,
          ),
        ).keys,
        ['years'],
      );
    });

    test('step 5 needs two to ten', () {
      expect(
        at(
          5,
          full.copyWith(testimonials: full.testimonials.take(1).toList()),
        ).values.single,
        const ApplyProblem(ApplyIssue.tooFew, 2),
      );
      expect(
        at(
          5,
          full.copyWith(testimonials: List.filled(11, full.testimonials.first)),
        ).keys,
        ['testimonials'],
      );
      final bad = [
        const CoachTestimonial(text: 'short', from: '', source: 'fax'),
        full.testimonials.last,
      ];
      expect(at(5, full.copyWith(testimonials: bad)).keys.toSet(), {
        'testimonials.0.text',
        'testimonials.0.from',
        'testimonials.0.source',
      });
    });

    test('step 6 needs both photos, weeks and the client consent', () {
      const t = CoachTransformation();
      expect(at(6, full.copyWith(transformations: [t])).keys.toSet(), {
        'transformations.0.before',
        'transformations.0.after',
        'transformations.0.weeks',
        'transformations.0.consent',
      });
      final ok = full.transformations.first;
      CoachTransformation w(
        int weeks, {
        bool consent = true,
        String note = '',
      }) => CoachTransformation(
        beforePath: ok.beforePath,
        afterPath: ok.afterPath,
        weeks: weeks,
        note: note,
        clientConsent: consent,
      );
      expect(at(6, full.copyWith(transformations: [w(105)])).keys, [
        'transformations.0.weeks',
      ]);
      expect(at(6, full.copyWith(transformations: [w(104)])), isEmpty);
      expect(
        at(6, full.copyWith(transformations: [w(12, consent: false)])).keys,
        ['transformations.0.consent'],
      );
      expect(
        at(6, full.copyWith(transformations: [w(12, note: 'x' * 301)])).keys,
        ['transformations.0.note'],
      );
    });

    test('step 7 approach, follow-ups, reply time, where', () {
      CoachApproach a({String? text, int? f, int? r, List<String>? w}) =>
          CoachApproach(
            text: text ?? full.approach.text,
            checkInsPerWeek: f ?? 2,
            replyHours: r ?? 12,
            trainsWhere: w ?? const ['home'],
          );
      expect(at(7, full.copyWith(approach: a(text: 'x' * 49))).keys, [
        'approachText',
      ]);
      expect(at(7, full.copyWith(approach: a(text: 'x' * 1501))).keys, [
        'approachText',
      ]);
      expect(at(7, full.copyWith(approach: a(f: 8))).keys, ['followUps']);
      expect(at(7, full.copyWith(approach: a(f: -1))).keys, ['followUps']);
      expect(at(7, full.copyWith(approach: a(r: 5))).keys, ['replyHours']);
      expect(at(7, full.copyWith(approach: a(w: []))).keys, ['trainsWhere']);
    });

    test('step 8 needs all three rules', () {
      expect(at(8, full.copyWith(rules: ['accurateInfo'])).keys, ['rules']);
      expect(applyStepsNeeded(full.copyWith(termsVersion: 0), now: now), [8]);
    });
  });

  group('the steps agree with missingSections', () {
    final cases = <String, CoachApplication>{
      'personal': full.copyWith(personal: full.personal.copyWith(headline: '')),
      'education rows': full.copyWith(education: []),
      'qualifications': full.copyWith(qualifications: 'short'),
      'certificates': full.copyWith(certificates: []),
      'specialties': full.copyWith(specialties: []),
      'feedback': full.copyWith(testimonials: []),
      'transformations': full.copyWith(transformations: []),
      'approach': full.copyWith(approach: const CoachApproach()),
      'terms': full.copyWith(rules: []),
      'terms version': full.copyWith(termsVersion: 0),
    };
    cases.forEach((name, app) {
      test(name, () {
        final missing = app.missingSections(now: now);
        expect(missing, isNotEmpty);
        expect(missing.contains('payout'), isFalse);
        final fromSections = <int>{
          for (final s in missing) ?applyStepOfSection(s, app, now: now),
        };
        expect(applyStepsNeeded(app, now: now).toSet(), fromSections);
      });
    });

    test('education points at step 4 when only qualifications are missing', () {
      final app = full.copyWith(qualifications: 'short');
      expect(applyStepOfSection('education', app, now: now), 4);
      expect(
        applyStepOfSection('education', full.copyWith(education: []), now: now),
        2,
      );
      expect(applyStepOfSection('payout', full, now: now), isNull);
    });
  });

  group('words', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      test(
        'every refusal and every problem has text in ${locale.languageCode}',
        () {
          final l10n = lookupAppL10n(locale);
          for (final refusal in CoachingRefusal.values) {
            expect(
              applyFailureText(l10n, refusal).trim(),
              isNotEmpty,
              reason: refusal.code,
            );
          }
          for (final issue in ApplyIssue.values) {
            expect(
              applyProblemText(l10n, ApplyProblem(issue, 2, 9)).trim(),
              isNotEmpty,
            );
          }
          for (final id in CoachingEnums.governorates) {
            expect(governorateLabel(l10n, id), isNot(id));
          }
          for (final id in CoachingEnums.specialties) {
            expect(specialtyLabel(l10n, id), isNot(id));
          }
          for (final id in CoachingEnums.coachRules) {
            expect(ruleLabel(l10n, id), isNot(id));
          }
          for (final id in CoachingEnums.testimonialSource) {
            expect(sourceLabel(l10n, id), isNot(id));
          }
          for (final code in CoachingEnums.sectionReasons) {
            expect(reasonLabel(l10n, code).trim(), isNotEmpty);
          }
        },
      );
    }

    test('digits typed in Arabic are read as numbers', () {
      expect(parseApplyInt('٢٠١٦'), 2016);
      expect(parseApplyInt(' 12 '), 12);
      expect(parseApplyInt('x'), isNull);
      expect(parseApplyInt(''), isNull);
    });
  });
}
