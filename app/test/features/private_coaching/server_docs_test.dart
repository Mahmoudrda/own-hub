// The documents the real server wrote during the end-to-end run, read by the
// app's own models. Regenerate the fixture with `app/tool/e2e_coaching.sh dump`
// (local emulators only); times in it are ISO strings, which `readTime` takes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/approved_media.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/payments.dart';
import 'package:own_hub/features/private_coaching/domain/portfolio_media.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';

const _fixture = 'test/fixtures/coaching_server_docs.json';

void main() {
  final file = File(_fixture);
  if (!file.existsSync()) {
    test(
      'server documents',
      () {},
      skip: 'run app/tool/e2e_coaching.sh dump to create $_fixture',
    );
    return;
  }

  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final uids = (root['uids'] as Map).cast<String, String>();
  final made = (root['created'] as Map).cast<String, Object?>();
  final docs = (root['docs'] as Map).cast<String, Map<String, dynamic>>();
  final coach = uids['coach']!;
  final client = uids['client']!;
  final rel = '${coach}__$client';

  /// Documents directly under [collection] (a path), as (id, fields).
  Iterable<MapEntry<String, Map<String, dynamic>>> under(String collection) =>
      docs.entries
          .where(
            (e) =>
                e.key.startsWith('$collection/') &&
                !e.key.substring(collection.length + 1).contains('/'),
          )
          .map((e) => MapEntry(e.key.split('/').last, e.value));

  Map<String, dynamic> one(String path) {
    final doc = docs[path];
    expect(doc, isNotNull, reason: 'the run wrote no $path');
    return doc!;
  }

  test('the fixture holds the run', () {
    expect(docs, isNotEmpty);
    expect(made['sub'], isA<String>());
  });

  test('the coach application', () {
    final app = CoachApplication.fromMap(one('coachApplications/$coach'));
    expect(app.status, ApplicationStatus.approved);
    expect(app.personal.displayName, 'Mona');
    expect(app.certificates, hasLength(2));
    expect(app.transformations, hasLength(1));
    expect(app.education, hasLength(2));
    expect(app.testimonials, hasLength(2));
    expect(app.specialties, containsAll(<String>['strength', 'fatLoss']));
    expect(app.termsVersion, 1);
  });

  test('the public coach page and her package', () {
    final profile = CoachProfile.fromMap(coach, one('coaches/$coach'));
    expect(profile, isNotNull);
    expect(profile!.displayName, 'Mona');
    expect(profile.headline, contains('Cairo'));
    expect(profile.published, isTrue);
    expect(profile.fromPriceEgp, 1150);
    expect(profile.fromMonthlyEgp, 1150);

    final packages = [
      for (final e in under('coaches/$coach/packages'))
        CoachPackage.fromMap(e.key, e.value),
    ];
    expect(packages, hasLength(1));
    final pkg = packages.single!;
    expect(pkg.id, made['package']);
    expect(pkg.title, 'Strong in four weeks');
    expect(pkg.priceFinalEgp, 1150);
    expect(pkg.durationDays, 28);
    expect(pkg.active, isTrue);
  });

  test('portfolio media, as members and as the coach read it', () {
    final rows = under('coaches/$coach/media').toList();
    // The coach sees every item, including the ones copied from her
    // application that wait for her consent or the reviewer.
    final mine = [for (final e in rows) PortfolioMedia.fromMap(e.key, e.value)];
    expect(mine, everyElement(isNotNull));
    expect(rows.length, greaterThan(3));
    // Members query only approved items (the rule refuses anything else).
    final approved = [
      for (final e in rows)
        if (e.value['status'] == 'approved')
          ApprovedMedia.fromMap(e.key, e.value),
    ];
    expect(approved, hasLength(3));
    expect(approved, everyElement(isNotNull));
    expect(
      {for (final m in approved) m!.kind},
      {MediaKind.transformation, MediaKind.feedback, MediaKind.photo},
    );
    final transformation = approved.firstWhere(
      (m) => m!.kind == MediaKind.transformation,
    )!;
    expect(transformation.weeks, 12);
    expect(transformation.beforePath, startsWith('coach-public/$coach/'));
    expect(transformation.afterPath, startsWith('coach-public/$coach/'));
    // The three she added were approved; the two copied from her application
    // wait for her consent (transformation) or the reviewer (feedback).
    expect(
      mine.map((m) => m!.status),
      containsAll(<MediaStatus>[MediaStatus.approved, MediaStatus.pending]),
    );
    expect(mine.where((m) => m!.status == MediaStatus.approved), hasLength(3));
  });

  test('the coach private summary and her own price', () {
    final summary = CoachPrivateSummary.fromMap(one('coachPrivate/$coach'));
    expect(summary, isNotNull);
    expect(summary!.suspended, isFalse);
    final price = one('coachPrivate/$coach/prices/${made['package']}');
    expect(price['coachPriceEgp'], 1000);
  });

  test('ledger and receipts parse when payments ever wrote any', () {
    for (final e in under('coachPrivate/$coach/ledger')) {
      expect(LedgerEntry.fromMap(e.key, e.value), isNotNull, reason: e.key);
    }
    for (final e in under('receipts')) {
      expect(Receipt.fromMap(e.key, e.value), isNotNull, reason: e.key);
    }
  });

  test('the subscription, free and ended by staff', () {
    final subId = made['sub']! as String;
    final sub = Subscription.fromMap(subId, one('subscriptions/$subId'));
    expect(sub, isNotNull);
    expect(sub!.coachUid, coach);
    expect(sub.clientUid, client);
    expect(sub.relId, rel);
    expect(sub.packageId, made['package']);
    expect(sub.package.title, 'Strong in four weeks');
    expect(sub.sessionsUsed, 1);
    expect(sub.startsAt, isNotNull);
    expect(sub.endsAt, isNotNull);
    expect(sub.status, SubscriptionStatus.endedEarly);
    final intake = sub.intake!;
    expect(intake.goal, 'stronger');
    expect(intake.level, 'beginner');
    expect(intake.daysPerWeek, 3);
    expect(intake.allergies, contains('peanut'));
    expect(intake.note, 'hello');
    // The coach's list fields come from the same document.
    expect(sub.clientName, one('subscriptions/$subId')['clientName'] ?? '');
  });

  test('the live session, done by both', () {
    final subId = made['sub']! as String;
    final rows = [
      for (final e in under('subscriptions/$subId/sessions'))
        LiveSession.fromMap(e.key, e.value),
    ];
    expect(rows, hasLength(1));
    final session = rows.single!;
    expect(session.id, made['session']);
    expect(session.status, SessionStatus.done);
    expect(session.doneBy, containsAll(<String>[coach, client]));
    expect(session.minutes, 45);
    expect(session.proposedBy, coach);
    expect(session.link, contains('meet.google.com'));
    expect(session.startsAt, isNotNull);
  });

  test('the relationship with its last line and unread counters', () {
    final relationship = Relationship.fromMap(rel, one('relationships/$rel'));
    expect(relationship, isNotNull);
    expect(relationship!.coachUid, coach);
    expect(relationship.clientUid, client);
    expect(relationship.status, RelationshipStatus.ended);
    expect(relationship.lastMessage, isNotNull);
    // A system line carries no text; the chat list words it by its type.
    expect(relationship.lastMessage!.text.length, lessThanOrEqualTo(80));
    if (relationship.lastMessage!.text.isEmpty) {
      expect(relationship.lastMessage!.type, isNot(MessageType.text));
    }
    expect(relationship.lastMessageAt, isNotNull);
    expect(
      relationship.unreadFor.keys,
      everyElement(isIn(<String>[coach, client])),
    );
    expect(docs.keys, contains('relationships/$rel/reads/$client'));
  });

  test('every chat line, whatever its type', () {
    final messages = [
      for (final e in under('relationships/$rel/messages'))
        ChatMessage.fromMap(e.key, e.value),
    ];
    expect(messages, isNotEmpty);
    expect(messages, everyElement(isNotNull));
    final types = {for (final m in messages) m!.type};
    expect(
      types,
      containsAll(<MessageType>[
        MessageType.text,
        MessageType.workoutPlan,
        MessageType.mealPlan,
        MessageType.session,
      ]),
    );
    final texts = [
      for (final m in messages)
        if (m!.type == MessageType.text) m.text,
    ];
    expect(texts, contains('Hello coach, I am ready to start'));
    expect(texts, contains('Welcome, let us begin on Sunday'));
    final cards = messages.where((m) => m!.type == MessageType.workoutPlan);
    expect(cards.single!.planId, made['workoutPlan']);
    final session = messages.firstWhere((m) => m!.type == MessageType.session)!;
    expect(session.sessionId, made['session']);
    expect(session.minutes, 45);
    expect(session.startsAt, isNotNull);
    // Every line has a sender and a server time.
    expect(messages.every((m) => m!.senderUid.isNotEmpty), isTrue);
    expect(messages.every((m) => m!.createdAt != null), isTrue);
  });

  test('the shared workout and meal plans', () {
    final plans = [
      for (final e in under('plans/$client/coachPlans'))
        CoachPlan.fromMap(e.key, e.value),
    ];
    expect(plans, hasLength(2));
    expect(plans, everyElement(isNotNull));
    final workout = plans.firstWhere((p) => p!.kind == PlanKind.workout)!;
    expect(workout.id, made['workoutPlan']);
    expect(workout.coachUid, coach);
    expect(workout.subId, made['sub']);
    expect(workout.name, 'My workout plan');
    expect(workout.revision, 1);
    expect(workout.workout!.days, hasLength(1));
    final meal = plans.firstWhere((p) => p!.kind == PlanKind.meal)!;
    expect(meal.id, made['mealPlan']);
    expect(meal.meal!.days, hasLength(1));
    expect(meal.meal!.days.single.label, 'Day 1');
    expect(meal.publishedAt, isNotNull);
  });
}
