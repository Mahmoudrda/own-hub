/// What each application step asks for, field for field as the server and
/// `CoachApplication.missingSections` judge it, and the words for every
/// refusal.
library;

import '../../../../l10n/app_l10n.dart';
import '../../domain/coach_application.dart';
import '../../domain/coaching_contract.dart';
import '../coach/coach_text.dart' show westernDigits;

/// Working days the reviewer takes at most, as the intro and status say.
const int kReviewWorkingDays = 5;

/// The upload limit in whole megabytes, for the words.
const String kUploadMaxMb = '${CoachingLimits.uploadMaxBytes ~/ 1000000}';

/// The number of steps in the application.
const int kApplyStepCount = 8;

enum ApplyIssue {
  required,
  tooShort,
  tooLong,
  badYear,
  badNumber,
  tooFew,
  tooMany,
  photoMissing,
  notTicked,
}

class ApplyProblem {
  const ApplyProblem(this.issue, [this.a = 0, this.b = 0]);

  final ApplyIssue issue;

  /// The limit(s) the message names: a minimum, a maximum or a year range.
  final int a;
  final int b;

  @override
  bool operator ==(Object other) =>
      other is ApplyProblem &&
      other.issue == issue &&
      other.a == a &&
      other.b == b;

  @override
  int get hashCode => Object.hash(issue, a, b);

  @override
  String toString() => 'ApplyProblem($issue, $a, $b)';
}

/// Field key to problem. Empty means the step is ready. Row fields are
/// `education.0.degree`; a list that is too short or long is its own key.
typedef ApplyProblems = Map<String, ApplyProblem>;

/// The words for [problem].
String applyProblemText(AppL10n l10n, ApplyProblem problem) =>
    switch (problem.issue) {
      ApplyIssue.required => l10n.thisIsNeeded,
      ApplyIssue.tooShort => l10n.useAtLeastMinCharacters('${problem.a}'),
      ApplyIssue.tooLong => l10n.useAtMostMaxCharacters('${problem.a}'),
      ApplyIssue.badYear => l10n.enterAYearFromFromToTo(
        '${problem.a}',
        '${problem.b}',
      ),
      ApplyIssue.badNumber => l10n.enterAWholeNumberFromMinTo(
        '${problem.a}',
        '${problem.b}',
      ),
      ApplyIssue.tooFew => l10n.addAtLeastMin('${problem.a}'),
      ApplyIssue.tooMany => l10n.chooseBetweenMinAndMax(
        '${problem.a}',
        '${problem.b}',
      ),
      ApplyIssue.photoMissing => l10n.addAPhoto,
      ApplyIssue.notTicked => l10n.tickThisToContinue,
    };

ApplyProblem? _text(String value, int min, int max) {
  final length = value.trim().length;
  if (length == 0) return const ApplyProblem(ApplyIssue.required);
  if (length < min) return ApplyProblem(ApplyIssue.tooShort, min);
  if (length > max) return ApplyProblem(ApplyIssue.tooLong, max);
  return null;
}

ApplyProblem? _year(int? year, int currentYear) => year == null
    ? const ApplyProblem(ApplyIssue.required)
    : (year < 1960 || year > currentYear)
    ? ApplyProblem(ApplyIssue.badYear, 1960, currentYear)
    : null;

ApplyProblem? _count(int length, int min, int max) {
  if (length < min) return ApplyProblem(ApplyIssue.tooFew, min);
  if (length > max) return ApplyProblem(ApplyIssue.tooMany, min, max);
  return null;
}

ApplyProblem? _photo(String path) => path.isEmpty || path.length > 300
    ? const ApplyProblem(ApplyIssue.photoMissing)
    : null;

/// What step [step] (1 to 8) still needs from [app].
ApplyProblems applyProblems(int step, CoachApplication app, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  final out = <String, ApplyProblem>{};
  void put(String key, ApplyProblem? problem) {
    if (problem != null) out[key] = problem;
  }

  switch (step) {
    case 1:
      final p = app.personal;
      put('fullName', _text(p.fullName, 3, CoachingLimits.fullNameMax));
      put(
        'displayName',
        _text(p.displayName, 2, CoachingLimits.displayNameMax),
      );
      if (!CoachingEnums.governorates.contains(p.governorate)) {
        out['governorate'] = const ApplyProblem(ApplyIssue.required);
      }
      if (p.languages.isEmpty) {
        out['languages'] = const ApplyProblem(ApplyIssue.required);
      }
      put('headline', _text(p.headline, 10, CoachingLimits.headlineMax));
      put('photo', _photo(p.photoPath));
    case 2:
      put(
        'education',
        _count(
          app.education.length,
          CoachingLimits.educationMin,
          CoachingLimits.educationMax,
        ),
      );
      for (var i = 0; i < app.education.length; i++) {
        final e = app.education[i];
        put('education.$i.degree', _text(e.degree, 2, 80));
        put('education.$i.institution', _text(e.institution, 2, 80));
        put('education.$i.year', _year(e.year, year));
      }
    case 3:
      put(
        'certificates',
        _count(
          app.certificates.length,
          CoachingLimits.certificatesMin,
          CoachingLimits.certificatesMax,
        ),
      );
      for (var i = 0; i < app.certificates.length; i++) {
        final c = app.certificates[i];
        put('certificates.$i.title', _text(c.title, 2, 80));
        put('certificates.$i.issuer', _text(c.issuer, 2, 80));
        put('certificates.$i.year', _year(c.year, year));
        put(
          'certificates.$i.photo',
          kCertificateMimes.contains(c.mime) ? _photo(c.path) : _photo(''),
        );
      }
    case 4:
      put(
        'specialties',
        _count(
          app.specialties.length,
          CoachingLimits.specialtiesMin,
          CoachingLimits.specialtiesMax,
        ),
      );
      final years = app.yearsExperience;
      if (years == null) {
        out['years'] = const ApplyProblem(ApplyIssue.required);
      } else if (years < 0 || years > CoachingLimits.yearsExperienceMax) {
        out['years'] = const ApplyProblem(
          ApplyIssue.badNumber,
          0,
          CoachingLimits.yearsExperienceMax,
        );
      }
      put(
        'qualifications',
        _text(app.qualifications, 20, CoachingLimits.qualificationsMax),
      );
    case 5:
      put(
        'testimonials',
        _count(
          app.testimonials.length,
          CoachingLimits.testimonialsMin,
          CoachingLimits.testimonialsMax,
        ),
      );
      for (var i = 0; i < app.testimonials.length; i++) {
        final t = app.testimonials[i];
        put(
          'testimonials.$i.text',
          _text(t.text, 10, CoachingLimits.testimonialTextMax),
        );
        put('testimonials.$i.from', _text(t.from, 1, 40));
        if (!CoachingEnums.testimonialSource.contains(t.source)) {
          out['testimonials.$i.source'] = const ApplyProblem(
            ApplyIssue.required,
          );
        }
      }
    case 6:
      put(
        'transformations',
        _count(
          app.transformations.length,
          CoachingLimits.transformationsMin,
          CoachingLimits.transformationsMax,
        ),
      );
      for (var i = 0; i < app.transformations.length; i++) {
        final t = app.transformations[i];
        put('transformations.$i.before', _photo(t.beforePath));
        put('transformations.$i.after', _photo(t.afterPath));
        if (t.weeks < 1 || t.weeks > 104) {
          out['transformations.$i.weeks'] = const ApplyProblem(
            ApplyIssue.badNumber,
            1,
            104,
          );
        }
        if (t.note.trim().length > 300) {
          out['transformations.$i.note'] = const ApplyProblem(
            ApplyIssue.tooLong,
            300,
          );
        }
        if (!t.clientConsent) {
          out['transformations.$i.consent'] = const ApplyProblem(
            ApplyIssue.notTicked,
          );
        }
      }
    case 7:
      final a = app.approach;
      put(
        'approachText',
        _text(
          a.text,
          CoachingLimits.approachTextMin,
          CoachingLimits.approachTextMax,
        ),
      );
      if (a.checkInsPerWeek < 0 ||
          a.checkInsPerWeek > CoachingLimits.checkInsPerWeekMax) {
        out['followUps'] = const ApplyProblem(
          ApplyIssue.badNumber,
          0,
          CoachingLimits.checkInsPerWeekMax,
        );
      }
      if (!CoachingEnums.replyHours.contains(a.replyHours)) {
        out['replyHours'] = const ApplyProblem(ApplyIssue.required);
      }
      if (a.trainsWhere.isEmpty) {
        out['trainsWhere'] = const ApplyProblem(ApplyIssue.required);
      }
    case 8:
      if (!CoachingEnums.coachRules.every(app.rules.contains)) {
        out['rules'] = const ApplyProblem(ApplyIssue.notTicked);
      }
  }
  return out;
}

/// Whether step [step] is ready.
bool applyStepReady(int step, CoachApplication app, {DateTime? now}) =>
    applyProblems(step, app, now: now).isEmpty;

/// Steps that are not ready yet, in order. Step 8 counts only once the rules
/// and the terms version are in.
List<int> applyStepsNeeded(CoachApplication app, {DateTime? now}) => <int>[
  for (var step = 1; step <= kApplyStepCount; step++)
    if (!applyStepReady(step, app, now: now) ||
        (step == 8 && app.termsVersion != kCoachTermsVersion))
      step,
];

/// The step a contract section is filled in on, or null for a section this
/// build never asks for (the payout account).
///
/// `education` also covers the qualifications text and the years of
/// experience, which are on step 4: when the education rows are fine the
/// section points there.
int? applyStepOfSection(
  String section,
  CoachApplication app, {
  DateTime? now,
}) => switch (section) {
  'personal' => 1,
  'education' => applyStepReady(2, app, now: now) ? 4 : 2,
  'certificates' => 3,
  'specialties' => 4,
  'feedback' => 5,
  'transformations' => 6,
  'approach' => 7,
  'terms' => 8,
  _ => null,
};

/// The words for a refused send. Every refusal has one.
String applyFailureText(
  AppL10n l10n,
  CoachingRefusal refusal,
) => switch (refusal) {
  CoachingRefusal.notVerified => l10n.onlyVerifiedWomenCanApplyVerifyYour,
  CoachingRefusal.applicationOpen => l10n.youAlreadyHaveAnApplicationWaitingFor,
  CoachingRefusal.applicationIncomplete =>
    l10n.somethingIsStillMissingLookAtThe,
  CoachingRefusal.fileNotUploaded ||
  CoachingRefusal.certificateNotUploaded => l10n.aPhotoDidNotReachUsTry,
  CoachingRefusal.tooManyCertificates =>
    l10n.youAddedTooManyCertificatesTheMost(
      '${CoachingLimits.certificatesMax}',
    ),
  CoachingRefusal.alreadyACoach => l10n.youAreAlreadyACoachOnOwn,
  CoachingRefusal.coachAppClosed => l10n.coachApplicationsAreClosedForNowTry,
  CoachingRefusal.coachSuspended => l10n.yourCoachAccountIsPausedContactSupport,
  CoachingRefusal.imageInvalid => l10n.thatPhotoCouldNotBeUsedChoose(
    kUploadMaxMb,
  ),
  CoachingRefusal.badRequest => l10n.someOfYourAnswersWereNotAccepted,
  CoachingRefusal.unreachable => l10n.noConnectionYourAnswersAreSavedSo,
  CoachingRefusal.signedOut => l10n.signInToSendYourApplication,
  CoachingRefusal.notACoach ||
  CoachingRefusal.inviteInvalid ||
  CoachingRefusal.inviteExpired ||
  CoachingRefusal.inviteOwn ||
  CoachingRefusal.applicationNotFound ||
  CoachingRefusal.coachUnavailable ||
  CoachingRefusal.packageNotFound ||
  CoachingRefusal.tooManyPackages ||
  CoachingRefusal.priceOutOfRange ||
  CoachingRefusal.alreadyRequested ||
  CoachingRefusal.requestNotFound ||
  CoachingRefusal.wrongStatus ||
  CoachingRefusal.healthNotReviewed ||
  CoachingRefusal.pastPayBy ||
  CoachingRefusal.referenceUsed ||
  CoachingRefusal.proofNotFound ||
  CoachingRefusal.attemptsExhausted ||
  CoachingRefusal.cancelWindowClosed ||
  CoachingRefusal.payoutAccountPending ||
  CoachingRefusal.nothingOwed ||
  CoachingRefusal.accountsNotSet ||
  CoachingRefusal.sellerNotSet ||
  CoachingRefusal.planInvalid ||
  CoachingRefusal.planTooLarge ||
  CoachingRefusal.eatingHistoryHold ||
  CoachingRefusal.sessionLinkInvalid ||
  CoachingRefusal.sessionNotFound ||
  CoachingRefusal.sessionNotStarted ||
  CoachingRefusal.reportNotFound ||
  CoachingRefusal.staffIsSubject ||
  CoachingRefusal.mediaNotFound ||
  CoachingRefusal.tooManyMedia ||
  CoachingRefusal.messageBlocked ||
  CoachingRefusal.unknown => l10n.somethingWentWrongYourAnswersAreSaved,
};

/// A whole number from what she typed, in Western or Arabic-Indic digits.
int? parseApplyInt(String text) {
  return int.tryParse(westernDigits(text.trim()));
}
