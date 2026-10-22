/// What a client sees of a coach, and the packages she sells.
///
/// Nothing here carries the coach's own price or Own Hub's margin: those live
/// only under `coachPrivate/` and the server never sends them to a client.
library;

import 'coaching_contract.dart';
import 'parse.dart';
import 'pricing.dart' as price;

class CoachStats {
  const CoachStats({
    this.clientsCoached = 0,
    this.plansShared = 0,
    this.sessionsDone = 0,
  });

  final int clientsCoached;
  final int plansShared;
  final int sessionsDone;

  factory CoachStats.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return CoachStats(
      clientsCoached: readInt(map['clientsCoached']),
      plansShared: readInt(map['plansShared']),
      sessionsDone: readInt(map['sessionsDone']),
    );
  }
}

class PublicCertificate {
  const PublicCertificate({this.title = '', this.issuer = '', this.year});

  final String title;
  final String issuer;
  final int? year;

  static PublicCertificate? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final title = readString(map['title']);
    if (title.isEmpty) return null;
    return PublicCertificate(
      title: title,
      issuer: readString(map['issuer']),
      year: readIntOrNull(map['year']),
    );
  }
}

class PublicTestimonial {
  const PublicTestimonial({this.text = '', this.from = ''});

  final String text;
  final String from;

  static PublicTestimonial? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final text = readString(map['text']);
    if (text.isEmpty) return null;
    return PublicTestimonial(text: text, from: readString(map['from']));
  }
}

class CoachProfile {
  const CoachProfile({
    required this.uid,
    this.displayName = '',
    this.headline = '',
    this.photoUrl,
    this.governorate = '',
    this.languages = const <String>[],
    this.specialties = const <String>[],
    this.approach = '',
    this.yearsExperience = 0,
    this.certificates = const <PublicCertificate>[],
    this.testimonials = const <PublicTestimonial>[],
    this.badges = const <String>[],
    this.stats = const CoachStats(),
    this.fromPriceEgp,
    this.fromMonthlyEgp,
    this.acceptingClients = false,
    this.autoAccept = false,
    this.maxActiveClients = CoachingLimits.maxActiveClientsDefault,
    this.activeClients = 0,
    this.published = false,
    this.replyHours,
    this.trainsWhere = const <String>[],
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String headline;
  final String? photoUrl;
  final String governorate;
  final List<String> languages;
  final List<String> specialties;
  final String approach;
  final int yearsExperience;
  final List<PublicCertificate> certificates;
  final List<PublicTestimonial> testimonials;
  final List<String> badges;
  final CoachStats stats;

  /// The cheapest active package's final price, if she has one.
  final int? fromPriceEgp;

  /// The cheapest active package's price for 28 days, if she has one.
  final int? fromMonthlyEgp;
  final bool acceptingClients;
  final bool autoAccept;
  final int maxActiveClients;
  final int activeClients;
  final bool published;
  final int? replyHours;
  final List<String> trainsWhere;
  final DateTime? updatedAt;

  bool get hasRoom => activeClients < maxActiveClients;

  /// Null when the document is not a coach (an empty map).
  static CoachProfile? fromMap(String uid, Object? raw) {
    final map = asMap(raw);
    if (map == null || uid.isEmpty || map.isEmpty) return null;
    final approach = map['approach'];
    return CoachProfile(
      uid: uid,
      displayName: readString(map['displayName']),
      headline: readString(map['headline']),
      photoUrl: readStringOrNull(map['photoUrl']),
      governorate: readString(map['governorate']),
      languages: readKnown(map['languages'], CoachingEnums.languages),
      specialties: readKnown(map['specialties'], CoachingEnums.specialties),
      approach: approach is Map
          ? readString(approach['text'])
          : readString(approach),
      yearsExperience: readInt(map['yearsExperience']),
      certificates: <PublicCertificate>[
        for (final row in readMaps(map['certificates']))
          ?PublicCertificate.fromMap(row),
      ],
      testimonials: <PublicTestimonial>[
        for (final row in readMaps(map['testimonials']))
          ?PublicTestimonial.fromMap(row),
      ],
      badges: readKnown(map['badges'], const <String>[
        'verifiedCoach',
        'certificatesChecked',
        'yearsCoaching',
      ]),
      stats: CoachStats.fromMap(map['stats']),
      fromPriceEgp: readIntOrNull(map['fromPriceEgp']),
      fromMonthlyEgp: readIntOrNull(map['fromMonthlyEgp']),
      acceptingClients: readBool(map['acceptingClients']),
      autoAccept: readBool(map['autoAccept']),
      maxActiveClients: readInt(
        map['maxActiveClients'],
        CoachingLimits.maxActiveClientsDefault,
      ),
      activeClients: readInt(map['activeClients']),
      published: readBool(map['published']),
      replyHours: readIntOrNull(map['replyHours']),
      trainsWhere: readKnown(map['trainsWhere'], CoachingEnums.trainsWhere),
      updatedAt: readTime(map['updatedAt']),
    );
  }
}

/// A package as the client reads it. The price is final: taxes and fees in.
class CoachPackage {
  const CoachPackage({
    required this.id,
    this.title = '',
    this.description = '',
    this.durationDays = 28,
    this.includes = const <String>[],
    this.liveSessionsPerMonth = CoachingLimits.liveSessionsPerMonthMin,
    this.sessionMinutes = 30,
    this.checkInsPerWeek = 0,
    this.priceFinalEgp = 0,
    this.active = false,
    this.order = 0,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final int durationDays;
  final List<String> includes;
  final int liveSessionsPerMonth;
  final int sessionMinutes;
  final int checkInsPerWeek;
  final int priceFinalEgp;
  final bool active;
  final int order;
  final DateTime? updatedAt;

  int get sessionsIncluded =>
      price.sessionsIncluded(liveSessionsPerMonth, durationDays);

  int get monthlyEquivalent =>
      price.monthlyEquivalent(priceFinalEgp, durationDays);

  /// Null when it has no id, no title or no price to show.
  static CoachPackage? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final title = readString(map['title']);
    final priceFinal = readInt(map['priceFinalEgp']);
    final duration = readInt(map['durationDays'], 28);
    if (title.isEmpty || priceFinal <= 0 || duration <= 0) return null;
    return CoachPackage(
      id: id,
      title: title,
      description: readString(map['description']),
      durationDays: duration,
      includes: readStrings(map['includes']),
      liveSessionsPerMonth: readInt(
        map['liveSessionsPerMonth'],
        CoachingLimits.liveSessionsPerMonthMin,
      ),
      sessionMinutes: readInt(map['sessionMinutes'], 30),
      checkInsPerWeek: readInt(map['checkInsPerWeek']),
      priceFinalEgp: priceFinal,
      active: readBool(map['active']),
      order: readInt(map['order']),
      updatedAt: readTime(map['updatedAt']),
    );
  }

  /// The copy a subscription keeps of what she bought.
  PackageSnapshot get snapshot => PackageSnapshot(
    title: title,
    description: description,
    durationDays: durationDays,
    includes: includes,
    liveSessionsPerMonth: liveSessionsPerMonth,
    sessionMinutes: sessionMinutes,
    checkInsPerWeek: checkInsPerWeek,
  );
}

/// What a subscription remembers of its package.
class PackageSnapshot {
  const PackageSnapshot({
    this.title = '',
    this.description = '',
    this.durationDays = 28,
    this.includes = const <String>[],
    this.liveSessionsPerMonth = 0,
    this.sessionMinutes = 0,
    this.checkInsPerWeek = 0,
  });

  final String title;
  final String description;
  final int durationDays;
  final List<String> includes;
  final int liveSessionsPerMonth;
  final int sessionMinutes;
  final int checkInsPerWeek;

  factory PackageSnapshot.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return PackageSnapshot(
      title: readString(map['title']),
      description: readString(map['description']),
      durationDays: readInt(map['durationDays'], 28),
      includes: readStrings(map['includes']),
      liveSessionsPerMonth: readInt(map['liveSessionsPerMonth']),
      sessionMinutes: readInt(map['sessionMinutes']),
      checkInsPerWeek: readInt(map['checkInsPerWeek']),
    );
  }
}

/// A package the coach is writing. The server does the final check and prices
/// it; [problems] lets the form say what is wrong first.
class PackageDraft {
  const PackageDraft({
    this.packageId,
    this.title = '',
    this.description = '',
    this.durationDays = 28,
    this.includes = const <String>[],
    this.liveSessionsPerMonth = CoachingLimits.liveSessionsPerMonthMin,
    this.sessionMinutes = 30,
    this.checkInsPerWeek = 0,
    this.coachPriceEgp = 0,
    this.active = true,
    this.order = 0,
  });

  final String? packageId;
  final String title;
  final String description;
  final int durationDays;
  final List<String> includes;
  final int liveSessionsPerMonth;
  final int sessionMinutes;
  final int checkInsPerWeek;
  final int coachPriceEgp;
  final bool active;
  final int order;

  /// What the client will pay.
  int get priceFinalEgp => price.finalPrice(coachPriceEgp);

  /// What the coach receives: her own price.
  int get youReceiveEgp => coachPriceEgp;

  /// The fields that fail the server's checks, by request key.
  List<String> problems() {
    final out = <String>[];
    final t = title.trim();
    if (t.isEmpty || t.length > CoachingLimits.packageTitleMax) {
      out.add('title');
    }
    if (description.trim().length > CoachingLimits.packageDescriptionMax) {
      out.add('description');
    }
    if (!CoachingLimits.durationDays.contains(durationDays)) {
      out.add('durationDays');
    }
    if (includes.length > CoachingLimits.includesMax ||
        includes.any(
          (i) =>
              i.trim().isEmpty ||
              i.trim().length > CoachingLimits.includeTextMax,
        )) {
      out.add('includes');
    }
    if (liveSessionsPerMonth < CoachingLimits.liveSessionsPerMonthMin ||
        liveSessionsPerMonth > CoachingLimits.liveSessionsPerMonthMax) {
      out.add('liveSessionsPerMonth');
    }
    if (!CoachingLimits.sessionMinutes.contains(sessionMinutes)) {
      out.add('sessionMinutes');
    }
    if (checkInsPerWeek < 0 ||
        checkInsPerWeek > CoachingLimits.checkInsPerWeekMax) {
      out.add('checkInsPerWeek');
    }
    if (!price.coachPriceInRange(coachPriceEgp)) out.add('coachPriceEgp');
    if (order < 0 || order >= CoachingLimits.maxPackages) out.add('order');
    return out;
  }

  Json toRequest() => <String, Object?>{
    'packageId': ?packageId,
    'title': title.trim(),
    'description': description.trim(),
    'durationDays': durationDays,
    'includes': <String>[for (final i in includes) i.trim()],
    'liveSessionsPerMonth': liveSessionsPerMonth,
    'sessionMinutes': sessionMinutes,
    'checkInsPerWeek': checkInsPerWeek,
    'coachPriceEgp': coachPriceEgp,
    'active': active,
    'order': order,
  };
}
