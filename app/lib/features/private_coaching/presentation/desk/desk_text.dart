/// Words and short formats for the coach's desk, in her language. Numbers and
/// times are written with Western digits in both languages.
library;

import '../../../../l10n/app_l10n.dart';
import '../../domain/chat_message.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/subscription.dart';
import '../coaching_when.dart';
import '../member/coach_labels.dart' show goalLabel, placeLabel;
import 'desk_model.dart';

/// The client's name, or "Client #a1b2" when she gave none. The tag comes
/// from her uid, as in the chat list, so one woman has one tag everywhere.
String clientName(AppL10n l10n, Subscription sub) => sub.clientName.isEmpty
    ? l10n.clientTag(tagOf(sub.clientUid))
    : sub.clientName;

/// Her life stage as the intake sheet names it, or null for a value this
/// build does not know.
String? lifeStageText(AppL10n l10n, String wire) => switch (wire) {
  'none' => l10n.nothingRightNow,
  'postpartum' => l10n.afterABirth,
  'pregnant' => l10n.pregnant,
  'pain_injury' => l10n.aKneeBackOrShoulder,
  _ => null,
};

String levelLabel(AppL10n l10n, String level) => switch (level) {
  'beginner' => l10n.beginner,
  'intermediate' => l10n.intermediate,
  'advanced' => l10n.advanced,
  _ => level,
};

String declineReasonLabel(AppL10n l10n, CoachDeclineReason reason) =>
    switch (reason) {
      CoachDeclineReason.full => l10n.myPlacesAreFull,
      CoachDeclineReason.notAFit => l10n.notTheRightFit,
      CoachDeclineReason.needsDoctor => l10n.sheShouldSeeHerDoctorFirst,
      CoachDeclineReason.other => l10n.anotherReason,
    };

/// The health question as she answered it.
String healthQuestionLabel(AppL10n l10n, String id) => switch (id) {
  'heart' => l10n.hasADoctorEverSaidYouHave,
  'chestPain' => l10n.doYouFeelPainInYourChest,
  'dizziness' => l10n.doYouFeelDizzyOrFaintWhen,
  'chronicCondition' => l10n.doYouHaveALongTermCondition,
  'medication' => l10n.doYouTakeMedicationEveryDay,
  'boneJoint' => l10n.doYouHaveABoneOrJoint,
  'supervisedOnly' => l10n.hasADoctorToldYouToExercise,
  _ => id,
};

/// "12 days left", "1 day left" or "Ends today". Null unless it is active.
String? daysLeftText(AppL10n l10n, int? days) {
  if (days == null) return null;
  if (days <= 0) return l10n.endsToday;
  return l10n.daysPluralOne1DayLeftOther(days);
}

/// "Strength · Beginner · 3 days a week · At home".
String intakeSummary(AppL10n l10n, Intake intake) =>
    l10n.goalLevelDaysDaysAWeekPlace(
      goalLabel(l10n, intake.goal),
      levelLabel(l10n, intake.level),
      '${intake.daysPerWeek}',
      placeLabel(l10n, intake.place),
    );

/// One reason in words.
String reasonText(AppL10n l10n, DeskClient client, FollowUpReason reason) =>
    switch (reason) {
      FollowUpReason.sessionToday => l10n.liveSessionTodayAtTime(
        clockText(l10n, client.subscription.nextSessionAt),
      ),
      FollowUpReason.waitingReply => l10n.waitingForYourReply,
      FollowUpReason.endingSoon =>
        daysLeftText(l10n, client.daysLeft) ?? l10n.endsToday,
      FollowUpReason.quiet => l10n.noMessageFromYouInDaysDays(
        '${client.quietDays}',
      ),
    };

/// Every reason, joined with a middle dot.
String reasonsText(AppL10n l10n, DeskClient client) =>
    <String>[for (final r in client.reasons) reasonText(l10n, client, r)]
        .join(' · ');

/// The last line in the chat list: "You: ..." for hers, a label for a card.
String previewText(AppL10n l10n, LastMessage? last, String? myUid) {
  if (last == null) return l10n.noMessagesYet;
  final body = switch (last.type) {
    MessageType.text || MessageType.system => last.text,
    MessageType.recipe => l10n.recipe,
    MessageType.image => l10n.photo,
    MessageType.video => l10n.video,
    MessageType.audio => l10n.voiceNote,
    MessageType.workoutPlan => l10n.workoutPlan,
    MessageType.mealPlan => l10n.mealPlan,
    MessageType.session => l10n.liveSession,
  };
  if (body.isEmpty) return l10n.noMessagesYet;
  final mine = myUid != null && last.senderUid == myUid;
  return mine && last.type != MessageType.system ? l10n.youText(body) : body;
}

/// "18:30", or a 12-hour clock in Arabic, in her phone's time.
String clockText(AppL10n l10n, DateTime? at) =>
    at == null ? '' : coachClockLabel(l10n, at);

/// "Sat 24 Oct".
String dateText(AppL10n l10n, DateTime? at) =>
    at == null ? '' : coachDayLabel(l10n, at);

/// The time on a chat row: the clock today, "Yesterday", else the date.
String rowTime(AppL10n l10n, DateTime? at, DateTime now) {
  if (at == null) return '';
  final a = at.toLocal();
  final n = now.toLocal();
  final days = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(a.year, a.month, a.day)).inDays;
  if (days <= 0) return clockText(l10n, at);
  if (days == 1) return l10n.yesterday;
  return dateText(l10n, at);
}

/// A reason on the "Needs attention" list, in words about the week, not about her.
String attentionReasonText(AppL10n l10n, String reason) => switch (reason) {
  'noCheckIn' => l10n.noCheckInYet,
  'missedSessions' => l10n.trainingSlippedThisWeek,
  'healthFlag' => l10n.healthAnswerToRead,
  'unread' => l10n.unreadMessage,
  _ => '',
};

