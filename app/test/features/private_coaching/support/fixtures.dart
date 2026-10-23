import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';

final DateTime kNow = DateTime.utc(2026, 10, 24, 12);

CoachApplication completeApplication() => CoachApplication(
  personal: const CoachPersonal(
    fullName: 'Sara Hassan Ali',
    displayName: 'Coach Sara',
    governorate: 'cairo',
    languages: <String>['ar', 'en'],
    headline: 'Strength coach for busy women',
    photoPath: 'coach-docs/u1/photo/a1.jpg',
  ),
  education: const <CoachEducation>[
    CoachEducation(
      degree: 'BSc Sport Science',
      institution: 'Cairo University',
      year: 2016,
    ),
  ],
  certificates: const <CoachCertificate>[
    CoachCertificate(
      id: 'cert-1',
      title: 'Level 3 Personal Trainer',
      issuer: 'REPs',
      year: 2019,
      path: 'coach-docs/u1/certificates/b1.pdf',
      mime: 'application/pdf',
    ),
  ],
  specialties: const <String>['strength', 'fatLoss'],
  qualifications: 'Level 3 trainer, nutrition coaching course, first aid.',
  yearsExperience: 6,
  testimonials: const <CoachTestimonial>[
    CoachTestimonial(
      text: 'Sara changed how I train, very patient.',
      from: 'Mona',
      source: 'whatsapp',
    ),
    CoachTestimonial(
      text: 'Clear plans and quick replies every day.',
      from: 'Nour',
      source: 'instagram',
    ),
  ],
  transformations: const <CoachTransformation>[
    CoachTransformation(
      beforePath: 'coach-docs/u1/transformations/c1.jpg',
      afterPath: 'coach-docs/u1/transformations/c2.jpg',
      weeks: 12,
      note: 'Twelve weeks, three sessions a week.',
      clientConsent: true,
    ),
  ],
  approach: CoachApproach(
    text:
        'I build slow, steady plans around your week, then check in often. ' *
        2,
    checkInsPerWeek: 2,
    replyHours: 12,
    trainsWhere: const <String>['home', 'gym'],
  ),
  payout: const CoachPayoutAccount(
    rail: 'instapay',
    account: 'sara.h@instapay',
    holderName: 'Sara Hassan Ali',
  ),
  termsVersion: kCoachTermsVersion,
  rules: List<String>.of(CoachingEnums.coachRules),
);

Intake validIntake() => Intake(
  goal: 'stronger',
  level: 'beginner',
  daysPerWeek: 3,
  place: 'home',
  health: {for (final q in CoachingEnums.healthQuestions) q: false},
);

CoachProfile coach(
  String uid,
  String name, {
  List<String> specialties = const <String>[],
  List<String> trainsWhere = const <String>[],
  bool published = true,
  bool accepting = true,
  int clientsCoached = 0,
  int? fromMonthlyEgp,
}) => CoachProfile(
  uid: uid,
  displayName: name,
  specialties: specialties,
  trainsWhere: trainsWhere,
  published: published,
  acceptingClients: accepting,
  fromMonthlyEgp: fromMonthlyEgp,
  stats: CoachStats(clientsCoached: clientsCoached),
);

CoachPackage package(
  String id, {
  int price = 1150,
  int days = 28,
  bool active = true,
}) => CoachPackage(
  id: id,
  title: 'Package $id',
  durationDays: days,
  priceFinalEgp: price,
  active: active,
);

Subscription sub(
  String id,
  SubscriptionStatus status, {
  String coachUid = 'coach1',
  String clientUid = 'me',
  DateTime? statusAt,
  DateTime? createdAt,
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? payBy,
  int attempts = 0,
  int sessionsIncluded = 4,
  int sessionsUsed = 0,
  int price = 1150,
  CancellationInfo? cancellation,
}) => Subscription(
  id: id,
  coachUid: coachUid,
  clientUid: clientUid,
  status: status,
  statusAt: statusAt,
  createdAt: createdAt,
  startsAt: startsAt,
  endsAt: endsAt,
  payBy: payBy,
  payment: PaymentState(attempts: attempts),
  sessionsIncluded: sessionsIncluded,
  sessionsUsed: sessionsUsed,
  priceFinalEgp: price,
  cancellation: cancellation,
);
