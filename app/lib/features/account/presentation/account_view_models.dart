/// What A01–A04 render, computed without a widget in sight.
///
/// `ARCHITECTURE.md` §1: "A view model may not restate a rule, and a widget may
/// never contain one." So this file *arranges* what the domain decided and
/// decides nothing itself — every switch value comes from [PrivacySettings],
/// every rule-7 claim from [VerificationClaim], every report state from
/// [ReportProjection].
///
/// # The recurring theme: a figure we cannot state is absent, not invented
///
/// Several rows on these screens carry a number in the prototype — "2 blocked",
/// "1 · resolved in 40 minutes", "Regular · level 7" — and **the dictionary has
/// no parameterised form for any of them**. `PHASE1-FIXES.md` §13 records four
/// screens that shipped the mockup's samples as a woman's personal facts, and
/// §3's conclusion is the rule followed here: "A sentence that says less is
/// better than one that says something untrue."
///
/// So these view models expose the real counts as **data**, and the widgets
/// render a subtitle only where an authored string can carry it. The counts are
/// computed and tested regardless, so the moment the strings land the screens
/// fill in with no further work.
library;

import 'package:meta/meta.dart';

import '../domain/dietary_profile.dart';
import '../domain/notifications.dart';
import '../domain/privacy_settings.dart';
import '../domain/safety.dart';
import '../domain/verification_claim.dart';

// ---------------------------------------------------------------------- A03 --

/// One switch row on A03.
@immutable
class PrivacyRowView {
  const PrivacyRowView({
    required this.key,
    required this.value,
    required this.queuedLocally,
  });

  final PrivacyKey key;
  final bool value;

  /// True when the last change to this row is saved on this phone and has not
  /// reached the server. The row shows a quiet "saved on your phone" chip —
  /// **never a spinner**, and never a claim that it applies everywhere yet.
  final bool queuedLocally;
}

/// A03 — Privacy.
@immutable
class PrivacyScreenView {
  const PrivacyScreenView({required this.rows, required this.imagesStatement});

  factory PrivacyScreenView.from({
    required PrivacySettings settings,
    required VerificationRecord verification,
    Set<PrivacyKey> queuedKeys = const <PrivacyKey>{},
  }) {
    return PrivacyScreenView(
      rows: [
        for (final key in PrivacyKey.values)
          PrivacyRowView(
            key: key,
            value: settings.valueOf(key),
            queuedLocally: queuedKeys.contains(key),
          ),
      ],
      imagesStatement: VerificationClaim.imagesDeletedStatement(verification),
    );
  }

  /// All four switches, in the order A03 draws them.
  final List<PrivacyRowView> rows;

  /// Rule 7. [ImagesDeletionPending] means A03 renders **no** deletion claim.
  final ImagesDeletedStatement imagesStatement;

  PrivacyRowView rowFor(PrivacyKey key) => rows.firstWhere((r) => r.key == key);

  /// True only when the product is entitled to state that the images are gone.
  bool get mayStateImagesDeleted => imagesStatement.mayClaimDeletion;
}

// ---------------------------------------------------------------------- A04 --

/// A04 — Safety Centre.
///
/// Named `...Model` rather than `...View` because the widget on A04 is called
/// `SafetyCentreView`, and two classes of the same name in one feature is how a
/// screen ends up importing its own view model by accident.
@immutable
class SafetyCentreModel {
  const SafetyCentreModel({
    required this.blockedCount,
    required this.reports,
    required this.hasUnsentReport,
  });

  factory SafetyCentreModel.from({
    required List<Block> blocks,
    required List<Report> reports,
  }) {
    final views = reports.map(ReportProjection.forReporter).toList();
    return SafetyCentreModel(
      blockedCount: blocks.length,
      reports: views,
      hasUnsentReport: views.any((r) => !r.hourStarted),
    );
  }

  /// Computed, never the prototype's "2".
  final int blockedCount;

  final List<ReporterView> reports;

  /// True while any report is still sitting on this phone.
  ///
  /// A04 must say so plainly. G7 §4 calls a queued report rendered as "a
  /// moderator is reading it" "the single most misleading thing this group
  /// could ship", and the one-hour clock has not started on it.
  final bool hasUnsentReport;

  int get reportCount => reports.length;

  /// Reports that actually reached a moderator.
  int get sentReportCount => reports.where((r) => r.hourStarted).length;
}

// ---------------------------------------------------------------------- A01 --

/// One inbox row that the product can actually render.
@immutable
class NotificationRowView {
  const NotificationRowView({required this.notification});

  final AppNotification notification;

  NotificationKind get kind => notification.kind;
  bool get read => notification.read;
}

/// A01 — Notifications.
///
/// # Why [unrenderableCount] exists
///
/// Every one of the four rows the prototype draws is a **sample**: "Sara replied
/// to your review" names a coach she may not have, "Beginners group reached 146
/// sessions" is a fixed number, "Habiba and 12 others liked your best" is a
/// fixed name and count. G7 Q11 — which MVP events A01 ships with — is
/// unresolved, and no notification kind has a general, authored title in the
/// dictionary.
///
/// Rendering the samples anyway is precisely the defect `PHASE1-FIXES.md` §3 and
/// §13 record five times over. So a row whose kind has no authored copy is
/// **counted and not drawn**, and A01 falls back to its empty state — which
/// rule 17 makes the onboarding anyway. The count makes the gap measurable
/// rather than invisible, and it expires by itself the day the strings land.
@immutable
class NotificationsInboxView {
  const NotificationsInboxView({
    required this.rows,
    required this.unrenderableCount,
    required this.permission,
  });

  factory NotificationsInboxView.from({
    required List<AppNotification> notifications,
    required NotificationPermission permission,
    required bool Function(NotificationKind) hasAuthoredCopy,
  }) {
    final renderable = <NotificationRowView>[];
    var skipped = 0;

    for (final notification in notifications) {
      if (hasAuthoredCopy(notification.kind)) {
        renderable.add(NotificationRowView(notification: notification));
      } else {
        skipped++;
      }
    }

    return NotificationsInboxView(
      rows: renderable,
      unrenderableCount: skipped,
      permission: permission,
    );
  }

  final List<NotificationRowView> rows;

  /// Notifications held back because their kind has no authored copy yet.
  final int unrenderableCount;

  final NotificationPermission permission;

  /// Rule 17 — the empty state is the onboarding. A branch inside A01, never a
  /// route.
  bool get isEmpty => rows.isEmpty;

  /// True when A01 should offer to turn the daily nudge on.
  bool get showsPermissionPrompt => permission.canPrompt;

  /// True when the only honest row is a deep link to OS settings.
  bool get showsSettingsDeepLink =>
      permission.state == NotifPermission.deniedTerminal ||
      permission.state == NotifPermission.revokedInSettings;
}

// ---------------------------------------------------------------------- A02 --

/// A02 — Profile and settings.
@immutable
class ProfileScreenView {
  const ProfileScreenView({
    required this.firstName,
    required this.verified,
    required this.dietary,
    required this.notifyIsDefault,
  });

  factory ProfileScreenView.from({
    required VerificationRecord verification,
    required DietaryProfile dietary,
    required NotifySettings notify,
    String? firstName,
  }) {
    return ProfileScreenView(
      firstName: firstName,
      verified: verification.isDecided,
      dietary: dietary,
      // A02's "One a day, quiet 10pm-8am" is a fixed sentence describing the
      // shipped defaults. It is true only while they ARE the defaults, so it is
      // rendered only then — the same discipline C13's nullable duration uses.
      notifyIsDefault: notify == NotifySettings.initial,
    );
  }

  /// Typed by her at C13, never lifted off the ID. A name is a value, not copy.
  final String? firstName;

  final bool verified;

  /// D3's allergy row. [DietaryProfile.asked] is what decides between inviting
  /// her to answer and showing her answer back.
  final DietaryProfile dietary;

  final bool notifyIsDefault;

  /// How many allergens she has named. Zero is a real answer once [asked].
  int get allergenCount => dietary.allergies?.length ?? 0;

  /// True when the product has never put the allergy question to her — the
  /// state every woman is in today, and the one that makes `AllergyGuard` fail
  /// closed for all of them.
  bool get allergiesUnasked => !dietary.asked;
}
