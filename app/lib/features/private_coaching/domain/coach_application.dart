/// A coach's application, section by section, as `coachApplications/{uid}`
/// holds it and as `submit_coach_application` takes it.
///
/// [CoachApplication.missingSections] mirrors the server's required checks so
/// a step can say "needs this" before she submits. The server stays the judge.
library;

import 'coaching_contract.dart';
import 'parse.dart';

/// The coach terms version the server accepts (`TERMS_VERSION`).
const int kCoachTermsVersion = 1;

/// File types a certificate or a degree may be.
const List<String> kCertificateMimes = <String>[
  'image/jpeg',
  'image/png',
  'application/pdf',
];

class CoachPersonal {
  const CoachPersonal({
    this.fullName = '',
    this.displayName = '',
    this.governorate = '',
    this.languages = const <String>[],
    this.headline = '',
    this.photoPath = '',
  });

  final String fullName;
  final String displayName;
  final String governorate;
  final List<String> languages;
  final String headline;
  final String photoPath;

  CoachPersonal copyWith({
    String? fullName,
    String? displayName,
    String? governorate,
    List<String>? languages,
    String? headline,
    String? photoPath,
  }) => CoachPersonal(
    fullName: fullName ?? this.fullName,
    displayName: displayName ?? this.displayName,
    governorate: governorate ?? this.governorate,
    languages: languages ?? this.languages,
    headline: headline ?? this.headline,
    photoPath: photoPath ?? this.photoPath,
  );

  factory CoachPersonal.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return CoachPersonal(
      fullName: readString(map['fullName']),
      displayName: readString(map['displayName']),
      governorate: readString(map['governorate']),
      languages: readKnown(map['languages'], CoachingEnums.languages),
      headline: readString(map['headline']),
      photoPath: readString(map['photoPath']),
    );
  }

  Json toMap() => <String, Object?>{
    'fullName': fullName.trim(),
    'displayName': displayName.trim(),
    'governorate': governorate,
    'languages': languages,
    'headline': headline.trim(),
    'photoPath': photoPath,
  };

  bool get complete =>
      _between(fullName, 3, CoachingLimits.fullNameMax) &&
      _between(displayName, 2, CoachingLimits.displayNameMax) &&
      CoachingEnums.governorates.contains(governorate) &&
      languages.isNotEmpty &&
      languages.length <= 2 &&
      languages.toSet().length == languages.length &&
      _between(headline, 10, CoachingLimits.headlineMax) &&
      _pathOk(photoPath);
}

class CoachEducation {
  const CoachEducation({
    this.degree = '',
    this.institution = '',
    this.year,
    this.path = '',
  });

  final String degree;
  final String institution;
  final int? year;
  final String path;

  static CoachEducation? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    return CoachEducation(
      degree: readString(map['degree']),
      institution: readString(map['institution']),
      year: readIntOrNull(map['year']),
      path: readString(map['path']),
    );
  }

  Json toMap() => <String, Object?>{
    'degree': degree.trim(),
    'institution': institution.trim(),
    'year': year,
    'path': path.isEmpty ? null : path,
  };

  /// The proof file is optional for a degree.
  bool complete(int currentYear) =>
      _between(degree, 2, 80) &&
      _between(institution, 2, 80) &&
      _yearOk(year, currentYear) &&
      (path.isEmpty || _pathOk(path));
}

class CoachCertificate {
  const CoachCertificate({
    this.id = '',
    this.title = '',
    this.issuer = '',
    this.year,
    this.path = '',
    this.mime = '',
  });

  final String id;
  final String title;
  final String issuer;
  final int? year;
  final String path;
  final String mime;

  static CoachCertificate? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    return CoachCertificate(
      id: readString(map['id']),
      title: readString(map['title']),
      issuer: readString(map['issuer']),
      year: readIntOrNull(map['year']),
      path: readString(map['path']),
      mime: readString(map['mime']),
    );
  }

  Json toMap() => <String, Object?>{
    'id': id,
    'title': title.trim(),
    'issuer': issuer.trim(),
    'year': year,
    'path': path,
    'mime': mime,
  };

  bool complete(int currentYear) =>
      RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(id) &&
      _between(title, 2, 80) &&
      _between(issuer, 2, 80) &&
      _yearOk(year, currentYear) &&
      _pathOk(path) &&
      kCertificateMimes.contains(mime);
}

class CoachTestimonial {
  const CoachTestimonial({
    this.text = '',
    this.from = '',
    this.source = '',
    this.imagePath,
  });

  final String text;
  final String from;
  final String source;
  final String? imagePath;

  static CoachTestimonial? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    return CoachTestimonial(
      text: readString(map['text']),
      from: readString(map['from']),
      source: readString(map['source']),
      imagePath: readStringOrNull(map['imagePath']),
    );
  }

  Json toMap() => <String, Object?>{
    'text': text.trim(),
    'from': from.trim(),
    'source': source,
    'imagePath': ?imagePath,
  };

  bool get complete =>
      _between(text, 10, CoachingLimits.testimonialTextMax) &&
      _between(from, 1, 40) &&
      CoachingEnums.testimonialSource.contains(source) &&
      (imagePath == null || _pathOk(imagePath!));
}

class CoachTransformation {
  const CoachTransformation({
    this.beforePath = '',
    this.afterPath = '',
    this.weeks = 0,
    this.note = '',
    this.clientConsent = false,
  });

  final String beforePath;
  final String afterPath;
  final int weeks;
  final String note;
  final bool clientConsent;

  static CoachTransformation? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    return CoachTransformation(
      beforePath: readString(map['beforePath']),
      afterPath: readString(map['afterPath']),
      weeks: readInt(map['weeks']),
      note: readString(map['note']),
      clientConsent: readBool(map['clientConsent']),
    );
  }

  Json toMap() => <String, Object?>{
    'beforePath': beforePath,
    'afterPath': afterPath,
    'weeks': weeks,
    'note': note.trim(),
    'clientConsent': clientConsent,
  };

  /// Her photo of another woman is only ever sent with that woman's consent.
  bool get complete =>
      _pathOk(beforePath) &&
      _pathOk(afterPath) &&
      weeks >= 1 &&
      weeks <= 104 &&
      note.trim().length <= 300 &&
      clientConsent;
}

class CoachApproach {
  const CoachApproach({
    this.text = '',
    this.checkInsPerWeek = 0,
    this.replyHours = 0,
    this.trainsWhere = const <String>[],
  });

  final String text;
  final int checkInsPerWeek;
  final int replyHours;
  final List<String> trainsWhere;

  CoachApproach copyWith({
    String? text,
    int? checkInsPerWeek,
    int? replyHours,
    List<String>? trainsWhere,
  }) => CoachApproach(
    text: text ?? this.text,
    checkInsPerWeek: checkInsPerWeek ?? this.checkInsPerWeek,
    replyHours: replyHours ?? this.replyHours,
    trainsWhere: trainsWhere ?? this.trainsWhere,
  );

  factory CoachApproach.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return CoachApproach(
      text: readString(map['text']),
      checkInsPerWeek: readInt(map['checkInsPerWeek']),
      replyHours: readInt(map['replyHours']),
      trainsWhere: readKnown(map['trainsWhere'], CoachingEnums.trainsWhere),
    );
  }

  Json toMap() => <String, Object?>{
    'text': text.trim(),
    'checkInsPerWeek': checkInsPerWeek,
    'replyHours': replyHours,
    'trainsWhere': trainsWhere,
  };

  bool get complete =>
      text.trim().length >= CoachingLimits.approachTextMin &&
      text.trim().length <= CoachingLimits.approachTextMax &&
      checkInsPerWeek >= 0 &&
      checkInsPerWeek <= CoachingLimits.checkInsPerWeekMax &&
      CoachingEnums.replyHours.contains(replyHours) &&
      trainsWhere.isNotEmpty &&
      trainsWhere.length <= 3 &&
      trainsWhere.toSet().length == trainsWhere.length;
}

class CoachPayoutAccount {
  const CoachPayoutAccount({
    this.rail = '',
    this.account = '',
    this.holderName = '',
  });

  final String rail;
  final String account;
  final String holderName;

  CoachPayoutAccount copyWith({
    String? rail,
    String? account,
    String? holderName,
  }) => CoachPayoutAccount(
    rail: rail ?? this.rail,
    account: account ?? this.account,
    holderName: holderName ?? this.holderName,
  );

  factory CoachPayoutAccount.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return CoachPayoutAccount(
      rail: readString(map['rail']),
      account: readString(map['account']),
      holderName: readString(map['holderName']),
    );
  }

  Json toMap() => <String, Object?>{
    'rail': rail,
    'account': account.trim(),
    'holderName': holderName.trim(),
  };

  bool get complete =>
      accountMatchesRail(rail, account.trim()) &&
      _between(holderName, 3, CoachingLimits.fullNameMax);
}

/// Whether [account] looks like an account on [rail] (the contract's pattern).
bool accountMatchesRail(String rail, String account) {
  final pattern = CoachingRails.accountPattern[rail];
  return pattern != null && RegExp(pattern).hasMatch(account);
}

/// Whether [reference] looks like a transfer reference on [rail].
bool referenceMatchesRail(String rail, String reference) {
  final pattern = CoachingRails.referencePattern[rail];
  return pattern != null && RegExp(pattern).hasMatch(reference);
}

class CoachApplication {
  const CoachApplication({
    this.status,
    this.round = 0,
    this.personal = const CoachPersonal(),
    this.education = const <CoachEducation>[],
    this.certificates = const <CoachCertificate>[],
    this.specialties = const <String>[],
    this.qualifications = '',
    this.yearsExperience,
    this.testimonials = const <CoachTestimonial>[],
    this.transformations = const <CoachTransformation>[],
    this.approach = const CoachApproach(),
    this.payout = const CoachPayoutAccount(),
    this.termsVersion = 0,
    this.rules = const <String>[],
    this.reasons = const <String, String>{},
    this.note = '',
    this.submittedAt,
    this.decidedAt,
    this.payoutOptional = false,
  });

  /// True while payments are off: the payout account is neither asked for nor
  /// sent, and [missingSections] does not list it.
  final bool payoutOptional;

  /// Null for a draft that was never sent.
  final ApplicationStatus? status;
  final int round;
  final CoachPersonal personal;
  final List<CoachEducation> education;
  final List<CoachCertificate> certificates;
  final List<String> specialties;
  final String qualifications;
  final int? yearsExperience;
  final List<CoachTestimonial> testimonials;
  final List<CoachTransformation> transformations;
  final CoachApproach approach;
  final CoachPayoutAccount payout;
  final int termsVersion;
  final List<String> rules;

  /// Section name to reason code, from the reviewer, when changes are asked for.
  final Map<String, String> reasons;
  final String note;
  final DateTime? submittedAt;
  final DateTime? decidedAt;

  CoachApplication copyWith({
    CoachPersonal? personal,
    List<CoachEducation>? education,
    List<CoachCertificate>? certificates,
    List<String>? specialties,
    String? qualifications,
    int? yearsExperience,
    List<CoachTestimonial>? testimonials,
    List<CoachTransformation>? transformations,
    CoachApproach? approach,
    CoachPayoutAccount? payout,
    int? termsVersion,
    List<String>? rules,
  }) => CoachApplication(
    payoutOptional: payoutOptional,
    status: status,
    round: round,
    personal: personal ?? this.personal,
    education: education ?? this.education,
    certificates: certificates ?? this.certificates,
    specialties: specialties ?? this.specialties,
    qualifications: qualifications ?? this.qualifications,
    yearsExperience: yearsExperience ?? this.yearsExperience,
    testimonials: testimonials ?? this.testimonials,
    transformations: transformations ?? this.transformations,
    approach: approach ?? this.approach,
    payout: payout ?? this.payout,
    termsVersion: termsVersion ?? this.termsVersion,
    rules: rules ?? this.rules,
    reasons: reasons,
    note: note,
    submittedAt: submittedAt,
    decidedAt: decidedAt,
  );

  /// Reads a stored application or a draft kept on the phone. Never throws.
  factory CoachApplication.fromMap(Object? raw, {bool payoutOptional = false}) {
    final map = asMap(raw) ?? const <String, Object?>{};
    final reasons = asMap(map['reasons']);
    return CoachApplication(
      payoutOptional: payoutOptional,
      status: ApplicationStatus.fromWire(map['status']),
      round: readInt(map['round']),
      personal: CoachPersonal.fromMap(map['personal']),
      education: <CoachEducation>[
        for (final row in readMaps(map['education']))
          ?CoachEducation.fromMap(row),
      ],
      certificates: <CoachCertificate>[
        for (final row in readMaps(map['certificates']))
          ?CoachCertificate.fromMap(row),
      ],
      specialties: readKnown(map['specialties'], CoachingEnums.specialties),
      qualifications: readString(map['qualifications']),
      yearsExperience: readIntOrNull(map['yearsExperience']),
      testimonials: <CoachTestimonial>[
        for (final row in readMaps(map['testimonials']))
          ?CoachTestimonial.fromMap(row),
      ],
      transformations: <CoachTransformation>[
        for (final row in readMaps(map['transformations']))
          ?CoachTransformation.fromMap(row),
      ],
      approach: CoachApproach.fromMap(map['approach']),
      payout: CoachPayoutAccount.fromMap(map['payout']),
      termsVersion: readInt(map['termsVersion']),
      rules: readKnown(map['rules'], CoachingEnums.coachRules),
      reasons: <String, String>{
        if (reasons != null)
          for (final entry in reasons.entries)
            if (entry.value is String) entry.key: entry.value as String,
      },
      note: readString(map['note']),
      submittedAt: readTime(map['submittedAt']),
      decidedAt: readTime(map['decidedAt']),
    );
  }

  /// The sections as the server stores them (also what a phone draft keeps).
  Json toMap() => <String, Object?>{
    'personal': personal.toMap(),
    'education': <Object?>[for (final e in education) e.toMap()],
    'certificates': <Object?>[for (final c in certificates) c.toMap()],
    'specialties': specialties,
    'qualifications': qualifications.trim(),
    'yearsExperience': yearsExperience,
    'testimonials': <Object?>[for (final t in testimonials) t.toMap()],
    'transformations': <Object?>[for (final t in transformations) t.toMap()],
    'approach': approach.toMap(),
    if (!payoutOptional) 'payout': payout.toMap(),
    'termsVersion': termsVersion,
    'rules': rules,
  };

  /// The body of `submit_coach_application`.
  Json toRequest({required String locale}) => <String, Object?>{
    ...toMap(),
    'locale': locale,
  };

  /// The contract's section names that are not complete yet, in the order of
  /// the steps. Empty means the server will accept it.
  ///
  /// Education also holds the qualifications text and the years of experience;
  /// feedback is the testimonials.
  List<String> missingSections({DateTime? now}) {
    final year = (now ?? DateTime.now()).year;
    bool uniqueBetween(List<Object?> l, int low, int high) =>
        l.length >= low && l.length <= high;
    final missing = <String>[];
    if (!personal.complete) missing.add('personal');
    if (!(uniqueBetween(
          education,
          CoachingLimits.educationMin,
          CoachingLimits.educationMax,
        ) &&
        education.every((e) => e.complete(year)) &&
        _between(qualifications, 20, CoachingLimits.qualificationsMax) &&
        yearsExperience != null &&
        yearsExperience! >= 0 &&
        yearsExperience! <= CoachingLimits.yearsExperienceMax)) {
      missing.add('education');
    }
    if (!(uniqueBetween(
          certificates,
          CoachingLimits.certificatesMin,
          CoachingLimits.certificatesMax,
        ) &&
        certificates.every((c) => c.complete(year)) &&
        certificates.map((c) => c.id).toSet().length == certificates.length)) {
      missing.add('certificates');
    }
    if (!(uniqueBetween(
          specialties,
          CoachingLimits.specialtiesMin,
          CoachingLimits.specialtiesMax,
        ) &&
        specialties.toSet().length == specialties.length)) {
      missing.add('specialties');
    }
    if (!(uniqueBetween(
          testimonials,
          CoachingLimits.testimonialsMin,
          CoachingLimits.testimonialsMax,
        ) &&
        testimonials.every((t) => t.complete))) {
      missing.add('feedback');
    }
    if (!(uniqueBetween(
          transformations,
          CoachingLimits.transformationsMin,
          CoachingLimits.transformationsMax,
        ) &&
        transformations.every((t) => t.complete))) {
      missing.add('transformations');
    }
    if (!approach.complete) missing.add('approach');
    if (!payoutOptional && !payout.complete) missing.add('payout');
    if (termsVersion != kCoachTermsVersion ||
        rules.length != CoachingEnums.coachRules.length ||
        !CoachingEnums.coachRules.every(rules.contains)) {
      missing.add('terms');
    }
    return missing;
  }

  bool canSubmit({DateTime? now}) => missingSections(now: now).isEmpty;

  /// Sections the reviewer asked her to fix.
  List<String> get sectionsNeedingChanges => <String>[
    for (final section in CoachingEnums.applicationSections)
      if (reasons.containsKey(section)) section,
  ];
}

bool _between(String value, int min, int max) {
  final length = value.trim().length;
  return length >= min && length <= max;
}

bool _pathOk(String path) => path.isNotEmpty && path.length <= 300;

bool _yearOk(int? year, int currentYear) =>
    year != null && year >= 1960 && year <= currentYear;
