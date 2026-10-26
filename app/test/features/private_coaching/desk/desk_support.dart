import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// Local noon, so "today" means the same on any machine.
final DateTime kDeskNow = DateTime(2026, 10, 24, 12);

String relOf(String clientUid) => CoachingIds.relationshipId('me', clientUid);

Subscription deskSub(
  String id, {
  SubscriptionStatus status = SubscriptionStatus.active,
  String? clientUid,
  String name = '',
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? nextSessionAt,
  DateTime? createdAt,
  Intake? intake,
  DateTime? healthReviewedAt,
}) {
  final client = clientUid ?? 'u$id';
  return Subscription(
    id: id,
    coachUid: 'me',
    clientUid: client,
    status: status,
    relId: relOf(client),
    clientName: name,
    package: const PackageSnapshot(title: 'Strong in 4 weeks'),
    sessionsIncluded: 4,
    sessionsUsed: 1,
    startsAt: startsAt ?? kDeskNow.subtract(const Duration(days: 2)),
    endsAt: endsAt ?? kDeskNow.add(const Duration(days: 20)),
    nextSessionAt: nextSessionAt,
    createdAt: createdAt,
    intake: intake,
    healthReviewedAt: healthReviewedAt,
  );
}

Relationship deskRel(
  String clientUid, {
  DateTime? lastAt,
  String text = 'See you Thursday',
  String? sender,
  int unread = 0,
  MessageType type = MessageType.text,
}) => Relationship(
  id: relOf(clientUid),
  coachUid: 'me',
  clientUid: clientUid,
  status: RelationshipStatus.active,
  chatOpen: true,
  lastMessageAt: lastAt,
  lastMessage: lastAt == null
      ? null
      : LastMessage(
          text: text,
          type: type,
          senderUid: sender ?? clientUid,
          at: lastAt,
        ),
  unreadFor: unread > 0 ? <String, int>{'me': unread} : const {},
);

Intake deskIntake({bool health = false, bool ack = false}) => Intake(
  goal: 'stronger',
  level: 'beginner',
  daysPerWeek: 3,
  place: 'home',
  allergies: const <String>['peanuts'],
  health: {
    for (final q in CoachingEnums.healthQuestions) q: health && q == 'heart',
  },
  doctorAck: ack,
  note: 'Please go slowly',
);

Widget deskHost(Widget child, {String lang = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(Locale(lang)),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: child,
    );

void deskPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2880);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}
