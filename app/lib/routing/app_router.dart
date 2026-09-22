import 'dart:async';

import 'package:flutter/material.dart';
// `Clipboard` — Z11 hands the export over on it, because nothing in this build
// can write a file.
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../app_state/app_changes.dart';
import '../app_state/coach_portfolio_state.dart';
import '../app_state/coach_profile_state.dart';
import '../app_state/coached_life_state.dart';
import '../app_state/coaching_desk_state.dart';
import '../app_state/coaching_link_state.dart';
import '../app_state/community_state.dart';
import '../app_state/cycle_state.dart';
import '../app_state/eat_state.dart';
import '../app_state/honest_notice.dart';
import '../app_state/workout_session_state.dart';
import '../domain/training/prescribed_set.dart';
import '../domain/rewards/level_curve.dart';
import '../features/testing/presentation/all_screens_view.dart';

import '../domain/flags/feature_flags.dart';
import '../domain/format/number_label.dart' show countLabel;
import '../ui/app_undo_snackbar.dart';
import '../ui/screen_scope.dart';
import '../domain/identity/user_roles.dart';
import '../domain/rewards/personal_best_ledger.dart';
import '../domain/week/week_key.dart';
import '../features/eat/domain/allergy_guard.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/eat/presentation/eat_sample_library.dart';
import '../features/eat/presentation/eat_view.dart';
import '../features/eat/presentation/grocery_list_view.dart';
import '../features/eat/presentation/recipe_view.dart';
import '../features/eat/presentation/recipes_view.dart';
import '../features/eat/presentation/say_it_view.dart';
import '../features/eat/presentation/type_it_view.dart';
import '../features/eat/presentation/week_plan_view.dart';
import '../features/onboarding/domain/intake_repository.dart';
import '../features/onboarding/presentation/goal_view.dart';
import '../features/onboarding/presentation/life_stage_view.dart';
import '../features/onboarding/presentation/place_view.dart';
import '../features/onboarding/presentation/schedule_view.dart';
import '../features/onboarding/presentation/starting_program_view.dart';
import '../features/signup/domain/auth_repository.dart';
import '../features/signup/domain/id_capture.dart';
import '../features/signup/domain/locale_preference.dart';
import '../features/signup/domain/verification.dart';
import '../features/signup/domain/verification_fake.dart';
import '../features/signup/presentation/being_checked_view.dart';
import '../features/signup/presentation/checking_view.dart';
import '../features/signup/presentation/code_view.dart';
import '../features/signup/presentation/id_capture_view.dart';
import '../features/signup/presentation/language_view.dart';
import '../features/signup/presentation/look_around_view.dart';
import '../features/signup/presentation/phone_number_view.dart';
import '../features/signup/presentation/pledge_view.dart';
import '../features/signup/presentation/role_view.dart';
import '../features/signup/presentation/selfie_capture_view.dart';
import '../features/signup/presentation/welcome_view.dart';
import '../features/signup/presentation/whats_inside_view.dart';
import '../features/signup/presentation/why_we_check_view.dart';
import '../features/signup/presentation/woman_reviewer_view.dart';
import '../features/signup/presentation/youre_in_view.dart';
import '../features/today/domain/today_repository.dart';
import '../features/today/presentation/already_did_it_view.dart';
import '../features/today/presentation/first_week_view.dart';
import '../features/today/presentation/lock_screen_nudge_view.dart';
import '../features/today/presentation/quiet_week_view.dart';
import '../features/today/presentation/tier_slip_view.dart';
import '../domain/logging/log_command_bus.dart';
import '../features/today/presentation/today_view.dart';
import '../features/train/domain/session_bests_bridge.dart';
import '../features/train/domain/train_repository.dart';
import '../features/train/presentation/change_set_view.dart';
import '../features/train/presentation/exercise_video_view.dart';
import '../features/train/presentation/finished_view.dart';
import '../features/train/presentation/follow_along_view.dart';
import '../features/train/presentation/logged_from_memory_view.dart';
import '../features/train/presentation/mid_set_view.dart';
import '../features/train/presentation/move_logged_view.dart';
import '../features/train/presentation/program_view.dart';
import '../features/train/presentation/resting_view.dart';
import '../features/train/presentation/swap_move_view.dart';
import '../features/train/presentation/train_view.dart';
import '../features/train/presentation/workout_day_view.dart';
import '../features/train/presentation/workout_library_view.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/account/domain/notifications.dart';
import '../features/account/domain/privacy_settings.dart';
import '../features/account/domain/safety.dart';
import '../features/account/presentation/notifications_view.dart';
import '../features/account/presentation/privacy_view.dart';
import '../features/account/presentation/profile_view.dart';
import '../features/account/presentation/safety_centre_view.dart';
import '../features/admin/domain/csv_parser.dart';
import '../features/admin/domain/content_schema.dart';
import '../features/admin/domain/export_manifest.dart' show buildExportBundle;
import '../features/admin/domain/import_validator.dart';
import '../features/admin/domain/content_repository.dart';
import '../features/admin/domain/media_bundle.dart';
import '../features/admin/domain/media_picker.dart';
import '../features/admin/domain/seed_library.dart';
import '../features/admin/domain/text_source.dart';
import '../features/admin/presentation/bulk_import_view.dart';
import '../features/admin/presentation/collection_view.dart';
import '../features/admin/presentation/content_form_view.dart';
import '../features/admin/presentation/content_library_view.dart';
import '../features/admin/presentation/export_view.dart';
import '../features/admin/presentation/import_check_view.dart';
import '../features/admin/presentation/media_library_view.dart';
import '../features/coach/domain/coach_desk.dart';
import '../features/coach/domain/coach_repository.dart';
import '../features/coach/domain/enquiry.dart';
import '../features/coach/presentation/coach_basics_view.dart';
import '../features/coach/presentation/coach_being_checked_view.dart';
import '../features/coach/presentation/coach_certificates_view.dart';
import '../features/coach/presentation/coach_chat_view.dart';
import '../features/coach/presentation/coach_earnings_view.dart';
import '../features/coach/presentation/coach_enquiry_view.dart';
import '../features/coach/presentation/coach_first_week_view.dart';
import '../features/coach/presentation/coach_packages_view.dart';
import '../features/coach/presentation/coach_payout_view.dart';
import '../features/coach/presentation/coach_specialties_view.dart';
import '../features/coach/presentation/coach_today_view.dart';
import '../features/coach/presentation/coach_view_models.dart';
import '../features/coachbrand/presentation/portfolio_home_view.dart';
import '../features/coached/presentation/assigned_workout_view.dart';
import '../features/coached/presentation/coach_replied_view.dart';
import '../features/coached/presentation/coached_chat_view.dart';
import '../features/coached/presentation/coaching_ended_view.dart';
import '../features/coached/presentation/coaching_food_view.dart';
import '../features/coached/presentation/coaching_intake_view.dart';
import '../features/coached/presentation/coaching_plan_view.dart';
import '../features/coached/presentation/coaching_support_view.dart';
import '../features/coached/presentation/log_planned_meal_view.dart';
import '../features/coached/presentation/meal_logged_view.dart';
import '../features/coached/presentation/preparing_view.dart';
import '../features/coached/presentation/rest_between_sets_view.dart';
import '../features/coached/presentation/session_done_view.dart';
import '../features/coached/presentation/swap_exercise_view.dart';
import '../features/coached/presentation/thirty_days_view.dart';
import '../features/coached/presentation/voice_note_view.dart';
import '../features/coached/presentation/weekly_review_view.dart';
import '../features/community/domain/community_models.dart';
import '../features/community/domain/community_repository.dart';
import '../features/community/domain/follow_up_policy.dart';
import '../features/community/presentation/activity_view.dart';
import '../features/community/presentation/compose_post_view.dart';
import '../features/community/presentation/create_view.dart';
import '../features/community/presentation/create_view_model.dart';
import '../features/community/presentation/explore_view.dart';
import '../features/community/presentation/feed_view.dart';
import '../features/community/presentation/feed_view_model.dart';
import '../features/community/presentation/follow_up_composer_view.dart';
import '../features/community/presentation/follow_up_thread_view.dart';
import '../features/community/presentation/group_goal_view.dart';
import '../features/community/presentation/group_view.dart';
import '../features/community/presentation/groups_view.dart';
import '../features/community/presentation/groups_view_model.dart';
import '../features/community/presentation/post_view.dart';
// Prefixed: `ProfileView` is also the name of A02's widget, and both are
// imported here. The prefix names which profile a builder means — a member's
// public profile (M07) or her own account (A02).
import '../features/community/presentation/profile_view.dart' as member;
import '../features/community/presentation/profile_view_model.dart';
import '../features/community/presentation/safety_sheet_view.dart';
import '../features/community/presentation/saved_view.dart';
import '../features/cycle/domain/cycle_repository.dart';
import '../features/cycle/domain/period_entry.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../features/cycle/presentation/check_in_view.dart';
import '../features/cycle/presentation/cycle_calendar_view.dart';
import '../features/cycle/presentation/cycle_dates_view.dart';
import '../features/cycle/presentation/cycle_hub_view.dart';
import '../features/cycle/presentation/cycle_meals_view.dart';
import '../features/cycle/presentation/cycle_patterns_view.dart';
import '../features/cycle/presentation/cycle_phases_view.dart';
import '../features/cycle/presentation/cycle_settings_view.dart';
import '../features/cycle/presentation/cycle_setup_view.dart';
import '../features/cycle/presentation/cycle_widgets.dart';
import '../features/cycle/presentation/gentler_option_view.dart';
import '../features/cycle/presentation/log_period_view.dart';
import '../features/cycle/presentation/why_suggestion_view.dart';
import '../features/progress/domain/milestone.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/progress/presentation/body_privately_view.dart';
import '../features/progress/presentation/milestones_view.dart';
import '../features/progress/presentation/personal_bests_view.dart';
import '../features/progress/presentation/progress_view.dart';
import '../features/progress/presentation/progress_view_model.dart';
import '../features/admin/presentation/feature_flags_view.dart';
import '../features/assistant/domain/assistant_provider.dart';
import '../features/assistant/presentation/ask_view.dart';
import '../features/assistant/presentation/ask_view_model.dart';
import '../features/assistant/presentation/assistant_boundaries.dart';
import '../features/assistant/presentation/boundaries_view.dart';
import '../features/assistant/presentation/draft_view_model.dart';
import '../features/assistant/presentation/meal_draft_view.dart';
import '../features/assistant/presentation/plan_draft_view.dart';
import '../features/coach/presentation/coach_public_profile_view.dart';
import '../features/coachbrand/domain/portfolio_block.dart';
import '../features/coachbrand/domain/portfolio_publisher.dart';
import '../features/coachbrand/presentation/ad_designer_view.dart';
import '../features/coachbrand/presentation/add_section_view.dart';
import '../features/coachbrand/presentation/canvas_view.dart';
import '../features/coachbrand/presentation/cover_editor_view.dart';
import '../features/coachbrand/presentation/insights_view.dart';
import '../features/coachbrand/presentation/look_view.dart';
import '../features/coachbrand/presentation/media_view.dart';
import '../features/coachbrand/presentation/method_editor_view.dart';
import '../features/coachbrand/presentation/offers_block_view.dart';
import '../features/coachbrand/presentation/preview_view.dart';
import '../features/coachbrand/presentation/publish_view.dart';
import '../features/coachbrand/presentation/results_view.dart';
import '../features/coaching/domain/coaching_repository.dart';
import '../features/coaching/domain/marketplace_stage.dart';
import '../features/coaching/presentation/coach_profile_view.dart';
import '../features/coaching/presentation/coaching_view_models.dart';
import '../features/coaching/presentation/enquiry_view.dart';
import '../features/coaching/presentation/find_a_coach_view.dart';
import '../features/coaching/presentation/my_coach_view.dart';
import '../features/coaching/presentation/packages_view.dart';
import '../features/coachplan/domain/assessment/assessment_form.dart';
import '../features/coachplan/domain/clients/coach_client.dart';
import '../features/coachplan/domain/plan/plan_draft.dart';
import '../features/coachplan/domain/review/review_feedback_service.dart';
// Prefixed: `Split` is also the name of a Flutter animation curve, and
// `package:flutter/material.dart` is imported above. The prefix names which
// split a builder means — a coach's week shape, never a curve.
import '../features/coachplan/domain/split/split.dart' as coachplan;
import '../features/coachplan/presentation/assessment_health_view.dart';
import '../features/coachplan/presentation/client_overview_view.dart';
import '../features/coachplan/presentation/clients_view.dart';
import '../features/coachplan/presentation/coach_inbox_view.dart';
import '../features/coachplan/presentation/copy_week_view.dart';
import '../features/coachplan/presentation/create_meal_view.dart';
import '../features/coachplan/presentation/meal_planner_view.dart';
import '../features/coachplan/presentation/coachplan_labels.dart'
    show mealSlotLabel;
import '../features/coachplan/presentation/movement_screening_view.dart';
import '../features/coachplan/presentation/no_client_view.dart';
// Prefixed: `PublishView` is also the name of B11's widget, and both are
// imported here. The prefix names which publish a builder means — a coach's
// month (W08) or her public page (B11).
import '../features/coachplan/presentation/publish_view.dart' as plan;
import '../features/coachplan/presentation/reassessment_view.dart';
import '../features/coachplan/presentation/review_view.dart';
import '../features/coachplan/presentation/session_editor_view.dart';
import '../features/coachplan/presentation/split_builder_view.dart';
import '../features/coachplan/presentation/splits_view.dart';
import '../features/coachplan/presentation/workout_planner_view.dart';
import '../features/community/presentation/record_view.dart';
import '../features/community/presentation/reels_view.dart';
import '../features/community/presentation/story_viewer_view.dart';
import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';
import 'app_routes.dart';

/// Screens that are **states, not destinations**.
///
/// `HANDOFF.md` rule 16: each of these is the day-one rendering of a tab whose
/// underlying collection is empty — Home, Eat, Community, the coach's Today, her
/// Clients, and her portfolio. In Flutter they are branches inside those same
/// routes, chosen when the collection is empty.
///
/// The generated route table in `app_routes.dart` still lists all six, because it
/// is generated from the screen inventory and the inventory is a catalogue of
/// screens rather than of destinations. Excluding them here is what keeps rule 16
/// true: if one became routable, something could navigate to "Home, empty" while
/// Home is not empty.
const Set<String> firstRunStates = {
  'T06', // Home, day one
  'E09', // Eat, day one
  'M17', // Community, day one
  'K24', // Coach Today, day one
  'W11', // Coach Clients, day one
  'B14', // Portfolio, before she has built anything
  // G9's two, added when the Cycle flow was built. Both are branches of Y03
  // rendered by the same widget, exactly as T06 is a branch of T01:
  'Y11', // My cycle, severe symptoms — a state of the hub, not a screen
  'Y14', // My cycle, symptoms-only — the same hub without the calendar
};

/// Every screen this application routes to.
///
/// `DECISIONS.md` D1 withdrew the MVP cut, so the scope is the whole product —
/// both roles, all 16 flows — minus the six first-run states above. Derived from
/// the generated inventory rather than retyped, so it cannot drift from it.
Map<String, AppRoute> get appDestinations => {
  for (final e in appRoutes.entries)
    if (!firstRunStates.contains(e.key)) e.key: e.value,
};

/// Screen ID for a route name, or null if no screen serves it.
String? screenIdForRoute(String routeName) {
  for (final e in appDestinations.entries) {
    if (e.value.name == routeName) return e.key;
  }
  return null;
}

class AppRouter {
  /// Resolves a route name to a page. Returns null for anything that is not a
  /// destination, so a first-run state fails loudly at the navigator rather than
  /// quietly rendering an empty-state screen over real data.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;
    final id = screenIdForRoute(name);
    if (id == null) return null;
    final route = appDestinations[id]!;

    // D25. A screen whose feature is switched off is not reachable, even when
    // it is fully built and its route resolves. Without this check
    // `featureFlags` is a claim with no mechanism: every Phase 3 screen would
    // be one deep link away from a woman the moment it compiled.
    final feature = featureForFlow(route.flow);
    if (feature != null && !featureFlags.isOn(feature)) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => FeatureOff(screenId: id, title: route.title),
      );
    }

    final built = _built[id];
    return MaterialPageRoute<dynamic>(
      settings: settings,
      // ScreenScope tells the screen its own id, which is how AppScaffold finds
      // this screen's illustrations in ScreenArt. Only the router does this, so
      // widget tests that build a screen directly draw no illustration.
      builder: built == null
          ? (_) => NotBuiltYet(screenId: id, title: route.title)
          // Redrawn whenever shared state changes, so a screen underneath
          // another is current again the moment she comes back to it.
          : (_) => ListenableBuilder(
              listenable: AppChanges.instance,
              builder: (context, _) =>
                  ScreenScope(screenId: id, child: built(context)),
            ),
    );
  }

  /// The switch that governs a flow, or null when the flow is never gated.
  ///
  /// Two flows are deliberately ungated and must stay that way:
  ///
  ///   * **`account`** — the privacy centre, her export and account deletion
  ///     live here. A flag flip must never be able to trap a woman inside an
  ///     app she cannot leave, and PDPL erasure is not a feature to toggle.
  ///   * **`onboarding`** — the setup questions sit between signing up and
  ///     having an account. Gating them could strand a half-registered woman
  ///     with no way forward and no way back.
  ///
  /// `feature_gating_test` asserts every flow in [appRoutes] appears here, so a
  /// new flow cannot become ungated by being forgotten.
  static Feature? featureForFlow(String flow) => switch (flow) {
    'signup' => Feature.signUp,
    'today' => Feature.today,
    'train' => Feature.train,
    'eat' => Feature.eat,
    'progress' => Feature.progress,
    'cycle' => Feature.cycle,
    'admin' => Feature.adminConsole,
    'community' => Feature.community,
    'coach' => Feature.coachApp,
    // K01-K06, the coach's own setup. Same switch as her app: a coach
    // who can fill in her certificates but cannot open her desk is a
    // half-open door.
    'coach-setup' => Feature.coachApp,
    'coachplan' => Feature.coachPlanning,
    'coachbrand' => Feature.coachPortfolio,
    'coached' => Feature.coachedLife,
    'coaching' => Feature.marketplace,
    'assistant' => Feature.assistant,
    'account' || 'onboarding' => null,
    _ => null,
  };

  /// Flows this file has made an explicit decision about.
  static const Set<String> decidedFlows = {
    'signup',
    'today',
    'train',
    'eat',
    'progress',
    'cycle',
    'admin',
    'community',
    'coach',
    'coach-setup',
    'coachplan',
    'coachbrand',
    'coached',
    'coaching',
    'assistant',
    'account',
    'onboarding',
  };

  /// Screens that actually exist. Everything absent renders [NotBuiltYet], so
  /// the gap between what is designed and what is built is visible rather than
  /// guessed at — and this map is the honest measure of progress.
  static final Map<String, WidgetBuilder> _built = {
    'C01': (context) => WelcomeView(
      onGetStarted: () => goTo(context, 'C02'),
      onSignIn: () => goTo(context, 'C06'),
    ),
    'C02': (context) => LanguageView(
      preference: localePreference,
      onContinue: () => goTo(context, 'C03'),
    ),
    'C03': (context) => WhatsInsideView(
      onCreateAccount: () => goTo(context, 'C06'),
      onLookAround: () => goTo(context, 'C04'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'C04': (context) => LookAroundView(onJoin: () => goTo(context, 'C06')),
    // C05 is C04 with the join prompt raised, not a separate page. The route
    // exists so the design can be reviewed screen by screen.
    'C05': (context) => LookAroundView(
      openJoinPrompt: true,
      onJoin: () => goTo(context, 'C06'),
    ),
    'C06': (context) => PhoneNumberView(
      repository: authRepository,
      onCodeSent: () => goTo(context, 'C07'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'C07': (context) => CodeView(
      repository: authRepository,
      // Only while no account is required, like every other test affordance.
      // Against a real provider there is no such code and none is claimed.
      testCode: featureFlags.isOn(Feature.accountRequired)
          ? null
          : testCodeOf(authRepository),
      onConfirmed: () => goTo(context, 'C08'),
      // "Send it again" has to answer. In this build nothing is sent, so the
      // answer names the code instead of promising a message.
      onResent: () => showHonestNotice(context, switch (featureFlags.isOn(
            Feature.accountRequired,
          )
          ? null
          : testCodeOf(authRepository)) {
        final code? => AppL10n.of(context).testBuildNoTextMessageIsSent(code),
        null => AppL10n.of(context).aNewCodeIsOnItsWay,
      }),
      onResendRefused: () => showHonestNotice(
        context,
        AppL10n.of(context).tooManyTriesWaitAMinuteThen,
      ),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    // Her answer is carried, not discarded: a coach and a client are verified
    // the same way here, but the role decides where C13 sends her afterwards.
    'C08': (context) => RoleView(
      onContinue: (role) {
        lastSignupRole = role;
        // Writes into the app-level scope, so the navigation she sees after
        // sign-up is already hers (D11). In production `roles.held` is
        // server-written — this is the local echo of what the sign-up call
        // records, and picking "coach" still earns nothing until the coach
        // application and its certificate checks pass.
        RoleScope.maybeOf(context)?.value = role.toRoles();
        goTo(context, 'C09');
      },
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'C09': (context) => WhyWeCheckView(
      onScanId: () => goTo(context, 'C10'),
      // The niqab path. Nothing on this route may ask for a selfie.
      onNiqabPath: () => goTo(context, 'C15'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'C10': (context) => IdCaptureView(
      captureService: captureService,
      onCaptured: () => goTo(context, 'C11'),
      onClose: () => Navigator.of(context).maybePop(),
    ),
    'C11': (context) => SelfieCaptureView(
      captureService: captureService,
      onCaptured: () => goTo(context, 'C12'),
      onClose: () => Navigator.of(context).maybePop(),
    ),
    'C12': (context) => CheckingView(
      repository: verificationRepository,
      onVerified: (result) {
        // Kept so C13 can state a measured duration instead of inventing one.
        lastVerification = result;
        goTo(context, 'C13');
      },
      // Both "waiting for a reviewer" and "needs another look" land on the
      // same screen. Neither is a rejection (DECISIONS.md D8).
      onAwaitingReviewer: () => goTo(context, 'C14'),
      onContinue: () => goTo(context, 'C13'),
    ),
    'C13': (context) => YoureInView(
      // Her measured time, or nothing at all. Null is the honest answer when
      // the check was never timed — this screen used to state the prototype's
      // 74 seconds as a fact about her own verification.
      verifiedInSeconds: lastVerification?.took?.inSeconds,
      onReadTheRules: () => goTo(context, 'C16'),
      onCoachSetup: () => goTo(context, 'K01'),
    ),
    'C14': (context) => BeingCheckedView(
      onOpenWorkouts: () => goTo(context, 'R01'),
      onOpenRecipes: () => goTo(context, 'E05'),
      onOpenCoaches: () => goTo(context, 'H01'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Which path she chose matters operationally — a video check and a partner
    // gym cost very different things — so it is recorded rather than dropped.
    // G1 flagged that the two share one VerificationMethod today (F8).
    'C15': (context) => WomanReviewerView(
      repository: verificationRepository,
      onBooked: (path) {
        lastReviewerPath = path;
        goTo(context, 'C14');
      },
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'C16': (context) => PledgeView(
      onAgree: () => goTo(context, 'O01'),
      onBack: () => Navigator.of(context).maybePop(),
    ),

    // Setup. Every step writes to the SAME repository instance, or her answers
    // would not survive the walk from O01 to O05.
    'O01': (context) => GoalView(
      repository: intakeRepository,
      onContinue: () => goTo(context, 'O02'),
      onSkip: () => goTo(context, 'O02'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'O02': (context) => PlaceView(
      repository: intakeRepository,
      onContinue: () => goTo(context, 'O03'),
      onSkip: () => goTo(context, 'O03'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'O03': (context) => ScheduleView(
      repository: intakeRepository,
      onContinue: () => goTo(context, 'O04'),
      onSkip: () => goTo(context, 'O04'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'O04': (context) => LifeStageView(
      repository: intakeRepository,
      onContinue: () => goTo(context, 'O05'),
      onSkip: () => goTo(context, 'O05'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'O05': (context) => StartingProgramView(
      repository: intakeRepository,
      onStartNow: () => goTo(context, 'R03'),
      onStartTomorrow: () => goTo(context, 'T01'),
      // Goes to the workout library, not a picker — no picker exists among
      // the 161 screens. Recorded as F4 in PHASE1-FINDINGS.md.
      onPickDifferentProgram: () => goTo(context, 'R11'),
    ),

    // Today. T06 and T08 are states inside T01 and T07, never routes.
    'T01': (context) => TodayView(
      repository: todayRepository,
      // The same figure P01 shows, from the same derivation, so Home and
      // Progress cannot disagree about her level.
      level: progressSummary.level,
      onStartSession: () => goTo(context, 'R03'),
      onRecall: () => goTo(context, 'T02'),
      onOpenMeal: () => goTo(context, 'E01'),
      // Her usual plate logs straight from Home and lands on the logged day.
      // `onOpenPlate` is the way in when the card has no plate to log; the
      // plates themselves go through `onLogPlate`, which writes the one she
      // pressed and carries its five seconds to E04. Home's plates used to be
      // a link and nothing more: E04 opened showing whatever she had logged
      // elsewhere, and the plate she tapped was never written.
      onOpenPlate: () => goTo(context, 'E04'),
      onLogPlate: (plate) {
        final handle = EatAppState.instance.logPlate(context, plate.foodId);
        if (handle == null) return;
        _goCarryingHandle(context, 'E04', handle);
      },
      onOpenWeek: () => goTo(context, 'P01'),
      onOpenCycle: () => goTo(context, 'Y03'),
      // D11: her profile picture is the way into her profile, and — for a woman
      // who chose both roles — the way she switches between the trainee and
      // coach apps. `AppAvatar` was built for that and then placed on no screen,
      // so `onOpenProfile` was passed by nobody and A02 sat three taps from Home.
      onOpenProfile: () => goTo(context, 'A02'),
      onAsk: () => goTo(context, 'X01'),
      onNotifications: () => goTo(context, 'A01'),
      // T06 — "Home, day one" — is a STATE of this same widget (rule 16), and
      // it is the only screen the design routes to T07 from. Leaving this
      // unwired was why T07 was built, routable, and reachable by nobody.
      onOpenFirstWeek: () => goTo(context, 'T07'),
      onTellUsWhatYouEat: () => goTo(context, 'E02'),
      onOpenBeginnersGroup: () => goTo(context, 'M01'),
      // The bottom bar on the app's landing tab. Without this, TodayView's
      // AppNavBar had nothing to call and tapping Train, Community or Eat from
      // Home did nothing at all — on the first screen she sees after sign-up.
      // app_nav_bar_test.dart could not catch it: it builds the bar directly
      // and supplies its own onSelect.
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'T02': (context) => AlreadyDidItView(
      repository: todayRepository,
      // A session she did without her phone counts the same everywhere a
      // trained one does. Today's own copy is credited by the repository
      // above; this credits the week document and her points, deduped by the
      // day so a second tap on the same day adds nothing.
      onLogged: () {
        WorkoutSessionState.creditSession(
          sessionId: 'recalled-${dayId(DateTime.now())}',
          source: SessionSource.recalled,
          today: todayRepository,
          progress: progressStore,
          creditToday: false,
        );
        goTo(context, 'R12');
      },
      onStartSession: () => goTo(context, 'R03'),
      onOpenMeal: () => goTo(context, 'E01'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'T03': (context) => LockScreenNudgeView(
      repository: todayRepository,
      onLogged: () => goTo(context, 'T01'),
      onSomethingElse: () => goTo(context, 'E02'),
    ),
    'T04': (context) => QuietWeekView(
      repository: todayRepository,
      onStartShortSession: () => goTo(context, 'R03'),
      onOpenMeal: () => goTo(context, 'E01'),
      onOpenWeek: () => goTo(context, 'P01'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'T05': (context) => TierSlipView(
      repository: todayRepository,
      onStartShortSession: () => goTo(context, 'R03'),
      onStartSession: () => goTo(context, 'R03'),
      onRecall: () => goTo(context, 'T02'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'T07': (context) => FirstWeekView(
      repository: todayRepository,
      onClose: () => Navigator.of(context).maybePop(),
      onStartSession: () => goTo(context, 'R03'),
      onOpenStep: (screenId) => goTo(context, screenId),
      onBackToToday: () => goTo(context, 'T01'),
      onSeeProgress: () => goTo(context, 'P01'),
    ),

    // Train.
    'R01': (context) => TrainView(
      // Her week, from the same copy Home draws, so the two cannot disagree.
      sessionsThisWeek: todayRepository.day.week.sessionsLogged,
      sessionsPrescribed: todayRepository.day.week.sessionsTarget,
      onSearch: () => goTo(context, 'R11'),
      // The design sends "Continue" to G06, the coached-client screen. In
      // phase 1 no woman has a coach, so that would be a dead end — she goes
      // to today's session instead. Revisit when coaching ships (G4 OQ-12).
      onContinue: () => goTo(context, 'R03'),
      onSeeProgram: () => goTo(context, 'R02'),
      onOpenToday: () => goTo(context, 'T01'),
      onGentlerOption: () => goTo(context, 'R05'),
      // The first "Short ones that still count" tile, as the design has it.
      onFollowAlong: () => goTo(context, 'R06'),
      onShortSession: () => goTo(context, 'R03'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'R02': (context) => ProgramView(
      onBack: () => Navigator.of(context).maybePop(),
      onChangeProgram: () => goTo(context, 'R11'),
      onStart: () => goTo(context, 'R03'),
      onOpenDay: (screenId) => goTo(context, 'R03'),
    ),
    'R03': (context) => WorkoutDayView(
      repository: trainRepository,
      onBack: () => Navigator.of(context).maybePop(),
      // Starts the session this screen is listing, so R07 opens on its first
      // move and its first set rather than on a fixed example.
      onStart: () {
        WorkoutSessionState.instance.start(
          sampleWorkoutDay(AppL10n.of(context)),
          trainRepository,
        );
        goTo(context, 'R07');
      },
      onAlreadyDidIt: () => goTo(context, 'T02'),
      onOpenMove: (_) => goTo(context, 'R04'),
    ),
    'R04': (context) => ExerciseVideoView(
      onClose: () => Navigator.of(context).maybePop(),
      onBackToWorkout: () => goTo(context, 'R03'),
      onSwap: () => goTo(context, 'R05'),
    ),
    'R05': (context) => SwapMoveView(
      repository: trainRepository,
      onBack: () => Navigator.of(context).maybePop(),
      // The swap replaces the move she is on, carrying its prescription with
      // it. It used to be assigned to a field nothing read, so she chose an
      // alternative and then trained the move she had just replaced.
      onSwapped: (alternative) {
        lastSwappedFor = alternative;
        WorkoutSessionState.instance.swapCurrent(alternative, trainRepository);
        goTo(context, 'R07');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'R06': (context) => FollowAlongView(
      onPause: () => Navigator.of(context).maybePop(),
      onSkip: () => goTo(context, 'R07'),
    ),
    // One tap logs the set and starts the rest timer.
    //
    // The LogHandle is carried forward, not discarded. It IS the five-second
    // undo: R09 and R13 render `handle.describe` in the snackbar and call
    // `handle.undo()`. Dropping it here would leave the next screen with a
    // canned message and no way to take the log back — rule 9 broken by the
    // wiring while every widget test stayed green, because each screen is
    // individually correct.
    'R07': (context) => MidSetView(
      repository: trainRepository,
      sessionId: WorkoutSessionState.instance.sessionId,
      // The move and the set she is actually on. Both were left out, so this
      // screen asked every woman for the second set of a goblet squat for as
      // long as she kept tapping.
      move: WorkoutSessionState.instance.currentMove,
      setIndex: WorkoutSessionState.instance.setIndex,
      onClose: () => Navigator.of(context).maybePop(),
      onChange: () => goTo(context, 'R08'),
      onSetLogged: (handle) {
        WorkoutSessionState.instance.setLogged();
        _goCarryingHandle(context, 'R09', handle);
      },
      onMoveLogged: (handle) {
        WorkoutSessionState.instance.moveLogged();
        _goCarryingHandle(context, 'R13', handle);
      },
    ),
    'R08': (context) => ChangeSetView(
      repository: trainRepository,
      sessionId: WorkoutSessionState.instance.sessionId,
      prescribed:
          WorkoutSessionState.instance.currentSet ??
          const PrescribedSet(
            exerciseId: 'goblet_squat',
            order: 2,
            weightKg: 12,
            reps: 10,
          ),
      moveName: WorkoutSessionState.instance.currentMove?.name,
      onClose: () => Navigator.of(context).maybePop(),
      // Carries the handle, exactly as R07 does. It used to assign the
      // change to a field nothing read, which silently discarded her
      // override and left R09 announcing the numbers she had corrected.
      onSaved: (handle) {
        WorkoutSessionState.instance.setLogged();
        _goCarryingHandle(context, 'R09', handle);
      },
    ),
    'R09': (context) => RestingView(
      handle: handleFrom(context),
      onClose: () => Navigator.of(context).maybePop(),
      // The next set, or the end of the session when there is no next set.
      onReady: () {
        if (WorkoutSessionState.instance.isComplete) {
          _finishWorkout();
          goTo(context, 'R10');
        } else {
          goTo(context, 'R07');
        }
      },
    ),
    'R10': (context) => FinishedView(
      // Her week, her points — the same numbers Home and Progress read.
      sessionsThisWeek: todayRepository.day.week.sessionsLogged,
      sessionsPrescribed: todayRepository.day.week.sessionsTarget,
      levelProgressPercent: _levelProgressPercent,
      onBackToToday: () => goTo(context, 'T01'),
      onShare: () => goTo(context, 'M03'),
    ),
    'R11': (context) => WorkoutLibraryView(
      onBack: () => Navigator.of(context).maybePop(),
      onOpenWorkout: (_) => goTo(context, 'R03'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Eat. E09 is a BRANCH of E01, not a destination: `firstRunStates` keeps it
    // out of `appDestinations` and `routing_test.dart` pins that, so "Eat,
    // empty" cannot be opened over an Eat screen that is not empty.
    //
    // E04 is a real destination and is the same widget as E01, constructed with
    // the LogHandle. The handle travels as a route argument — never a static
    // field, which is the bug `_goCarryingHandle` records.
    //
    // Every Eat screen logs into ONE session (`EatAppState.instance.session`),
    // not into a bus of its own. That is what makes E02 → E04 show the meal she
    // just typed: the write is held in the session for five seconds, so the
    // screen she lands on draws it and can still take it back. Each screen
    // holding its own bus is why E04 opened on the day-one branch and then grew
    // an undo bar that did nothing.
    'E01': (context) => EatView(
      constraints: eatConstraints,
      repository: mealRepository,
      session: EatAppState.instance.session,
      onOpenRecipes: () => goTo(context, 'E05'),
      onType: () => goTo(context, 'E02'),
      onSpeak: () => goTo(context, 'E03'),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'E02': (context) => TypeItView(
      constraints: eatConstraints,
      repository: mealRepository,
      session: EatAppState.instance.session,
      onClose: () => Navigator.of(context).maybePop(),
      onSpeak: () => goTo(context, 'E03'),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
    ),
    'E03': (context) => SayItView(
      constraints: eatConstraints,
      repository: mealRepository,
      session: EatAppState.instance.session,
      onClose: () => Navigator.of(context).maybePop(),
      // `refused` and `failed` route to the keyboard with an explanation,
      // never to a spinner (§3.3).
      onTypeInstead: () => goTo(context, 'E02'),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
    ),
    'E04': (context) => EatView(
      constraints: eatConstraints,
      repository: mealRepository,
      session: EatAppState.instance.session,
      justLogged: handleFrom(context),
      onOpenRecipes: () => goTo(context, 'E05'),
      onType: () => goTo(context, 'E02'),
      onSpeak: () => goTo(context, 'E03'),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'E05': (context) => RecipesView(
      onBack: () => Navigator.of(context).maybePop(),
      // The row she tapped, recorded inline at the tap — the same arrangement
      // the community ids use, because `goTo` pushes a route name and nothing
      // else. Without it E06 opened on koshari whichever recipe she chose.
      onOpenRecipe: (recipeId) {
        EatAppState.instance.openRecipeId = recipeId;
        goTo(context, 'E06');
      },
      onOpenWeekPlan: () => goTo(context, 'E07'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'E06': (context) => RecipeView(
      constraints: eatConstraints,
      repository: mealRepository,
      session: EatAppState.instance.session,
      foodId: EatAppState.instance.openFoodId,
      title: EatAppState.instance.recipeTitle(AppL10n.of(context)),
      saved: EatAppState.instance.isSaved(EatAppState.instance.openFoodId),
      onBack: () => Navigator.of(context).maybePop(),
      onBookmark: () => EatAppState.instance.toggleSaved(
        context,
        EatAppState.instance.openFoodId,
      ),
      // No recipe pack exists, so there are no steps to show — see
      // `recipe_view.dart`. Said out loud rather than left as a dead button.
      onShare: () => showHonestNotice(
        context,
        AppL10n.of(context).sharingIsNotConnectedInThisBuild,
      ),
      onSeeSteps: () => showHonestNotice(
        context,
        AppL10n.of(context).theStepsForThisDishHaveNot,
      ),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
    ),
    'E07': (context) => WeekPlanView(
      repository: mealRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenRecipe: (recipeId) {
        EatAppState.instance.openRecipeId = recipeId;
        goTo(context, 'E06');
      },
      onOpenGroceryList: () => goTo(context, 'E08'),
    ),
    'E08': (context) => GroceryListView(
      repository: mealRepository,
      onBack: () => Navigator.of(context).maybePop(),
      // There is no share plugin in `pubspec.yaml`, so nothing here can open an
      // OS share sheet. G5 §9 Q8 stands; this says what the build can do.
      onShare: () => showHonestNotice(
        context,
        AppL10n.of(context).sharingIsNotConnectedInThisBuild,
      ),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),

    'R12': (context) => LoggedFromMemoryView(
      sessionsThisWeek: todayRepository.day.week.sessionsLogged,
      sessionsPrescribed: todayRepository.day.week.sessionsTarget,
      levelProgressPercent: _levelProgressPercent,
      onBackToToday: () => goTo(context, 'T01'),
    ),
    // Logs a whole move and returns to the move list — the session does NOT end.
    'R13': (context) => MoveLoggedView(
      handle: handleFrom(context),
      moves: WorkoutSessionState.instance.moves,
      loggedCount: WorkoutSessionState.instance.loggedSetCount,
      onClose: () => Navigator.of(context).maybePop(),
      // The next move, or the end of the session when that was the last one.
      onNextMove: () {
        if (WorkoutSessionState.instance.isComplete) {
          _finishWorkout();
          goTo(context, 'R10');
        } else {
          goTo(context, 'R07');
        }
      },
      onFinishHere: () {
        _finishWorkout();
        goTo(context, 'R10');
      },
    ),

    // ---------------------------------------------------- Progress (G6)
    //
    // P01 carries the ONLY inbound edges T04 and T05 have anywhere in the
    // design. Until it was built, both were implemented, routable and
    // reachable by nobody — the same fault T07 had before T06 was wired.
    'P01': (context) => ProgressView(
      summary: progressSummary,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenMilestones: () => goTo(context, 'P02'),
      onOpenBests: () => goTo(context, 'P03'),
      onOpenBody: () => goTo(context, 'P04'),
      onOpenFirstWeek: () => goTo(context, 'T07'),
      onOpenRestWeek: () => goTo(context, 'T04'),
      onOpenTierSlip: () => goTo(context, 'T05'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'P02': (context) => MilestonesView(
      summary: MilestonesSummary.from(
        // The eight milestones that are actually authored, not the empty
        // catalogue. `authoredMilestones` is deliberately 8 and not 12: the
        // other four are inferred from the prototype rather than written, and
        // shipping an inferred milestone is the same defect as shipping an
        // inferred tier ladder. P02's "Twelve in all" heading checks itself
        // against this count, so it stays hidden until the four are authored.
        catalogue: authoredMilestones,
        // Her earn dates, so a tick can say when rather than only that.
        earnedAt: progressStore.rewards.milestones,
        // All zeros until real counters are wired, so the "next" rows read
        // "0 of 10". That is true of a woman who has logged nothing, which is
        // exactly who this store describes.
        counts: const MilestoneCounts(),
      ),
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'P03': (context) => PersonalBestsView(
      bests: progressStore.bests.values.toList(),
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'P04': (context) => BodyPrivatelyView(
      repository: measurementsRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),

    // ----------------------------------------------------- Account (G7)
    'A01': (context) => NotificationsView(
      onBack: () => Navigator.of(context).maybePop(),
      onOpenSettings: () => goTo(context, 'A03'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'A02': (context) => ProfileView(
      dietaryRepository: dietaryRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenCycle: () => goTo(context, 'Y03'),
      // D11's promised door into coaching, and it was built and never
      // connected. `traineeTabs` records that the fifth Coaching tab was
      // deleted because "D11 moves it into her profile instead", and warns
      // that dropping the tab and the capability together "would have quietly
      // dropped a launch feature nobody asked to lose". That is exactly what
      // had happened: ProfileView renders the row, `onOpenCoach` existed, and
      // this builder wired seven callbacks and silently omitted it -- so the
      // entire marketplace was reachable only down the sign-up chain, six to
      // eight taps deep.
      //
      // H01, the directory, because with no relationship store wired every
      // woman is `browsing`. When one exists this should read her stage and
      // send a coached woman to H05 instead; `MarketplaceStage` already draws
      // that distinction.
      onOpenCoach: () => goTo(context, 'H01'),
      onOpenLanguage: () => goTo(context, 'C02'),
      onOpenNotifications: () => goTo(context, 'A01'),
      onOpenPrivacy: () => goTo(context, 'A03'),
      onOpenSafetyCentre: () => goTo(context, 'A04'),
      // Every screen, one tap away — only while no account is required.
      onOpenAllScreens: featureFlags.isOn(Feature.accountRequired)
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AllScreensView()),
            ),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'A03': (context) => PrivacyView(
      service: privacyService,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenCycleSharing: () => goTo(context, 'Y12'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'A04': (context) => SafetyCentreView(
      blockService: blockService,
      reportService: reportService,
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),

    // ------------------------------------------- Admin console (D12, G16)
    //
    // **Z03 and Z05 now exist.** They were absent because every field label
    // they needed was missing from the dictionary, and a bilingual
    // name_en/name_ar pair cannot be labelled from a single `name` string
    // without lying about which language each field takes. Those labels were
    // minted, so the forms are built and routed, and D12's "add meals and
    // workouts from within the admin section" is served by adding one at a
    // time as well as in bulk.
    //
    // `onSave` emits the finished row and **nothing writes it**. There is no
    // persistence layer anywhere in this app yet — the import commit has the
    // same gap — and putting the content library's only writer behind a screen
    // would be inventing one in the worst possible place.
    //
    // The callbacks with nothing behind them — choosing a file, uploading
    // media, committing writes — are left unwired for the same reason. There
    // is no file picker dependency and no persistence layer, so wiring them to
    // something that looks like it works is the one outcome worse than a
    // control that visibly does not.
    'Z01': (context) => ContentLibraryView(
      status: adminLibraryStatus,
      onOpenCollection: (collection) {
        switch (collection) {
          case ContentCollection.exercises:
            goTo(context, 'Z02');
          case ContentCollection.foods:
            goTo(context, 'Z04');
          case ContentCollection.recipes:
            goTo(context, 'Z06');
          case ContentCollection.programmes:
            goTo(context, 'Z07');
        }
      },
      onImport: () => goTo(context, 'Z08'),
      // The switchboard. Z01 is where staff land, and Z14 is the only place a
      // feature can be switched on or off — without a door here it would be
      // built, routable and reachable by nobody.
      onOpenFlags: () => goTo(context, 'Z14'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Z02': (context) => CollectionView(
      collection: ContentCollection.exercises,
      rows: contentRepository.rowsNow(ContentCollection.exercises),
      onBack: () => Navigator.of(context).maybePop(),
      onImport: () => goTo(context, 'Z08'),
      // Literal and inline, deliberately — a helper would hide this edge from
      // nav_reachability_test's parser and strand Z03, which is the bug this
      // file already records being caught twice for Y08 and Y10.
      onAdd: () {
        adminEditingRow = const <String, String>{};
        goTo(context, 'Z03');
      },
      // Opening a row is what makes the form an EDIT rather than an add.
      // Literal and inline for the same reason `onAdd` is.
      onOpenRow: (id) {
        adminEditingRow = adminRowValues(ContentCollection.exercises, id);
        goTo(context, 'Z03');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Z03': (context) => ContentFormView(
      collection: ContentCollection.exercises,
      values: adminEditingRow,
      onSave: (row) {
        unawaited(
          contentRepository.saveValues(
            collection: ContentCollection.exercises,
            values: row,
          ),
        );
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),
    'Z04': (context) => CollectionView(
      collection: ContentCollection.foods,
      rows: contentRepository.rowsNow(ContentCollection.foods),
      onBack: () => Navigator.of(context).maybePop(),
      onImport: () => goTo(context, 'Z08'),
      onAdd: () {
        adminEditingRow = const <String, String>{};
        goTo(context, 'Z05');
      },
      // Opening a row is what makes the form an EDIT rather than an add.
      // Literal and inline for the same reason `onAdd` is.
      onOpenRow: (id) {
        adminEditingRow = adminRowValues(ContentCollection.foods, id);
        goTo(context, 'Z05');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Z05': (context) => ContentFormView(
      collection: ContentCollection.foods,
      values: adminEditingRow,
      onSave: (row) {
        unawaited(
          contentRepository.saveValues(
            collection: ContentCollection.foods,
            values: row,
          ),
        );
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),
    'Z06': (context) => CollectionView(
      collection: ContentCollection.recipes,
      rows: contentRepository.rowsNow(ContentCollection.recipes),
      onBack: () => Navigator.of(context).maybePop(),
      onImport: () => goTo(context, 'Z08'),
      onAdd: () {
        adminEditingRow = const <String, String>{};
        goTo(context, 'Z12');
      },
      // Opening a row is what makes the form an EDIT rather than an add.
      // Literal and inline for the same reason `onAdd` is.
      onOpenRow: (id) {
        adminEditingRow = adminRowValues(ContentCollection.recipes, id);
        goTo(context, 'Z12');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Z07': (context) => CollectionView(
      collection: ContentCollection.programmes,
      rows: contentRepository.rowsNow(ContentCollection.programmes),
      onBack: () => Navigator.of(context).maybePop(),
      onImport: () => goTo(context, 'Z08'),
      onAdd: () {
        adminEditingRow = const <String, String>{};
        goTo(context, 'Z13');
      },
      // Opening a row is what makes the form an EDIT rather than an add.
      // Literal and inline for the same reason `onAdd` is.
      onOpenRow: (id) {
        adminEditingRow = adminRowValues(ContentCollection.programmes, id);
        goTo(context, 'Z13');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Z08': (context) => BulkImportView(
      collection: adminImportCollection,
      source: csvSource,
      chosenFileName: adminChosenFileName,
      // The tab is the whole screen: the expected-columns table under it is
      // read off the chosen collection's schema, so without the bump the
      // console kept listing the columns of whichever collection it opened on.
      onCollectionChanged: (collection) {
        adminImportCollection = collection;
        AppChanges.bump();
      },
      onChooseFile: () async {
        final result = await csvSource.chooseText();
        if (result is TextPicked) {
          adminChosenFileName = result.file.name;
          adminImportPlan = validateImport(
            collection: adminImportCollection,
            table: parseCsv(result.file.text),
            uploadedMedia: adminMediaBundle.names,
            // The line that makes a re-import UPDATE rather than duplicate:
            // the validator decides create-vs-update by asking the library what
            // it already holds.
            existingIds: contentRepository.existingIdsNow(
              adminImportCollection,
            ),
          );
        }
      },
      onCheckFile: () => goTo(context, 'Z09'),
      onBack: () => Navigator.of(context).maybePop(),
    ),
    // A block body, so the plan Z09 renders and the plan it commits are the
    // same object. Reading `adminPlanOrEmpty` twice could validate twice and
    // commit something the screen never showed.
    'Z09': (context) {
      final plan = adminPlanOrEmpty;
      return ImportCheckView(
        plan: plan,
        // `writes` is empty unless `canCommit`, so one bad row writes nothing.
        onCommit: () => unawaited(contentRepository.saveAll(plan.writes)),
        onBack: () => Navigator.of(context).maybePop(),
      );
    },
    'Z10': (context) => MediaLibraryView(
      bundle: adminMediaBundle,
      picker: mediaPicker,
      onUpload: () async {
        final result = await mediaPicker.pickMedia();
        if (result is MediaPicked) adminMediaBundle = result.bundle;
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Export, as far as this build goes. There is nothing in `pubspec.yaml`
    // that writes a file, so the bundle is handed over on the clipboard and
    // the notice says so rather than letting a button claim a download that
    // never arrives. `buildExportBundle` runs the manifest first, so "content
    // only, never her" is enforced on this path too.
    'Z11': (context) => ExportView(
      onExport: (chosen) {
        final bundle = buildExportBundle(<ContentCollection, List<ImportRow>>{
          for (final collection in chosen)
            collection: contentRepository.rowsNow(collection),
        });
        // Not awaited, and the notice does not wait for it: a platform channel
        // is answered by the host, and a screen that held its answer back
        // until the host replied would be silent for as long as the host felt
        // like taking. The bundle is already built by the line above; the
        // clipboard is only where it is put down.
        unawaited(Clipboard.setData(ClipboardData(text: bundle.text)));
        showHonestNotice(
          context,
          AppL10n.of(context)
              .csvFilesCopiedToTheClipboardCount(countLabel(bundle.csvCount)),
        );
      },
      onBack: () => Navigator.of(context).maybePop(),
    ),

    // D18 — the same widget as Z03 and Z05, with a different collection.
    //
    // ContentFormView draws whichever columns the schema can label, so these
    // two carry no bespoke layout: a column added to recipes.csv tomorrow
    // appears here without anyone editing a screen.
    'Z12': (context) => ContentFormView(
      collection: ContentCollection.recipes,
      values: adminEditingRow,
      onSave: (row) {
        unawaited(
          contentRepository.saveValues(
            collection: ContentCollection.recipes,
            values: row,
          ),
        );
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),
    'Z13': (context) => ContentFormView(
      collection: ContentCollection.programmes,
      values: adminEditingRow,
      onSave: (row) {
        unawaited(
          contentRepository.saveValues(
            collection: ContentCollection.programmes,
            values: row,
          ),
        );
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),

    // ------------------------------------------------------- Cycle (G9)
    //
    // Y11 and Y14 are deliberately absent: both are branches of Y03 rendered
    // by the same widget, so they are first-run states rather than routes.
    // Setting up is what puts My cycle on Home: `afterSetUp` turns the card on
    // (the default Y02 pre-ticks) unless she has already switched it off.
    'Y01': (context) => CycleSetupView(
      repository: cycleRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onContinueWithDates: () {
        unawaited(CycleAppState.instance.afterSetUp());
        goTo(context, 'Y02');
      },
      onContinueSymptomsOnly: () {
        unawaited(CycleAppState.instance.afterSetUp());
        goTo(context, 'Y03');
      },
      // Skipping costs nothing, and lands her back on Home.
      onSkip: () => goTo(context, 'T01'),
    ),
    'Y02': (context) => CycleDatesView(
      repository: cycleRepository,
      periods: periodRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onSaved: () {
        // Her "Show the cycle card on Home" answer reaches Home here.
        CycleAppState.instance.preferencesSaved();
        goTo(context, 'Y03');
      },
      onOpenProfile: () => goTo(context, 'A02'),
    ),
    'Y03': (context) => CycleHubView(
      cycle: cycleRepository.current,
      // Without these the hub always saw `TodayCheckIn.absent`: no period-day
      // card, no gentler card, and the severe branch unreachable however she
      // logged. The widgets were right; nothing was handing them her day.
      checkIn: todayCheckIn,
      periods: periodsSoFar,
      gentlerDecided: CycleAppState.instance.decidedToday,
      onBack: () => Navigator.of(context).maybePop(),
      onSettings: () => goTo(context, 'Y12'),
      onCheckIn: () => goTo(context, 'Y04'),
      onViewOption: () => goTo(context, 'Y06'),
      // Her plan stands, and the card stops asking until she checks in again.
      onKeepMine: () => CycleAppState.instance.decideToday(),
      onOpenMeals: () => goTo(context, 'Y07'),
      onAddDates: () => goTo(context, 'Y02'),
      // Y11's two outward routes need maps and a browser, and this build has
      // neither. Each says so, rather than being a button that does nothing.
      onFindCare: () => showHonestNotice(
        context,
        AppL10n.of(context).mapsAreNotConnectedInThisBuild,
      ),
      onReadGuidance: () => showHonestNotice(
        context,
        AppL10n.of(context).openingWebLinksIsNotConnectedIn,
      ),
      // Nothing records a planned rest yet (D5a's `markPlannedRest` does not
      // exist), so the note promises only what is true: nothing changed.
      onRest: () => showHonestNotice(
        context,
        AppL10n.of(context).restingTodayNothingInYourPlanChanges,
      ),
      // The hub renders nothing but an invitation until she has set up, so the
      // one action it offers has to go somewhere.
      onSetUp: () => goTo(context, 'Y01'),
      onSelectTab: (screenId) => goTo(context, screenId),
      // One literal `goTo` per arm, deliberately.
      //
      // `nav_reachability_test` recovers the graph with a regex that expects
      // the screen id immediately after `context,`. Passing a `switch`
      // expression AS the argument compiles and works at runtime, but hides
      // 'Y08' and 'Y10' from that parser exactly as a helper function did —
      // four built cycle screens were reported stranded twice, for the same
      // reason, in two different disguises. Written out, the edges are visible
      // to the parser and to a reader at the same time.
      onSelectCycleTab: (tab) {
        switch (tab) {
          case CycleTab.today:
            goTo(context, 'Y03');
          case CycleTab.calendar:
            goTo(context, 'Y08');
          case CycleTab.patterns:
            goTo(context, 'Y10');
        }
      },
    ),
    // Y04 discarded what she logged. `onSaved` was passed by nobody, so tapping
    // "Save check-in" closed the sheet and told no one — which meant heavy
    // bleeding could be logged and the severe branch still never appeared.
    //
    // `saveCheckIn` also redraws: Y03 underneath was drawn before she logged,
    // and without the signal it kept showing the morning without her answer.
    'Y04': (context) => CheckInView(
      onSaved: (checkIn) {
        CycleAppState.instance.saveCheckIn(checkIn);
        Navigator.of(context).maybePop();
      },
      onCancel: () => Navigator.of(context).maybePop(),
    ),
    // Both read what she logged today — the resolver's own reason — instead
    // of an empty list, so "why" names her symptoms and not nobody's.
    'Y05': (context) => WhySuggestionView(
      reason: CycleAppState.instance.todaysReason,
      onClose: () => Navigator.of(context).maybePop(),
      onReadSource: () => showHonestNotice(
        context,
        AppL10n.of(context).openingWebLinksIsNotConnectedIn,
      ),
    ),
    'Y06': (context) => GentlerOptionView(
      reason: CycleAppState.instance.todaysReason,
      onUseOption: () => goTo(context, 'R03'),
      // Her planned session, unchanged — and the hub stops offering.
      onKeepWorkout: () {
        CycleAppState.instance.decideToday();
        goTo(context, 'R03');
      },
      onRest: () {
        CycleAppState.instance.decideToday();
        showHonestNotice(
          context,
          AppL10n.of(context).restingTodayNothingInYourPlanChanges,
        );
        Navigator.of(context).maybePop();
      },
      onWhy: () => goTo(context, 'Y05'),
      onClose: () => Navigator.of(context).maybePop(),
    ),
    'Y07': (context) => CycleMealsView(
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Y08': (context) => CycleCalendarView(
      cycle: cycleRepository.current,
      year: DateTime.now().year,
      month: DateTime.now().month,
      // The calendar drew no logged days and no check-in days at all, because
      // neither list was ever passed.
      periods: periodsSoFar,
      checkInDays: todayCheckIn == TodayCheckIn.absent
          ? const <String>{}
          : <String>{dayId(DateTime.now())},
      onBack: () => Navigator.of(context).maybePop(),
      onSettings: () => goTo(context, 'Y12'),
      onLogPeriod: () => goTo(context, 'Y09'),
      onAboutPhases: () => goTo(context, 'Y13'),
      onSelectTab: (screenId) => goTo(context, screenId),
      // One literal `goTo` per arm, deliberately.
      //
      // `nav_reachability_test` recovers the graph with a regex that expects
      // the screen id immediately after `context,`. Passing a `switch`
      // expression AS the argument compiles and works at runtime, but hides
      // 'Y08' and 'Y10' from that parser exactly as a helper function did —
      // four built cycle screens were reported stranded twice, for the same
      // reason, in two different disguises. Written out, the edges are visible
      // to the parser and to a reader at the same time.
      onSelectCycleTab: (tab) {
        switch (tab) {
          case CycleTab.today:
            goTo(context, 'Y03');
          case CycleTab.calendar:
            goTo(context, 'Y08');
          case CycleTab.patterns:
            goTo(context, 'Y10');
        }
      },
    ),
    'Y09': (context) => LogPeriodView(
      repository: periodRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onSaved: () => goTo(context, 'Y08'),
    ),
    'Y10': (context) => CyclePatternsView(
      // Y10 rendered its empty state permanently: no starts, no check-ins, so
      // the chart never drew and its caption never appeared in the app.
      recentStarts: cycleRepository.current?.recentStarts ?? const <String>[],
      checkIns: todayCheckIn == TodayCheckIn.absent
          ? const <String, TodayCheckIn>{}
          : <String, TodayCheckIn>{dayId(DateTime.now()): todayCheckIn},
      easierWhenLowEnergy:
          cycleRepository.current?.adaptation.easierWhenLowEnergy ?? false,
      onBack: () => Navigator.of(context).maybePop(),
      onSettings: () => goTo(context, 'Y12'),
      onSelectTab: (screenId) => goTo(context, screenId),
      // One literal `goTo` per arm, deliberately.
      //
      // `nav_reachability_test` recovers the graph with a regex that expects
      // the screen id immediately after `context,`. Passing a `switch`
      // expression AS the argument compiles and works at runtime, but hides
      // 'Y08' and 'Y10' from that parser exactly as a helper function did —
      // four built cycle screens were reported stranded twice, for the same
      // reason, in two different disguises. Written out, the edges are visible
      // to the parser and to a reader at the same time.
      onSelectCycleTab: (tab) {
        switch (tab) {
          case CycleTab.today:
            goTo(context, 'Y03');
          case CycleTab.calendar:
            goTo(context, 'Y08');
          case CycleTab.patterns:
            goTo(context, 'Y10');
        }
      },
    ),
    'Y12': (context) => CycleSettingsView(
      cycle: cycleRepository.current,
      repository: cycleRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onChangeMode: () => goTo(context, 'Y01'),
      // Deleting her cycle data returns her to Home, not to an empty hub.
      onDeleted: () => goTo(context, 'T01'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'Y13': (context) =>
        CyclePhasesView(onClose: () => Navigator.of(context).maybePop()),

    // ------------------------------------------------ Community (G10, M)
    //
    // `M01` is a tab root, so what hangs off it is one or two taps from the
    // bar. Three ids here had view models in `create_view_model.dart` and no
    // widget for a release — **M09** (Reels), **M13** (Stories) and **M16**
    // (Record) — and rendered `NotBuiltYet` rather than a control that silently
    // did nothing. All three are built and wired now, at the foot of this map.
    //
    // **M17 is deliberately absent.** "Community, day one" is the
    // `CommunityTabState.dayOne` branch of this same `FeedView`, chosen from
    // the follow graph rather than navigated to, and `firstRunStates` keeps it
    // out of `appDestinations`. `goTo(context, 'M17')` would resolve to
    // nothing, so writing it in a builder would be a dead call that also lied
    // to the reachability parser.
    //
    // Likes, saves, follows and joins are **not wired**. Every screen here is
    // a `StatelessWidget` built from a model computed once at route-build
    // time, and nothing rebuilds it — so a wired like would write to the store
    // and change nothing on screen, which is worse than a control that
    // visibly does not work. They arrive with the state holder these screens
    // need, not before it.
    'M01': (context) => FeedView(
      model: communityFeedModel(AppL10n.of(context)),
      // The only way this screen re-reads. There is no listener in community
      // by design, so refreshing is her gesture and nothing else.
      onRefresh: () async => AppChanges.bump(),
      onLike: CommunityState.instance.toggleLike,
      onSave: CommunityState.instance.toggleSave,
      onFollow: CommunityState.instance.toggleFollow,
      onJoinGroup: CommunityState.instance.joinGroup,
      onOpenPost: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M02');
      },
      onOpenProfile: (uid) {
        communityOpenProfileUid = uid;
        goTo(context, 'M07');
      },
      onOpenGroups: () => goTo(context, 'M04'),
      onOpenActivity: () => goTo(context, 'M14'),
      onOpenSearch: () => goTo(context, 'M10'),
      onOpenCreate: () {
        CommunityState.instance.composeGroupId = null;
        goTo(context, 'M03');
      },
      onOpenStory: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M13');
      },
      onMore: (postId) {
        communityOpenPostId = postId;
        communitySafetySubject = communityAuthorName(postId);
        communitySafetyUid = communityAuthorUid(postId);
        communitySafetyInGroup = false;
        CommunityState.instance.safetyPostId = postId;
        goTo(context, 'M08');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M02': (context) => PostView(
      model: communityPostModel,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenProfile: (uid) {
        communityOpenProfileUid = uid;
        goTo(context, 'M07');
      },
      onLike: () => communityOpenPostId == null
          ? null
          : CommunityState.instance.toggleLike(communityOpenPostId!),
      onSave: () => communityOpenPostId == null
          ? null
          : CommunityState.instance.toggleSave(communityOpenPostId!),
      onFollow: () => CommunityState.instance.toggleFollow(
        communityAuthorUid(communityOpenPostId),
      ),
      // She types, she sends, and it is hers at once. No dialog, and the
      // field clears itself.
      onSubmitComment: (body) => communityOpenPostId == null
          ? null
          : CommunityState.instance.addComment(communityOpenPostId!, body),
      onMore: () {
        communitySafetySubject = communityAuthorName(communityOpenPostId);
        communitySafetyUid = communityAuthorUid(communityOpenPostId);
        communitySafetyInGroup = false;
        CommunityState.instance.safetyPostId = communityOpenPostId;
        goTo(context, 'M08');
      },
      // The same destination R10 already uses for "share this": the composer.
      onShare: () => goTo(context, 'M03'),
    ),
    'M03': (context) => CreateView(
      model: communityCreateModel,
      onClose: () => Navigator.of(context).maybePop(),
      // Text is the half of the launch scope this build can make. The sheet
      // is laid over M03 rather than routed to, because the design has no
      // text-composer screen and inventing one would be inventing a screen.
      onWritePost: () => communityWritePost(context),
      // Creating is camera-first, so the reel tile, the photo-or-post row and
      // the personal-best row all open the recorder. One literal per arm.
      onOpenRecord: () => goTo(context, 'M16'),
      onOpenPhotoPost: () => goTo(context, 'M16'),
      onOpenPersonalBest: () => goTo(context, 'M16'),
      onOpenVoiceNote: () => goTo(context, 'M16'),
      onOpenFollowUp: () => goTo(context, 'M11'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M04': (context) => GroupsView(
      model: communityGroupsModel(AppL10n.of(context)),
      onBack: () => Navigator.of(context).maybePop(),
      // One tap, and the row flips to Joined. Joining is reversible, so it
      // gets no dialog — leaving is one tap on M05's overflow.
      onJoin: CommunityState.instance.joinGroup,
      onOpenSearch: () => goTo(context, 'M10'),
      onOpenGroup: (groupId) {
        communityOpenGroupId = groupId;
        goTo(context, 'M05');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M05': (context) => GroupView(
      model: communityGroupModel(AppL10n.of(context)),
      posts: communityGroupPosts,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenGoal: () => goTo(context, 'M06'),
      onOpenPost: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M02');
      },
      onJoin: () => communityOpenGroupId == null
          ? null
          : CommunityState.instance.joinGroup(communityOpenGroupId!),
      onLeave: () => communityOpenGroupId == null
          ? null
          : CommunityState.instance.leaveGroup(communityOpenGroupId!),
      onLike: CommunityState.instance.toggleLike,
      onSave: CommunityState.instance.toggleSave,
      onOpenProfile: (uid) {
        communityOpenProfileUid = uid;
        goTo(context, 'M07');
      },
      // Posting from inside a room posts INTO it: create opens as usual, and
      // the composer there opens with this group already chosen.
      onOpenCreate: () {
        CommunityState.instance.composeGroupId = communityOpenGroupId;
        goTo(context, 'M03');
      },
      onMorePost: (postId) {
        communityOpenPostId = postId;
        communitySafetySubject = communityAuthorName(postId);
        communitySafetyUid = communityAuthorUid(postId);
        communitySafetyInGroup = false;
        CommunityState.instance.safetyPostId = postId;
        goTo(context, 'M08');
      },
      onMore: () {
        communitySafetySubject = communityGroupName;
        communitySafetyUid = communityOpenGroupId ?? '';
        // The one place the sheet offers "mute this group", which is why the
        // subject being a group rather than a woman has to travel with it.
        communitySafetyInGroup = true;
        CommunityState.instance.safetyPostId = null;
        goTo(context, 'M08');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M06': (context) => GroupGoalView(
      model: communityGoalModel,
      groupName: communityGroupName,
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'M07': (context) => member.ProfileView(
      model: communityProfileModel(AppL10n.of(context)),
      selectedTab: communityProfileTab,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenSaved: () => goTo(context, 'M15'),
      onFollow: () =>
          CommunityState.instance.toggleFollow(communityOpenProfileUid),
      // A tile means a different screen depending on which of her tabs is
      // open: a photo is a post, a clip is the reel player, a follow-up is a
      // thread of several moments. Written out with one literal per arm, for
      // the reason recorded at the foot of this file — a helper here would hide
      // 'M09' and 'M12' from the reachability parser and strand both.
      //
      // The reels tab is the design's only door into `M09`
      // (`screens-community.mjs` puts it behind the `videocam` tab and behind
      // every tile with a clip on it); the feed has no reel rail.
      onOpenPost: (postId) {
        communityOpenPostId = postId;
        switch (communityProfileTabKind) {
          case ProfileTab.photos:
            goTo(context, 'M02');
          case ProfileTab.reels:
            goTo(context, 'M09');
          case ProfileTab.followUps:
            communityFollowUpParentId = postId;
            goTo(context, 'M12');
        }
      },
      // Her tabs are a rebuild, not a local setState: the tiles behind each
      // one are a different read of the store.
      onSelectTabIndex: (index) {
        communityProfileTab = index;
        AppChanges.bump();
      },
      onMore: () {
        communitySafetySubject = communityProfileModel(AppL10n.of(context))
            .name;
        communitySafetyUid = communityOpenProfileUid;
        communitySafetyInGroup = false;
        CommunityState.instance.safetyPostId = null;
        goTo(context, 'M08');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Two taps to safety, from a post, a profile or a group.
    //
    // `onBlock` writes through the same `BlockService` A04 reads, so a woman
    // blocked here is already blocked when she opens the safety centre.
    // `onReport` and `onMute` are **not** wired: filing a report needs a
    // `ReportReason` and this sheet collects none — the reason picker is not
    // among the designed screens — and there is no mute on
    // `CommunityRepository` at all. Both are reported rather than wired to
    // something that would look like it worked.
    'M08': (context) => SafetySheetView(
      model: communitySafetyModel,
      onBlock: () {
        unawaited(blockService.block(communitySafetyUid, BlockSource.post));
        Navigator.of(context).maybePop();
      },
      // The reasons are a second step inside the sheet. The report goes to the
      // same service A04 reads, and the note says only what is true: it was
      // sent. Nothing claims a moderator has read it.
      onReportReason: (reason) {
        unawaited(CommunityState.instance.report(communitySafetyUid, reason));
        showHonestNotice(context, AppL10n.of(context).reportSent);
        Navigator.of(context).maybePop();
      },
      onMute: communitySafetyInGroup && !communityGroupIsMuted
          ? () {
              unawaited(CommunityState.instance.muteGroup(communitySafetyUid));
              Navigator.of(context).maybePop();
            }
          : null,
      onUnmute: communitySafetyInGroup && communityGroupIsMuted
          ? () {
              unawaited(
                CommunityState.instance.unmuteGroup(communitySafetyUid),
              );
              Navigator.of(context).maybePop();
            }
          : null,
      onLeaveGroup: communitySafetyInGroup && communityGroupIsJoined
          ? () {
              unawaited(CommunityState.instance.leaveGroup(communitySafetyUid));
              Navigator.of(context).maybePop();
            }
          : null,
      // Only ever her own post, and only when the sheet is about one.
      onDelete: communityOwnPostInSheet == null
          ? null
          : () {
              unawaited(
                CommunityState.instance.deletePost(communityOwnPostInSheet!),
              );
              Navigator.of(context).maybePop();
            },
      onCancel: () => Navigator.of(context).maybePop(),
    ),
    'M10': (context) => ExploreView(
      model: communityExploreModel,
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTopic: (topic) {
        communityTopic = topic;
        AppChanges.bump();
      },
      onOpenPost: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M02');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M11': (context) => FollowUpComposerView(
      model: communityFollowUpComposerModel,
      onClose: () => Navigator.of(context).maybePop(),
      // The card is an offer, and the two integers on it are her own: sessions
      // she logged and weeks that counted, read from G6's rollups. There is no
      // parameter here a weight could enter through.
      onToggleCost: (on) {
        CommunityState.instance.followUpCostOn = on;
        AppChanges.bump();
      },
      onSelectParent: (postId) {
        communityFollowUpParentId = postId;
        AppChanges.bump();
      },
      onCaptionChanged: (text) =>
          CommunityState.instance.followUpCaption = text,
      // Posting lands on the thread the new moment joined, which is the only
      // screen that shows what she just made next to what it follows.
      onPost: () {
        communityPostFollowUp(context);
        goTo(context, 'M12');
      },
    ),
    'M12': (context) => FollowUpThreadView(
      model: communityFollowUpThreadModel,
      post: communityFollowUpParentCard,
      onBack: () => Navigator.of(context).maybePop(),
      // Null, not a callback that returns null: opened from the index there is
      // no parent moment to like or save, and a control with no callback is
      // drawn and announced as unavailable rather than looking live and
      // answering with nothing.
      onLike: communityFollowUpParentId == null
          ? null
          : () =>
                CommunityState.instance.toggleLike(communityFollowUpParentId!),
      onSave: communityFollowUpParentId == null
          ? null
          : () =>
                CommunityState.instance.toggleSave(communityFollowUpParentId!),
      onOpenProfile: (uid) {
        communityOpenProfileUid = uid;
        goTo(context, 'M07');
      },
      onMore: () {
        communitySafetySubject = communityAuthorName(communityFollowUpParentId);
        communitySafetyUid = communityAuthorUid(communityFollowUpParentId);
        communitySafetyInGroup = false;
        goTo(context, 'M08');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M14': (context) => ActivityView(
      model: communityActivityModel,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenPost: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M02');
      },
      // The follow-up prompt is the one nudge on this screen, and it carries
      // the post it is about.
      onAddFollowUp: (postId) {
        communityFollowUpParentId = postId;
        CommunityState.instance.followUpCaption = '';
        goTo(context, 'M11');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M15': (context) => SavedView(
      model: communitySavedModel,
      selectedFilter: communitySavedFilter,
      onBack: () => Navigator.of(context).maybePop(),
      onSelectFilter: (index) {
        communitySavedFilter = index;
        AppChanges.bump();
      },
      onOpenPost: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M02');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),

    // ------------------------------------------ The coach's app (G12, K)
    //
    // `K07` (Today) and `K17` (Earnings) are two of her four tabs; `W01` and
    // `W10` are the other two and belong to the planning group, which has
    // shipped — so all four tabs on her bar are live.
    //
    // **K24 is deliberately absent.** "Today, day one" is the empty-roster
    // branch of this same `CoachTodayView` — `CoachToday.resolve` reads her
    // capacity, and accepting a first client flips the branch with no
    // navigation at all. `firstRunStates` keeps it out of `appDestinations`.
    //
    // **K18, her public profile, now has a door**, and it is not the one the
    // prototype drew. That was a row on `K17`, and `coach_earnings_view.dart`
    // deliberately points it at `K05` instead, because a payout method has
    // nothing to do with a public profile — a decision that stands. The way in
    // is an action on `K07`, her desk, labelled with the same dictionary string
    // the screen titles itself with.
    //
    // **Every step saves.** The form was one object already; what was missing
    // is that nothing ever wrote it to `coachRepository`, which is the profile
    // `K06`, `K07`, `K18` and the directory all read. `saveSetup` is that
    // write, and it goes through `CoachProfileEditor` — the same field-scoped,
    // rule-enforcing path a server would use — so four specialties or a
    // capacity of ninety is refused here too.
    'K01': (context) => CoachBasicsView(
      model: coachSetupModel,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K02');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K02': (context) => CoachCertificatesView(
      model: coachSetupModel,
      now: DateTime.now(),
      // In test mode a certificate is recorded without a photo — there is no
      // file picker here — and `K02` draws the row as a test that nobody has
      // reviewed. With an account required this is null and the row is inert.
      onAddCertificate: CoachProfileState.isTestMode
          ? (credentialId) =>
                CoachProfileState.instance.addTestCertificate(credentialId)
          : null,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K03');
      },
      onBack: () => goTo(context, 'K01'),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K03': (context) => CoachSpecialtiesView(
      model: coachSetupModel,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K04');
      },
      onBack: () => goTo(context, 'K02'),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K04': (context) => CoachPackagesView(
      model: coachSetupModel,
      flags: featureFlags,
      // The single write path for offers in this application. `K18` and `B06`
      // are handed a reader and physically cannot write one.
      editor: CoachProfileState.instance.packagesEditor,
      onOffersChanged: CoachProfileState.instance.publishOffersIfAllowed,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K05');
      },
      onBack: () => goTo(context, 'K03'),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K05': (context) => CoachPayoutView(
      model: coachSetupModel,
      flags: featureFlags,
      // The test rail, and only while no account is required. It records where
      // she would be paid and pays nobody; `K05` and `K17` say so in words.
      onSetPayout: CoachProfileState.isTestMode
          ? CoachProfileState.instance.setTestPayout
          : null,
      // Completing setup is what submits her for the check — and, in test
      // mode, what makes her a test coach so the rest can be walked.
      onContinue: () {
        CoachProfileState.instance.completeSetup();
        goTo(context, 'K06');
      },
      onBack: () => goTo(context, 'K04'),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K06': (context) => CoachBeingCheckedView(
      verification: coachRepository.profileUnbilled.verification,
      // The tick above says her certificates are cleared. Nobody looked at
      // them: while sign-up is off she counts as checked so the coach side can
      // be walked, and the screen has to say that rather than let the tick
      // claim a reviewer.
      note: CoachProfileState.instance.isTestCoach
          ? AppL10n.of(context).whileSignUpIsSwitchedOffYou
          : null,
      onReplaceCertificate: () => goTo(context, 'K02'),
      onBuildFirstPlan: () => goTo(context, 'K20'),
      onSeeToday: () => goTo(context, 'K07'),
    ),
    'K07': (context) => CoachTodayView(
      model: coachTodayModel,
      now: DateTime.now(),
      onNotifications: () => goTo(context, 'A01'),
      onStartReviews: () {
        coachPlanOpenClient = coachDesk.longestWaiting;
        goTo(context, 'W09');
      },
      onOpenClients: () => goTo(context, 'W01'),
      onOpenPortfolio: () => goTo(context, 'B01'),
      onOpenPublicProfile: () => goTo(context, 'K18'),
      onOpenFirstWeek: () => goTo(context, 'K25'),
      // A row on her desk leads somewhere different depending on why it is
      // waiting, and the row only hands back its relationship id — so the
      // reason is looked up here and each arm carries its own literal. A
      // `deskReasonDestination(...)` call would compile, work, and hide K09
      // and K16 from the reachability parser.
      onOpenRow: (relId) {
        coachOpenRelId = relId;
        // The row carries a relationship; the planning screens are about a
        // client. Opening her here is what lets K16's thread and W09's week
        // be about the woman whose row she just tapped.
        coachPlanOpenClient = coachDesk.clientFor(coachDesk.clientUidOf(relId));
        switch (coachDeskReason(relId)) {
          case DeskReason.newEnquiry:
            goTo(context, 'K09');
          case DeskReason.message:
            goTo(context, 'K16');
          case DeskReason.reviewDue:
          case DeskReason.checkIn:
            goTo(context, 'W09');
        }
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Her real enquiry, read back from the repository the marketplace mirrored
    // it onto — her words, her situation, her status. The fabricated empty one
    // is only what a row opened before anybody enquired resolves to.
    'K09': (context) => CoachEnquiryView(
      enquiry: coachDesk.enquiryAt(coachOpenRelId) ?? coachOpenEnquiry,
      verification: coachRepository.profileUnbilled.verification,
      hasRoom: coachRepository.profileUnbilled.capacity.hasRoom,
      // Accepting takes one of her places and moves the marketplace stage, the
      // enquiry status and the desk queue together — which is what stops a
      // coach being oversold. Null when there is nothing waiting on her.
      onAccept: coachDesk.enquiryAt(coachOpenRelId) == null
          ? null
          : () {
              coachDesk.acceptEnquiry(coachOpenRelId);
              goTo(context, 'W01');
            },
      onDecline: coachDesk.enquiryAt(coachOpenRelId) == null
          ? null
          : () {
              coachDesk.declineEnquiry(coachOpenRelId);
              goTo(context, 'K07');
            },
      onBack: () => goTo(context, 'K07'),
    ),
    // One thread, two screens. `G14` writes into the same list from the other
    // side, because the relationship id is derived from both women.
    'K16': (context) => CoachChatView(
      messages: coachDesk.threadFor(coachThreadRelId),
      clientName: coachPlanClient.displayName,
      onBack: () => goTo(context, 'W10'),
      onOpenClient: () => goTo(context, 'W02'),
      onSendText: coachThreadRelId.isEmpty
          ? null
          : (text) => coachDesk.sendMessage(
              relId: coachThreadRelId,
              body: text,
              fromCoach: true,
            ),
    ),
    // Her month, from the payments the test rail actually settled — and
    // unavailable rather than zero until one has been.
    'K17': (context) => CoachEarningsView(
      model: CoachEarningsViewModel.from(
        earnings: coachDesk.earnings,
        payout: coachSetupModel.payout,
        flags: featureFlags,
      ),
      onOpenPayoutMethod: () => goTo(context, 'K05'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'K25': (context) => CoachFirstWeekView(
      firstWeek: coachRepository.deskUnbilled.firstWeek,
      onClose: () => goTo(context, 'K07'),
      onBackToToday: () => goTo(context, 'K07'),
      onSetUpAssessment: () => goTo(context, 'K21'),
      // Each step already carries the screen it leads to, so this passes it
      // on rather than restating four ids the view owns.
      onOpenStep: (screenId) => goTo(context, screenId),
    ),

    // --------------------------------------- Her portfolio (G13, B-flow)
    //
    // `B01` was wired alone while it was the only B screen with a widget. The
    // rest are built now and are wired at the foot of this map, beside the
    // account of the two that are not: **B12**, which has no widget and should
    // not have one until something measures, and `portfolio_view`, which is the
    // block renderer both B10 and H02 draw with — a `Column`, not a screen.
    //
    // **B14 is deliberately absent**, for the same reason M17 and K24 are: it
    // is `PortfolioHomeState.isDayOne`, a getter on the state this builder
    // already passes, and `P0-PORT-01` requires that no `/coachbrand/b14`
    // destination is ever navigated to.
    'B01': (context) => PortfolioHomeView(
      state: portfolio.home,
      onBack: () => goTo(context, 'K07'),
      onDesign: () => goTo(context, 'B02'),
      onPreview: () => goTo(context, 'B10'),
      onOpenInsights: () => goTo(context, 'B12'),
      onOpenAds: () => goTo(context, 'B09'),
      onOpenResults: () {
        portfolio.editing = null;
        goTo(context, 'B08');
      },
      onOpenSections: () => goTo(context, 'B03'),
      // The day-one screen's one action: start with the cover. No row has been
      // tapped, so the editor has no block — clearing it is what makes the
      // cover editor add one on her first keystroke rather than save into
      // whichever block she last opened.
      onStart: () {
        portfolio.editing = null;
        goTo(context, 'B04');
      },
    ),

    // ------------------------------------- Being coached (G11, G-flow)
    //
    // Every screen here is downstream of the marketplace, and **the
    // marketplace has shipped**. `H05` (My coach) is the only door to the plan,
    // exactly as `nav_reachability_test`'s `_awaitingInboundScreen` recorded;
    // the door to the intake is `H03` rather than `H04`, because removing
    // buy-direct moved the pay button onto the packages screen. All seventeen
    // exemptions lapsed by themselves the moment those two entered `_built`,
    // and they have been deleted — every one of the seventeen now has a real
    // inbound edge from a screen that exists.
    // The three intake steps write three real answers, each a merge of its own
    // fields: abandoning after two leaves two, which is the shape the
    // repository was built for.
    'G01': (context) => CoachingIntakeView(
      coachName: coachedLife.coachName.isEmpty ? null : coachedLife.coachName,
      selectedGoal: coachedLife.goal,
      selectedDays: coachedLife.trainingDays,
      selectedSessionLength: coachedLife.sessionLength,
      selectedPlace: coachedLife.places,
      onGoal: coachedLife.setGoal,
      onDay: coachedLife.toggleTrainingDay,
      onSessionLength: coachedLife.setSessionLength,
      onPlace: coachedLife.togglePlace,
      onClose: () => Navigator.of(context).maybePop(),
      onContinue: () {
        coachedLife.saveTraining();
        goTo(context, 'G17');
      },
      onMessageCoach: () => goTo(context, 'H05'),
    ),
    // Step 2 of 3 — the food step the prototype's intake announced and never
    // built, which is why its back edge is the only one here that does not
    // match `PHASE3-NAV-GRAPH.json`: the markup sends G02 back to G01 because
    // G17 did not exist when it was drawn.
    //
    // **Her allergies are written to her profile, not to the intake.** That is
    // the one place they live, and it is where the coach's meal planner reads
    // them from — which is what makes W06 refuse a conflicting slot.
    'G17': (context) => CoachingFoodView(
      selectedAllergens: <int>{
        for (final tag in coachedLife.allergens)
          AllergenTag.values.indexOf(tag),
      },
      selectedDietary: <int>{
        for (final tag in coachedLife.diets) DietaryTag.values.indexOf(tag),
      },
      selectedCookMinutes: coachedLife.cookMinutes,
      familyPot: coachedLife.familyPot,
      onAllergen: coachedLife.toggleAllergen,
      onDietary: coachedLife.setDiet,
      onCookMinutes: coachedLife.setCookMinutes,
      onFamilyPot: coachedLife.setFamilyPot,
      onBack: () => goTo(context, 'G01'),
      onContinue: () {
        coachedLife.saveFood();
        goTo(context, 'G02');
      },
    ),
    'G02': (context) => CoachingSupportView(
      dailyCheckin: coachedLife.dailyCheckin,
      onDailyCheckin: coachedLife.setDailyCheckin,
      onBack: () => goTo(context, 'G17'),
      onSend: () {
        coachedLife.submitIntake();
        goTo(context, 'G03');
      },
      // Cycle sharing is her setting, and it lives in one place: G9's screen.
      onPreviewSharing: () => goTo(context, 'Y12'),
    ),
    'G03': (context) => PreparingView(
      coachName: coachedLife.coachName.isEmpty ? null : coachedLife.coachName,
      onMessageCoach: () => goTo(context, 'G14'),
      onTrainOnYourOwn: () => goTo(context, 'R01'),
      onMyCycle: () => goTo(context, 'Y03'),
      onExampleDay: () => goTo(context, 'G04'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Her plan, in her coach's own words. Every string below is null until
    // something was published for her, and null renders nothing rather than
    // the prototype's "Full body strength" on a woman with no plan.
    'G04': (context) {
      final life = coachedLife;
      final strip = life.stripDays(AppL10n.of(context));
      final workout = life.workout;
      final numbering = life.dayNumber;
      return CoachingPlanView(
        days: strip.isEmpty ? null : strip,
        selectedDay: life.selectedIndexInWeek,
        dayLabel: numbering == null
            ? null
            : AppL10n.of(context)
                  .countOfTotal('${numbering.day}', '${numbering.total}'),
        workoutTitle: workout?.title,
        workoutLength: workout == null || workout.minutes == 0
            ? null
            : countLabel(workout.minutes),
        coachNote: workout?.note,
        mealTitle: coachedLife.mealTitle(
          AppL10n.of(context),
          PlanMealSlot.lunch,
        ),
        reviewDue: life.hasPlan,
        onSelectDay: (index) {
          final week = life.weekDays;
          if (index < week.length) life.selectDay(week[index]);
        },
        onStartWorkout: () => goTo(context, 'G06'),
        onSeeMonth: () => goTo(context, 'G05'),
        onLogMeal: () => goTo(context, 'G10'),
        onOpenReview: () => goTo(context, 'G12'),
        onOpenPlanChange: () => goTo(context, 'G13'),
        onSelectTab: (screenId) => goTo(context, screenId),
      );
    },
    // The month, counted from the plan and ticked from her logs — never the
    // preview days dated 2026-09-08.
    'G05': (context) => ThirtyDaysView(
      days: coachedLife.calendar.isEmpty ? null : coachedLife.calendar,
      // In test mode this row is what ends the engagement, because nothing
      // else can: there is no renewal clock here. It says so.
      subscriptionLabel:
          CoachingLinkState.isTestMode && coachedLife.relId != null
          ? AppL10n.of(context).endThisCoachingNowTest
          : null,
      onBack: () => goTo(context, 'G04'),
      onOpenDay: (day) {
        coachedLife.selectDay(dayId(day.date));
        goTo(context, 'G06');
      },
      onOpenSubscription: () {
        final relId = coachedLife.relId;
        if (CoachingLinkState.isTestMode && relId != null) {
          coaching.endCoaching(relId);
        }
        goTo(context, 'G16');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // The session her coach wrote. **No set lines**: a move must come from the
    // bundled exercise pack, there is no pack in this build, and the planner
    // therefore prescribes a session rather than a list of exercises.
    'G06': (context) => AssignedWorkoutView(
      moveTitle: coachedLife.workout?.title,
      coachNote: coachedLife.workout?.note,
      onClose: () => goTo(context, 'G04'),
      onCompleteSet: () {
        coachedLife.completeSet();
        goTo(context, 'G07');
      },
      onSwap: () => goTo(context, 'G08'),
      onAsk: () => goTo(context, 'G14'),
      onSkip: () => goTo(context, 'G07'),
    ),
    'G07': (context) => RestBetweenSetsView(
      handle: handleFrom(context),
      onClose: () => goTo(context, 'G04'),
      onReady: () => goTo(context, 'G06'),
      onSkipTimer: () => goTo(context, 'G06'),
      onShareForm: () => goTo(context, 'G15'),
      onFinishWorkout: () => goTo(context, 'G09'),
    ),
    'G08': (context) => SwapExerciseView(
      onClose: () => goTo(context, 'G06'),
      onChoose: (_) => goTo(context, 'G06'),
      onAskCoach: () => goTo(context, 'G14'),
      onSkip: () => goTo(context, 'G06'),
    ),
    // The session is recorded in **her logs**, never in the plan — which is
    // what W09's "workouts, 1 of 3" then counts.
    'G09': (context) => SessionDoneView(
      headline: coachedLife.workout?.title,
      selectedEffort: coachedLife.effort,
      onEffort: coachedLife.setEffort,
      onSend: () {
        coachedLife.markSessionDone();
        goTo(context, 'G04');
      },
      onBackToToday: () => goTo(context, 'G04'),
    ),
    // The slot her coach planned, as her coach planned it: one of her own
    // dishes, a food from the pack, or a stated free choice.
    'G10': (context) => LogPlannedMealView(
      title: mealSlotLabel(AppL10n.of(context), coachedLife.slot),
      foodName: coachedLife.mealTitle(AppL10n.of(context), coachedLife.slot),
      ingredients: coachedLife.mealIngredients(coachedLife.slot),
      onClose: () => goTo(context, 'G04'),
      // One tap, and five seconds to undo it on G11. Never a confirm.
      onLog: () {
        coachedLife.logMeal();
        goTo(context, 'G11');
      },
      // She ate something else. That is the product's own food logger, not a
      // second one built inside coaching.
      onSomethingElse: () => goTo(context, 'E02'),
    ),
    'G11': (context) => MealLoggedView(
      slots: <SlotChip>[
        for (final slot in PlanMealSlot.values)
          SlotChip(
            name: mealSlotLabel(AppL10n.of(context), slot),
            state: coachedLife.isLogged(coachedLife.day, slot)
                ? AppL10n.of(context).logged
                : AppL10n.of(context).planned,
            logged: coachedLife.isLogged(coachedLife.day, slot),
          ),
      ],
      itemName: coachedLife.mealTitle(AppL10n.of(context), coachedLife.slot),
      selectedPortion: coachedLife.portion,
      onPortion: coachedLife.setPortion,
      // The five-second undo, and the only way back out of a log.
      undoMessage: coachedLife.lastLogged == null
          ? null
          : AppL10n.of(context).tapOneAndItIsSavedUndo,
      onUndo: coachedLife.lastLogged == null
          ? null
          : () {
              coachedLife.undoLastMeal();
              goTo(context, 'G04');
            },
      onEdit: () => goTo(context, 'G10'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // Her week, from her own logs, answered in her own words. What she sends
    // is what W09 shows her coach.
    'G12': (context) {
      final relId = coachedLife.relId ?? '';
      final review = coachDesk.openReview(relId);
      final summary = coachDesk.summaryFor(CoachingLinkState.clientUid);
      return WeeklyReviewView(
        workoutsCompleted: summary.rollupAvailable
            ? AppL10n.of(context).countOfTotal(
                '${summary.sessionsLogged}',
                '${summary.sessionsPlanned}',
              )
            : null,
        foodDaysLogged: '${summary.mealDaysLogged}',
        selectedManageable: review.manageable,
        selectedChanges: review.changes,
        weightOptIn: review.weightOptIn,
        onManageable: (value) =>
            coachDesk.editReview(relId, review.copyWith(manageable: value)),
        onChange: (value) => coachDesk.editReview(
          relId,
          review.copyWith(
            changes: review.changes.contains(value)
                ? (<int>{...review.changes}..remove(value))
                : <int>{...review.changes, value},
          ),
        ),
        onWorkedChanged: (text) =>
            coachDesk.reviews[relId] = review.copyWith(worked: text),
        onWeightOptIn: (value) =>
            coachDesk.editReview(relId, review.copyWith(weightOptIn: value)),
        onClose: () => goTo(context, 'G04'),
        onSend: () {
          coachDesk.submitReview(relId);
          goTo(context, 'G13');
        },
      );
    },
    // Her coach's answer, in her coach's words. Absent until W09 saved one.
    'G13': (context) => CoachRepliedView(
      coachName: coachedLife.coachName.isEmpty ? null : coachedLife.coachName,
      planChange: coachDesk.reviewFor(coachedLife.relId ?? '')?.coachWords,
      onBack: () => goTo(context, 'G04'),
      onReplyInChat: () => goTo(context, 'G14'),
      onOpenPlanChange: () => goTo(context, 'G05'),
    ),
    // The same thread K16 shows the coach, from this side.
    'G14': (context) => CoachedChatView(
      coachName: coachedLife.coachName.isEmpty ? null : coachedLife.coachName,
      entries: <ThreadEntry>[
        for (final message in coachDesk.threadFor(coachedLife.relId ?? ''))
          ThreadEntry.message(
            mine: message.senderUid == CoachingLinkState.clientUid,
            text: message.body,
          ),
      ],
      composerEnabled: coachedLife.relId != null,
      onSendText: coachedLife.relId == null
          ? null
          : (text) => coachDesk.sendMessage(
              relId: coachedLife.relId!,
              body: text,
              fromCoach: false,
            ),
      onBack: () => goTo(context, 'G04'),
      onVoice: () => goTo(context, 'G15'),
    ),
    'G15': (context) => VoiceNoteView(
      onBack: () => goTo(context, 'G14'),
      onCancel: () => goTo(context, 'G14'),
      onSend: () => goTo(context, 'G14'),
    ),
    'G16': (context) => CoachingEndedView(
      onOpenPlan: () => goTo(context, 'G05'),
      onOpenConversation: () => goTo(context, 'G14'),
      // "Your reviews" is G12, the weekly review. It pointed at G13 — "Coach
      // replied" — and a message from her coach is not a review she wrote; it
      // is the answer to one. G13 keeps its inbound edges from G12's send and
      // from H05's "last review" row, so this repoint strands nothing.
      onOpenReviews: () => goTo(context, 'G12'),
      // Renewal starts a NEW engagement, and **buy-direct is removed**, so it
      // opens the enquiry and not the checkout: a coach accepts before a pound
      // moves, on a renewal exactly as on a first hire. This pointed at H03,
      // which was the old "straight to packages" path.
      onWorkAgain: () => goTo(context, 'H04'),
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    // -------------------------------------------- The marketplace (G11, H)
    //
    // **Enquiry-first.** Buy-direct was removed, so the order a woman actually
    // moves through is H01 → H02 → **H04** (message her before she decides) →
    // **H03** (her packages, and the checkout, once the coach has accepted) →
    // `G01`. The prototype had it the other way round: `H03` was a price list
    // whose "Continue" led to `H04`, the payment form, and `H04`'s "Pay" was
    // the only door into the intake. **The pay button moved to H03**, so the
    // edge the design draws as "H04 → G01" is written on H03 below. The
    // exemption in `nav_reachability_test` naming H04 as `G01`'s blocker was
    // naming the *pay* screen, and the pay screen changed id.
    //
    // **Nothing is seeded.** There is no coaching repository in this build, so
    // the directory is `DirectorySnapshot.unavailable()`: H01 says it could not
    // load rather than "no coaches found", which would be a claim about the
    // product instead of about the read. Every model below is built from the
    // same absence — no coach, no page, no offers, no relationship — and the
    // gates refuse accordingly, which is the truthful rendering of this build.
    //
    // **H06 is not wired**, and it is the one screen here that could not be.
    // `coaching_ended_view.dart` repurposed it: the prototype's H06 was the
    // chat thread, the thread belongs to `G14`, and what the marketplace owns
    // at the end of a relationship is "what stays readable". Nothing in the
    // built product opens that. `H05` is its parent — the view's own back edge
    // says so — and `MyCoachView` has no callback for it, and the design's only
    // other doors into H06 were the assistant's "Ask Sara", which goes to the
    // thread itself now. Wiring it would put a finished screen in this map that
    // no woman can reach, which is the exact thing this map exists to make
    // visible.
    'H01': (context) => FindACoachView(
      // The pack, and it holds whoever has published a page. Empty is
      // `nothingMatched` — a real answer — where `unavailable()` was the
      // network having failed, which is a different sentence.
      model: FindACoachViewModel(snapshot: coaching.snapshot),
      // The promise under the title is the product's and it holds the day a
      // reviewer exists. Nobody has checked anything here, so the screen says
      // that instead of making a promise about the rows underneath it.
      note: CoachingLinkState.isTestMode
          ? AppL10n.of(context).testModeCoachesSetUpOnThis
          : null,
      onBack: () => Navigator.of(context).maybePop(),
      // The row carries the coach it is about, recorded inline at the tap for
      // the same reason `communityOpenPostId` is.
      onOpenCoach: (coachUid) {
        marketplaceOpenCoachUid = coachUid;
        marketplaceSelectedOfferId = null;
        goTo(context, 'H02');
      },
    ),
    'H02': (context) => CoachProfileView(
      model: CoachProfileViewModel(
        // Her published page, or null. Null renders "nothing has been written
        // yet"; her name over an empty page would suggest she had written one.
        page: coaching.pageFor(marketplaceOpenCoachUid),
        offers: coaching.offersFor(marketplaceOpenCoachUid),
        stage: coaching.stageWith(marketplaceOpenCoachUid),
        flags: featureFlags,
        verified: marketplaceVerified,
      ),
      onBack: () => goTo(context, 'H01'),
      onSeePackages: () => goTo(context, 'H03'),
      onMessageFirst: () => goTo(context, 'H04'),
    ),
    'H03': (context) => PackagesView(
      model: packagesModel,
      onBack: () => goTo(context, 'H02'),
      // The selection decides which price the gate clears, so it is recorded
      // and the screen redrawn from the answer rather than from the tap.
      onSelectOffer: (offerId) {
        marketplaceSelectedOfferId = offerId;
        AppChanges.bump();
      },
      // What the rail is. Drawn above the button that spends money.
      testNote: CoachingLinkState.isTestMode
          ? AppL10n.of(context).testPaymentNoMoneyMoves
          : null,
      // `CheckoutGate` opens a checkout from one stage: the coach accepted.
      // That is not relaxed. One woman holds both roles here, so on her OWN
      // coach page the accept she is waiting for is offered to her, labelled
      // as the coach's act. Null on anybody else's page.
      onTestAccept: coaching.mayTestAccept(marketplaceOpenCoachUid)
          ? () => coaching.acceptEnquiry(
              coaching.relIdOrNull(marketplaceOpenCoachUid) ?? '',
            )
          : null,
      testAcceptNote: AppL10n.of(context).testModeThisIsYourOwnCoach,
      // Paying is what opens the intake: three questions her coach needs
      // answered before she can write a plan. The rail settles through the
      // ledger, and only a record the ledger calls paid gets here.
      onPay: (offer, rail) {
        coaching
            .pay(coachUid: marketplaceOpenCoachUid, offer: offer, rail: rail)
            .then((record) {
              if (!context.mounted) return;
              if (record == null || !record.state.unlocksCoaching) return;
              goTo(context, 'G01');
            });
      },
    ),
    'H04': (context) => EnquiryView(
      model: enquiryModel,
      onBack: () => goTo(context, 'H02'),
      // The one write the marketplace has. It moves no money and takes no
      // place; it is stored under the relationship id both parties derive, so
      // a second send collapses onto the first rather than forking the thread.
      onSend: (text) => coaching.send(
        EnquiryDraft(
          coachUid: marketplaceOpenCoachUid,
          clientUid: _selfUid,
          herWords: text,
        ),
      ),
      onOpenCoaching: () => goTo(context, 'H05'),
    ),
    'H05': (context) => MyCoachView(
      // Her coaching, once she has some. Null until then, and the empty state
      // IS the onboarding.
      model: MyCoachViewModel(snapshot: coaching.myCoachSnapshot),
      onFindACoach: () => goTo(context, 'H01'),
      onOpenChat: () => goTo(context, 'H06'),
      onOpenPlan: () => goTo(context, 'G04'),
      onOpenReview: () => goTo(context, 'G12'),
      onOpenLastReview: () => goTo(context, 'G13'),
    ),
    // The same conversation as `G14`, read from the same thread and written
    // back to it. Two doors, one room: the coaching tab opens it from H05 and
    // the plan opens it from G04, and a message sent through either is the
    // message the other shows.
    'H06': (context) => CoachedChatView(
      coachName: coachedLife.coachName.isEmpty ? null : coachedLife.coachName,
      entries: <ThreadEntry>[
        for (final message in coachDesk.threadFor(coachedLife.relId ?? ''))
          ThreadEntry.message(
            mine: message.senderUid == CoachingLinkState.clientUid,
            text: message.body,
          ),
      ],
      composerEnabled: coachedLife.relId != null,
      onSendText: coachedLife.relId == null
          ? null
          : (text) => coachDesk.sendMessage(
              relId: coachedLife.relId!,
              body: text,
              fromCoach: false,
            ),
      onBack: () => goTo(context, 'H05'),
      onVoice: () => goTo(context, 'G15'),
    ),

    // ------------------------------------------------ The assistant (G15, X)
    //
    // **There is no model behind this.** `UnavailableAssistantProvider` is the
    // only implementation in the tree, so `X01` opens on
    // `AssistantUnavailableReason.notImplemented` — today's state, named on
    // screen — and `onAsk` is left unwired rather than taking a question that
    // goes nowhere. Rendering the idle state instead would invite her to ask.
    //
    // **X02 is not wired.** `RefusalView` requires a `RefusalCategory`, which
    // is the guardrail's verdict on a question somebody asked; nothing in this
    // build can produce one, and choosing a category would put a reason in her
    // mouth — "I cannot tell you whether that is normal" to a woman who asked
    // nothing. It has no door either: a refusal is a STATE of `X01`, drawn
    // inline by `AssistantRefusalBody`, and `AskView` has no callback that
    // navigates to the standalone route.
    'X01': (context) => AskView(
      screen: const AskScreen(
        state: AskState.unavailable,
        reason: AssistantUnavailableReason.notImplemented,
      ),
      onBack: () => Navigator.of(context).maybePop(),
      onBoundaries: () => goTo(context, 'X03'),
      // The design sends "Ask Sara" to `H06`, which was the chat thread. The
      // thread moved to `features/coached` when H06 became "coaching ended" —
      // `coaching_ended_view.dart` records the move — so this opens the thread
      // itself, exactly as H05's chat icon does.
      onAskSara: () => goTo(context, 'G14'),
      // The design sends "find care" to `Y11`, which is a STATE of the cycle
      // hub and not a destination: `goTo(context, 'Y11')` resolves through
      // `appDestinations`, which excludes it, so the call would be a silent
      // no-op that also lied to the reachability parser. Y03 is the hub that
      // renders that branch.
      onFindCare: () => goTo(context, 'Y03'),
      // A swap is a **proposal**. G4's swap screen is what writes, after her
      // tap there; nothing on X01 changes a plan.
      onSwap: (proposal) => goTo(context, 'R05'),
    ),
    'X03': (context) => BoundariesView(
      boundaries: assistantBoundaries(AppL10n.of(context)),
      switchedOff: !featureFlags.isOn(Feature.assistant),
      onBack: () => Navigator.of(context).maybePop(),
      onAsk: () => goTo(context, 'X01'),
      onAskSara: () => goTo(context, 'G14'),
    ),
    // K26 and K27 are the coach's two draft screens, and they belong to the
    // planning flow rather than to hers — `W03` and `W06` are the only doors,
    // which is exactly where the assistant would hand a draft over.
    //
    // **A draft is held.** Both open empty because nothing has drafted one:
    // there is no model, so there is no plan and no meal week to show. Neither
    // screen publishes, and `onOpenInPlanner` is a navigation — the planner
    // performs the write, after the tap.
    'K26': (context) => PlanDraftView(
      screen: PlanDraftScreen.empty,
      onClose: () => Navigator.of(context).maybePop(),
      onBoundaries: () => goTo(context, 'X03'),
      onOpenInPlanner: () => goTo(context, 'W03'),
      onDiscard: () => goTo(context, 'W03'),
    ),
    'K27': (context) => MealDraftView(
      screen: MealDraftScreen.empty,
      onClose: () => Navigator.of(context).maybePop(),
      onBoundaries: () => goTo(context, 'X03'),
      onOpenInPlanner: () => goTo(context, 'W06'),
      onDiscard: () => goTo(context, 'W06'),
    ),

    // ------------------------------------ Her planning desk (G14, W and K19+)
    //
    // `W01` and `W10` are the other two tabs on her bar, so her bottom bar is
    // live on all four at last. Both take their select callback as `onTab`
    // rather than `onSelectTab` — the same bar, this feature's name for it.
    //
    // **W11 is deliberately absent**, for the same reason M17, K24 and B14 are:
    // "Clients, none yet" is the `isFirstRun` branch of this same `ClientsView`,
    // chosen from an empty roster, and `firstRunStates` keeps it out of
    // `appDestinations`. It is what W01 renders today, because the roster is
    // genuinely empty.
    //
    // **W08 and K22 are built now**, and the two reasons they could not be have
    // both gone: `K21`/`K23` record a real `AssessmentRecord`, so a publish
    // context carries the life stage a woman was actually screened at, and a
    // re-assessment has a parent to hang off. With nothing recorded, `W08`
    // still says so — `hasAssessment: false` draws the "no assessment on file"
    // card, which is the screen's own designed answer — and nothing here makes
    // the gate more permissive than the domain does.
    //
    // Every document these screens write lives in `coachDesk`: one month per
    // client, one assessment per client, one thread per relationship. That is
    // what makes `W03` keep what she planned — it used to be handed a **new**
    // empty `PlanDraft` on every build.
    'W01': (context) => ClientsView(
      // Her roster, and **loaded**: `hasLoaded` is the difference between
      // "nobody yet" and "we have not looked". Empty until she accepts
      // somebody, and that empty is `W11`.
      clients: coachPlanClients,
      hasLoaded: true,
      now: DateTime.now(),
      onOpenClient: (client) {
        coachPlanOpenClient = client;
        goTo(context, 'W02');
      },
      // The "Start" on the longest-waiting row, the same destination K07's
      // waiting card uses.
      onStartWaiting: () {
        coachPlanOpenClient = coachDesk.longestWaiting;
        goTo(context, 'W09');
      },
      onBuildAPlan: () => goTo(context, 'W03'),
      onOpenSplits: () => goTo(context, 'K19'),
      onOpenAssessment: () {
        coachDesk.openAssessment(coachPlanClient.clientUid);
        goTo(context, 'K21');
      },
      onOpenPortfolio: () => goTo(context, 'B01'),
      onTab: (screenId) => goTo(context, screenId),
    ),
    'W02': (context) => ClientOverviewView(
      client: coachPlanClient,
      // From her assessment when one has been recorded, and **unresolved**
      // when none has — a different state from "nothing to avoid", and the one
      // W04 renders a line about instead of showing an unrestricted list.
      constraints: coachDesk.constraintsFor(coachPlanClient.clientUid),
      assessment: coachDesk.assessments[coachPlanClient.clientUid],
      now: DateTime.now(),
      onBack: () => goTo(context, 'W01'),
      onOpenChat: () => goTo(context, 'K16'),
      // The first assessment and a re-assessment are different screens, and
      // which one this row opens is decided by whether anything is on file.
      onOpenAssessment: () {
        coachDesk.openAssessment(coachPlanClient.clientUid);
        if (coachDesk.hasAssessment(coachPlanClient.clientUid)) {
          goTo(context, 'K22');
        } else {
          goTo(context, 'K21');
        }
      },
      onOpenPlan: () => goTo(context, 'W03'),
      onOpenMeals: () => goTo(context, 'W06'),
      onOpenReview: () => goTo(context, 'W09'),
      onTab: (screenId) => goTo(context, screenId),
    ),
    // Day one first: a month belongs to one woman, and a coach with nobody on
    // her roster has no month to write. The planner says so and points at
    // where a client comes from, instead of offering chips that cannot save.
    'W03': (context) => coachPlanClients.isEmpty
        ? NoClientYetView(
            title: AppL10n.of(context).plan,
            onOpenClients: () => goTo(context, 'W01'),
            onBack: () => Navigator.of(context).maybePop(),
          )
        : WorkoutPlannerView(
            draft: coachPlanDraft,
            clientName: coachPlanClient.displayName,
            weekIndex: coachPlanWeekIndex,
            onSelectWeek: (index) {
              coachPlanWeekIndex = index;
              AppChanges.bump();
            },
            onOpenDay: (dayKey) {
              coachPlanOpenDayKey = dayKey;
              goTo(context, 'W04');
            },
            onApplySplit: () => goTo(context, 'K19'),
            onAddWorkout: () {
              coachPlanOpenDayKey = null;
              goTo(context, 'W04');
            },
            onCopyWeek: () => goTo(context, 'W05'),
            onSaveAsSplit: () {
              coachDesk.openSplitForEditing(null);
              goTo(context, 'K20');
            },
            onDraftForMe: () => goTo(context, 'K26'),
            onPublish: () => goTo(context, 'W08'),
            onBack: () => goTo(context, 'W02'),
          ),
    // Every field writes the day as she types it — the same one document W03
    // reads back. **`onAddMove` is still unwired**, and deliberately: §2.10
    // says a planner selects and never generates, `AssistantPack` is empty in
    // this build, and an exercise id nothing can resolve is a prescription
    // nobody can read.
    'W04': (context) => coachPlanClients.isEmpty
        ? NoClientYetView(
            title: AppL10n.of(context).workouts,
            onOpenClients: () => goTo(context, 'W01'),
            onBack: () => Navigator.of(context).maybePop(),
          )
        : SessionEditorView(
            // The day she tapped, or today when the screen was opened by "add
            // a workout" rather than from a date.
            dayKey: coachPlanDayKey,
            workout: coachPlanDraft.dayAt(coachPlanDayKey)?.workout,
            suppressedExerciseIds: const <String>{},
            onTitleChanged: (title) => coachDesk.editSession(
              coachPlanClient.clientUid,
              coachPlanDayKey,
              title: title,
              notify: false,
            ),
            onNoteChanged: (note) => coachDesk.editSession(
              coachPlanClient.clientUid,
              coachPlanDayKey,
              note: note,
              notify: false,
            ),
            onSelectMinutes: (minutes) => coachDesk.editSession(
              coachPlanClient.clientUid,
              coachPlanDayKey,
              minutes: minutes,
            ),
            onSelectRest: (seconds) => coachDesk.editSession(
              coachPlanClient.clientUid,
              coachPlanDayKey,
              restBetweenSetsSec: seconds,
            ),
            onSave: () => goTo(context, 'W03'),
            onBack: () => goTo(context, 'W03'),
          ),
    // Computed, never stated: the summary names the days this copy would
    // replace **before** it replaces them, and it is recomputed from the ticks
    // as she makes them.
    'W05': (context) => CopyWeekView(
      summary: coachDesk.copySummary(
        coachPlanClient.clientUid,
        coachPlanWeekIndex,
      ),
      weekCount: coachDesk.weekCountFor(coachPlanClient.clientUid),
      selectedTargets: coachDesk.copyTargets,
      daysOutsideMonth: coachDesk.copyDaysOutsideMonth(
        coachPlanClient.clientUid,
        coachPlanWeekIndex,
      ),
      onToggleTarget: coachDesk.toggleCopyTarget,
      onConfirm: () {
        coachDesk.applyCopy(coachPlanClient.clientUid, coachPlanWeekIndex);
        goTo(context, 'W03');
      },
      onCancel: () => goTo(context, 'W03'),
      onBack: () => goTo(context, 'W03'),
    ),
    // The pack is resolved from the dictionary on the way through, exactly as
    // `TypeItView` and `RecipeView` resolve theirs, because G5's stand-in
    // library is built from `AppL10n` and a state holder has none.
    'W06': (context) {
      final desk = coachDesk..useFoods(eatSampleLibrary(AppL10n.of(context)));
      final uid = coachPlanClient.clientUid;
      final day = coachPlanOpenDayKey ?? dayId(DateTime.now());
      if (coachPlanClients.isEmpty) {
        return NoClientYetView(
          title: AppL10n.of(context).meals,
          onOpenClients: () => goTo(context, 'W01'),
          onBack: () => Navigator.of(context).maybePop(),
        );
      }
      return MealPlannerView(
        draft: coachPlanDraft,
        constraints: desk.constraintsFor(uid),
        dayKey: day,
        clientName: coachPlanClient.displayName,
        coachMealNames: <String, String>{
          for (final meal in desk.meals.values) meal.mealId: meal.name,
        },
        // Named, with the allergen on the card. A coach may not prescribe
        // around a woman's allergy, so the slot is refused rather than filled.
        blockedSlots: desk.blockedSlots(uid),
        onSelectDay: (selected) {
          coachPlanOpenDayKey = selected;
          AppChanges.bump();
        },
        // One tap cycles the slot through the answers that exist — nothing,
        // *her choice*, then each dish she has written. There is no picker
        // screen in this feature and none was invented.
        onOpenSlot: (slot) => desk.cycleSlot(uid, day, slot),
        onSelectAppMeal: () =>
            desk.assignAppMeal(uid, day, desk.openSlot ?? PlanMealSlot.lunch),
        onCreateMeal: () {
          desk.startNewMeal();
          goTo(context, 'W07');
        },
        onDraftAWeek: () => goTo(context, 'K27'),
        onPublish: () => goTo(context, 'W08'),
        onBack: () => goTo(context, 'W02'),
      );
    },
    // Her own dish. Its nutrition is **derived** — one ingredient the pack
    // does not know and the whole meal carries no figures, which is what
    // `CoachMeal.compose` refuses to do any other way.
    'W07': (context) {
      final desk = coachDesk..useFoods(eatSampleLibrary(AppL10n.of(context)));
      return CreateMealView(
        // Null is a new dish — the same shape `adminEditingRow` uses for
        // "adding".
        meal: desk.editingMeal,
        onNameChanged: (value) => desk.mealName = value,
        onIngredientsChanged: (value) => desk.mealIngredients = value,
        onServingsChanged: (value) =>
            desk.mealServings = int.tryParse(value.trim()) ?? 1,
        onPrepMinutesChanged: (value) =>
            desk.mealPrepMinutes = int.tryParse(value.trim()),
        onNoteChanged: (value) => desk.mealNote = value,
        onSave: () {
          desk.saveMealFromFields(coachPlanClient.clientUid);
          goTo(context, 'W06');
        },
        onClose: () => Navigator.of(context).maybePop(),
      );
    },
    // Publish. The one act that changes a plan, and the only screen that
    // performs it.
    'W08': (context) => plan.PublishView(
      draft: coachPlanDraft,
      publishContext: coachDesk.publishContextFor(coachPlanClient.clientUid),
      hasAssessment: coachDesk.hasAssessment(coachPlanClient.clientUid),
      unreadableMealIds: coachDesk.unreadableMealIds(coachPlanClient.clientUid),
      outcome: coachDesk.lastPublish,
      onOpenAssessment: () {
        coachDesk.openAssessment(coachPlanClient.clientUid);
        goTo(context, 'K21');
      },
      onPreviewDay: () => goTo(context, 'G04'),
      onFillGaps: () => goTo(context, 'W06'),
      // The button's label varies with signal and its enablement cannot. What
      // lands is a version, an effective date and a document the client reads
      // — which is why `G04` shows her coach's own words afterwards.
      onPublish: () {
        coachDesk.publishPlan(coachPlanClient.clientUid);
      },
      onBack: () => goTo(context, 'W03'),
    ),
    // Her week from her logs, and the answer in the coach's own words. Saving
    // feedback publishes nothing — the domain cannot, and neither can this.
    'W09': (context) => ReviewView(
      summary: coachDesk.summaryFor(coachPlanClient.clientUid),
      actions: ReviewScreenActions.forDraft(
        draftIsDirty: coachDesk.draftIsDirty(coachPlanClient.clientUid),
      ),
      clientName: coachPlanClient.displayName,
      clientWords: coachDesk
          .reviewFor(coachDesk.relIdFor(coachPlanClient.clientUid))
          ?.worked,
      reply: coachDesk.replyDraft,
      onReplyChanged: (text) => coachDesk.replyDraft = text,
      onSaveFeedback: () {
        coachDesk.saveFeedback(
          coachDesk.relIdFor(coachPlanClient.clientUid),
          coachDesk.replyDraft,
        );
        goTo(context, 'K07');
      },
      onOpenPublish: () => goTo(context, 'W08'),
      onAdjustWorkouts: () => goTo(context, 'W03'),
      onAdjustMeals: () => goTo(context, 'W06'),
      onBack: () => goTo(context, 'K07'),
    ),
    'W10': (context) => CoachInboxView(
      clients: coachPlanClients,
      onOpenThread: (client) {
        coachPlanOpenClient = client;
        goTo(context, 'K16');
      },
      onTab: (screenId) => goTo(context, screenId),
    ),
    'K19': (context) => SplitsView(
      splits: coachPlanSplits,
      onOpenSplit: (split) {
        coachDesk.openSplitForEditing(split);
        goTo(context, 'K20');
      },
      onBuildSplit: () {
        coachDesk.openSplitForEditing(null);
        goTo(context, 'K20');
      },
      onBack: () => goTo(context, 'W01'),
      onTab: (screenId) => goTo(context, screenId),
    ),
    'K20': (context) => SplitBuilderView(
      split: coachPlanSplit,
      // Refused with its reasons on the rows rather than at the button: a
      // session needs a name, and a cycle needs a slot for every day in it.
      problems: coachDesk.splitProblems,
      onNameChanged: coachDesk.setSplitName,
      onSelectCycleLength: coachDesk.setSplitCycleLength,
      // One tap turns a rest day into a training day named after the split,
      // and back. The name is hers; nothing here writes a session title.
      onOpenSlot: coachDesk.toggleSplitSlot,
      onToggleCarryApproved: coachDesk.setSplitCarryApproved,
      onSave: () {
        coachDesk.saveSplit();
        goTo(context, 'K19');
      },
      // Materialises into one client's draft, by value. Publishes nothing —
      // which is why it lands on the planner and not on W08.
      onSaveAndApply: () {
        if (coachDesk.saveSplit()) {
          coachDesk.applySplit(coachPlanSplit, coachPlanClient.clientUid);
        }
        goTo(context, 'W03');
      },
      onClose: () => Navigator.of(context).maybePop(),
    ),
    'K21': (context) => AssessmentHealthView(
      form: coachAssessmentForm,
      onSelectLifeStage: coachDesk.setLifeStage,
      onSelectBirthType: coachDesk.setBirthType,
      onClearanceChanged: coachDesk.setClearance,
      onToggleAvoidTag: coachDesk.toggleAvoidTag,
      onPainNotesChanged: coachDesk.setPainNotes,
      onContinue: () => goTo(context, 'K23'),
      onClose: () => Navigator.of(context).maybePop(),
    ),
    // `onSave` writes the whole assessment — both steps, one document. A
    // half-saved assessment is a half-stated constraint, so there is no path
    // here that records one step.
    'K23': (context) => MovementScreeningView(
      form: coachAssessmentForm,
      onSetOutcome: (screeningId, outcome) => coachDesk.editForm(
        coachAssessmentForm.withOutcome(screeningId, outcome),
      ),
      onSave: () {
        coachDesk.saveAssessment();
        goTo(context, 'W02');
      },
      onSaveOnly: () {
        coachDesk.saveAssessment();
        goTo(context, 'W01');
      },
      onBack: () => goTo(context, 'K21'),
    ),
    // The re-assessment. It exists because there is a previous record to hang
    // it off: `AssessmentForm.from` pre-fills it and nothing is overwritten
    // until she saves, and an uncleared referral comes **forward** rather than
    // being dropped by the newer document's silence.
    'K22': (context) {
      final previous = coachDesk.assessments[coachPlanClient.clientUid];
      // A re-assessment with no first assessment is not a screen with empty
      // fields; it is a claim that there was one. Opened cold — from the
      // screen index, or for a client nobody has screened — this **is** the
      // first assessment, and says so by being K21's screen.
      if (previous == null) {
        return AssessmentHealthView(
          form: coachAssessmentForm,
          onSelectLifeStage: coachDesk.setLifeStage,
          onSelectBirthType: coachDesk.setBirthType,
          onClearanceChanged: coachDesk.setClearance,
          onToggleAvoidTag: coachDesk.toggleAvoidTag,
          onPainNotesChanged: coachDesk.setPainNotes,
          onContinue: () => goTo(context, 'K23'),
          onClose: () => Navigator.of(context).maybePop(),
        );
      }
      return ReassessmentView(
        previous: previous,
        form: coachAssessmentForm,
        activeReferrals: coachDesk.activeReferralsFor(
          coachPlanClient.clientUid,
        ),
        onSaveAndAdjust: () {
          coachDesk.saveAssessment();
          goTo(context, 'W03');
        },
        onSaveOnly: () {
          coachDesk.saveAssessment();
          goTo(context, 'W02');
        },
        onOpenHistory: () => goTo(context, 'W02'),
        onBack: () => goTo(context, 'W02'),
      );
    },

    // ----------------------------------------- Her portfolio (G13, B-flow)
    //
    // `B01` was wired alone for a release because it was the only B screen with
    // a widget. The rest have them now, so the builder, its four bespoke block
    // editors, the preview, the publish diff, the ad designer and her media
    // library are all reachable from her desk.
    //
    // **B12 is wired and draws no figures.** `portfolio_insights.dart` is its
    // domain and its first line is "B12, and the reason it renders nothing":
    // there is no storage and no beacon, so every number on it would be a
    // statement about our telemetry rather than about her page. The screen
    // says that, which is better than a row on B01 that opens nothing.
    //
    // **B14 is deliberately absent**, for the same reason M17, K24 and W11 are:
    // it is `PortfolioHomeState.isDayOne`, a getter on the state B01 already
    // passes, and `P0-PORT-01` requires that no `/coachbrand/b14` destination is
    // ever navigated to.
    //
    // `PortfolioView` has no entry here either, and never will: it is the block
    // **renderer** both B10 and H02 draw with — a `Column`, not a screen.
    'B02': (context) => PortfolioCanvasView(
      model: portfolio.canvas,
      onBack: () => goTo(context, 'B01'),
      onPreview: () => goTo(context, 'B10'),
      onPublish: () => goTo(context, 'B11'),
      onAddSection: () => goTo(context, 'B03'),
      onLook: () => goTo(context, 'B05'),
      onMedia: () => goTo(context, 'B13'),
      // The save. Without it the canvas would hold her blocks and B01 would
      // still render its day-one branch, one tap apart, for the same page —
      // and it goes through the repository, which refuses a stale revision
      // exactly as the security rule does.
      onChanged: portfolio.saveDraft,
      // Which editor a row opens is the block's own type. `BlockRegistry`
      // already carries `editorScreenId` and reading it here would compile,
      // work, and hide B04, B06, B07 and B08 from the reachability parser —
      // the bug this file has already recorded for Y08, Y10 and Z03. One
      // literal per arm instead.
      onEditBlock: (block) {
        portfolio.editing = block;
        switch (block.type) {
          case BlockType.cover:
            goTo(context, 'B04');
          case BlockType.offers:
            goTo(context, 'B06');
          case BlockType.method:
            goTo(context, 'B07');
          case BlockType.results:
            goTo(context, 'B08');
          // The other ten types are edited by the generic editor, which is not
          // among the designed screens and is not built. Nothing opens, rather
          // than a row that looks as though it leads somewhere.
          default:
            break;
        }
      },
    ),
    'B03': (context) => AddSectionView(
      // Every type not currently capped out, asked of the page itself so the
      // cap stays in the domain.
      addableTypes: portfolio.canvas.draft.addableTypes,
      onAdd: (type) {
        portfolio.addSection(type);
        Navigator.of(context).maybePop();
      },
      onBack: () => goTo(context, 'B02'),
    ),
    // Each editor writes as she types and redraws the rest of the app when she
    // leaves: the screens hold their own state and read the payload once, so
    // redrawing on every keystroke would buy nothing. Closing saves too —
    // there is no discard on these screens, and silently dropping what she
    // typed is not what an X means here.
    'B04': (context) => CoverEditorView(
      payload: portfolio.payloadFor<CoverPayload>(BlockType.cover),
      // `overlayFloor` is null on purpose: nothing has decoded a photo, and the
      // slider is left unclamped rather than clamped to a guess.
      onChanged: portfolio.replacePayload,
      onChangePhoto: () => goTo(context, 'B13'),
      onDone: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
      onClose: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
    ),
    'B05': (context) => LookView(
      theme: portfolio.canvas.draft.theme,
      onThemeChanged: portfolio.setTheme,
      onPreview: () {
        portfolio.doneEditing();
        goTo(context, 'B10');
      },
      onDone: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
      onBack: () {
        portfolio.doneEditing();
        goTo(context, 'B02');
      },
    ),
    'B06': (context) => OffersBlockView(
      payload: portfolio.payloadFor<OffersPayload>(BlockType.offers),
      // K04's offers, through the read-only port. This screen switches ids on
      // and off; it could not write an offer if it tried.
      offers: portfolio.offerSummaries,
      onChanged: portfolio.replacePayload,
      onAuthorOffers: () => goTo(context, 'K04'),
      onDone: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
      onClose: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
    ),
    'B07': (context) => MethodEditorView(
      payload: portfolio.payloadFor<MethodPayload>(BlockType.method),
      onChanged: portfolio.replacePayload,
      onDone: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
      onClose: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
    ),
    'B08': (context) => ResultsView(
      // Her clients' own documents. Empty because consent is theirs to give and
      // nobody has — `onAskAnotherClient` produces a `ResultRequest` and there
      // is nothing here to write one, which is left visible rather than faked.
      results: const [],
      now: DateTime.now(),
      payload: portfolio.openResultsPayload,
      onChanged: portfolio.replacePayload,
      onDone: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
      onClose: () {
        portfolio.doneEditing();
        Navigator.of(context).maybePop();
      },
    ),
    'B09': (context) => AdDesignerView(
      ad: portfolio.ad,
      // Her look. All three sizes inherit it — the creative is composed from
      // data, never a stored bitmap.
      theme: portfolio.canvas.draft.theme,
      now: DateTime.now(),
      onFormat: portfolio.setAdFormat,
      onChangePhoto: () => goTo(context, 'B13'),
      // Export writes a file, and nothing in this build can. Said plainly
      // rather than drawn as a button that appears to have saved something —
      // a creative that has left the app is the one thing consent cannot
      // reach back into.
      onExport: () => showHonestNotice(
        context,
        AppL10n.of(context).savingAnImageToYourPhoneIs,
      ),
      onBack: () => goTo(context, 'B01'),
    ),
    'B10': (context) => PreviewView(
      // The same widget and the same document H02 renders, resolved at read
      // time. Hidden blocks are absent from both, because both call this.
      portfolio: portfolio.resolve(
        page: portfolio.canvas.draft,
        now: DateTime.now(),
      ),
      onBackToEditing: () => goTo(context, 'B02'),
      onPublish: () => goTo(context, 'B11'),
    ),
    'B11': (context) => PublishView(
      // Derived, never stored: the live page against the draft.
      diff: portfolio.diff,
      refusals: portfolio.refusals,
      retainedVersions: portfolio.retainedVersions,
      // The publisher decides, with every reason at once, and only a queued
      // intent reaches the write. A refusal leaves her here with the list.
      onPublish: () {
        if (portfolio.publish() is PublishQueued) goTo(context, 'B01');
      },
      onRestore: portfolio.restore,
      onKeepDraft: () => goTo(context, 'B02'),
      onClose: () => Navigator.of(context).maybePop(),
    ),
    // B12 is wired, and it draws no figures. `kPortfolioInsightsEnabled` is
    // false because there is no ratified storage and no beacon, so the screen
    // states that nothing is being counted. "0 views · 0 enquiries" would be a
    // claim about her page made out of our own missing telemetry.
    'B12': (context) => InsightsView(
      isPublished: portfolio.live != null,
      onBack: () => goTo(context, 'B01'),
    ),
    'B13': (context) => MediaView(
      // One page of her media. Empty, and adding says why: `pubspec.yaml`
      // carries no picker, which is the same honest refusal
      // `UnavailableMediaPicker` gives the content console.
      items: const [],
      now: DateTime.now(),
      filter: portfolio.mediaFilter,
      onFilter: portfolio.setMediaFilter,
      onAdd: () => showHonestNotice(
        context,
        AppL10n.of(context).thereIsNoPhotoPickerInThis,
      ),
      onDone: () => Navigator.of(context).maybePop(),
      onBack: () => goTo(context, 'B02'),
    ),

    // ------------------------------------------- Community, the last three
    //
    // M09, M13 and M16 had view models and no widgets, so they were written as
    // literals above and rendered `NotBuiltYet`. They have widgets now.
    //
    // Reels is reached from the **reels tab of a profile** — M07's three tabs
    // are photos, reels and follow-ups, and which one is open decides what a
    // tile is. That is the design's door (`screens-community.mjs` puts `M09`
    // behind the `videocam` tab and behind every tile with a clip on it), and
    // it is the only one: the feed has no reel rail.
    'M09': (context) => ReelsView(
      model: communityReelsModel,
      posts: communityReelCards,
      onBack: () => Navigator.of(context).maybePop(),
      onRecord: () => goTo(context, 'M16'),
      onOpenProfile: (uid) {
        communityOpenProfileUid = uid;
        goTo(context, 'M07');
      },
      onOpenComments: (postId) {
        communityOpenPostId = postId;
        goTo(context, 'M02');
      },
      onLike: CommunityState.instance.toggleLike,
      onSave: CommunityState.instance.toggleSave,
      onMore: (postId) {
        communityOpenPostId = postId;
        communitySafetySubject = communityAuthorName(postId);
        communitySafetyUid = communityAuthorUid(postId);
        communitySafetyInGroup = false;
        CommunityState.instance.safetyPostId = postId;
        goTo(context, 'M08');
      },
      onSelectTab: (screenId) => goTo(context, screenId),
    ),
    'M13': (context) => StoryViewerView(
      model: communityStoryModel,
      onClose: () => Navigator.of(context).maybePop(),
      onOpenProfile: (uid) {
        communityOpenProfileUid = uid;
        goTo(context, 'M07');
      },
      onLike: () => communityOpenPostId == null
          ? null
          : CommunityState.instance.toggleLike(communityOpenPostId!),
      onMore: () {
        communitySafetySubject = communityAuthorName(communityOpenPostId);
        communitySafetyUid = communityAuthorUid(communityOpenPostId);
        communitySafetyInGroup = false;
        CommunityState.instance.safetyPostId = communityOpenPostId;
        goTo(context, 'M08');
      },
    ),
    'M16': (context) => RecordView(
      // The camera rail, blur already on. **There is no camera and no publish
      // pipeline**, so the shutter and the confirm are unwired — the controls
      // are visibly inert rather than quietly doing nothing with her footage.
      model: communityRecordModel,
      selectedMode: CommunityState.instance.recordMode,
      onSelectMode: (mode) {
        CommunityState.instance.recordMode = mode;
        AppChanges.bump();
      },
      onClose: () => Navigator.of(context).maybePop(),
      // No camera plugin is in `pubspec.yaml`, so there is nothing behind the
      // shutter. It says so and points at the half of the launch scope that
      // does work, rather than doing nothing at all.
      onCapture: () => showHonestNotice(
        context,
        AppL10n.of(context).thereIsNoCameraInThisBuild,
      ),
      onConfirm: () => showHonestNotice(
        context,
        AppL10n.of(context).thereIsNoCameraInThisBuild,
      ),
      onOpenGallery: () => showHonestNotice(
        context,
        AppL10n.of(context).thereIsNoCameraInThisBuild,
      ),
    ),

    // ------------------------------------------- Her public profile (K18)
    //
    // It was built, tested, and opened by nothing: the prototype's only door
    // was a row on `K17`, and `coach_earnings_view.dart` deliberately points
    // that row at `K05` instead, because a payout method has nothing to do with
    // a public profile. That decision stands. The door added instead is on
    // `K07`, her desk, beside the notifications bell and on both of its
    // branches — labelled `yourPublicProfile`, which is the same dictionary
    // string the screen titles itself with.
    'K18': (context) => CoachPublicProfileView(
      model: CoachPublicProfileViewModel.from(
        profile: coachRepository.profileUnbilled,
        // Read-only by type: `K04` is the single writer of an offer and this
        // screen is handed an `OfferReader`, so it has no method that could
        // change one.
        offers: coachRepository,
        // The certificates she actually entered on `K02`.
        // `CoachRepository.certificates()` is a `Future` and a route builder is
        // synchronous; the setup model holds the same list synchronously, for
        // the same reason `periodRepository.store` is read directly.
        certificates: coachSetupModel.certificates,
        now: DateTime.now(),
      ),
      // No badge is drawn above, because `CertificateStanding` holds nothing
      // cleared. This says why: she counts as checked while sign-up is off,
      // and nobody has read her certificates.
      note: CoachProfileState.instance.isTestCoach
          ? AppL10n.of(context).whileSignUpIsSwitchedOffYou
          : null,
      onBack: () => goTo(context, 'K07'),
      onPreviewAsClient: () => goTo(context, 'B10'),
      onEditBasics: () => goTo(context, 'K01'),
      onDesignPage: () => goTo(context, 'B02'),
      onOpenPackages: () => goTo(context, 'K04'),
    ),

    // ------------------------------------------ The switchboard (D25, Z14)
    //
    // The only place in the product where a feature is switched on or off.
    // Until it existed, `featureFlags` could only be changed by editing this
    // file, so every Phase 3 flow shipped dark with no way to see one.
    'Z14': (context) => FeatureFlagsView(onBack: () => goTo(context, 'Z01')),
  };

  static MoveAlternative? lastSwappedFor;

  /// Carries the undoable log to the screen that offers the undo.
  ///
  /// Passed as a route **argument**, not held in a static field. An earlier
  /// version kept it in `_pendingHandle` and claimed it was "cleared as soon as
  /// it is handed on" — it was not; it cleared on *pop*. So walking
  /// R09 → R07 → R08 → R09 left the first handle in place, and R09 rendered a
  /// live Undo button for a set whose window had long expired, which silently
  /// did nothing when tapped. QA found it; no test touched this path.
  ///
  /// A route argument cannot go stale: it belongs to that one push.
  static void _goCarryingHandle(
    BuildContext context,
    String screenId,
    LogHandle handle,
  ) {
    final route = appDestinations[screenId];
    if (route == null) return;
    Navigator.of(context).pushNamed(route.name, arguments: handle);
  }

  /// The handle for the route currently being built, if it was pushed with one.
  static LogHandle? handleFrom(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is LogHandle ? args : null;
  }

  /// Ends the session. The caller navigates, so the route it goes to stays
  /// visible in the builder above — `nav_reachability_test` reads those
  /// literals, and a `goTo` hidden in here makes R10 look like dead code.
  ///
  /// The credit itself is idempotent by session id — in the week document, in
  /// the award ledger and in Today's copy — so finishing twice, or a tap that
  /// arrives late, counts once.
  static void _finishWorkout() {
    unawaited(
      WorkoutSessionState.instance.finish(
        repository: trainRepository,
        today: todayRepository,
        progress: progressStore,
      ),
    );
  }

  /// How far she is into her level, as a percentage of the points it takes.
  static double get _levelProgressPercent {
    const curve = LevelCurve();
    final remaining = curve.pointsToNextLevel(progressStore.rewards.points);
    final span = curve.pointsPerLevel;
    if (span <= 0) return 0;
    return ((span - remaining) / span * 100).clamp(0, 100).toDouble();
  }

  /// Shared, in-memory stand-ins for the data layer, until there is a Firebase
  /// project to point at.
  ///
  /// **Deliberately single instances.** Constructing a repository inside each
  /// route builder would give every screen its own empty copy, so her goal from
  /// `O01` would be gone by `O05` and the summary would describe nobody. The bug
  /// would look like a screen fault and actually be a wiring fault, which is the
  /// expensive kind to chase.
  /// Which parts of the product are switched on.
  ///
  /// Read by screens and by the navigation, never by domain code -- a domain
  /// rule that changes with a flag is a rule nobody can reason about. Phase 1
  /// and 2 are on; every Phase 3 feature ships dark until it is proven, which
  /// is why a half-built flow can be merged without reaching a woman.
  ///
  /// Compiled-in today. A remote config document later merges over these with
  /// [FeatureFlags.with_]; the specs already name the keys.
  static FeatureFlags featureFlags = FeatureFlags.shipped;

  static final LocalePreference localePreference = InMemoryLocalePreference();
  static final AuthRepository authRepository = FakeAuthRepository();
  static final VerificationRepository verificationRepository =
      FakeVerificationRepository();
  static final CaptureService captureService =
      const UnavailableCaptureService();
  static final IntakeRepository intakeRepository = InMemoryIntakeRepository();
  static final InMemoryTodayRepository todayRepository =
      InMemoryTodayRepository();

  /// The Cloud Function's job, done in memory: a set is flushed, detection
  /// runs, and her bests and her lifetime count are updated.
  ///
  /// [progressStore.bests] is passed **by reference**, so P03 reads the very
  /// map the ledger writes. Handing over a copy is how a screen and a detector
  /// end up holding two different ideas of her best.
  ///
  /// Without this wiring `bestsCount` never moves, and three of the five tiers
  /// in [TierLadder.shipped] are unreachable no matter how long she trains.
  static final PersonalBestLedger personalBestLedger = PersonalBestLedger(
    bests: progressStore.bests,
    bestsCount: progressStore.rewards.bestsCount,
  );

  static final SessionBestsBridge sessionBests = SessionBestsBridge(
    ledger: personalBestLedger,
  );

  static final InMemoryTrainRepository trainRepository =
      InMemoryTrainRepository(
        onFlushed: ({session, required exerciseId, required sets}) {
          sessionBests.record(
            session: session,
            exerciseId: exerciseId,
            sets: sets,
          );
          progressStore.rewards = progressStore.rewards.copyWith(
            bestsCount: personalBestLedger.bestsCount,
          );
        },
      );

  // ------------------------------------------------------------- Phase 2
  //
  // One instance each, for the reason given above: a screen that builds its own
  // repository shows an empty copy of her data, and the bug looks like a screen
  // fault while actually being a wiring fault.

  /// The uid these stand in for until there is a real session store.
  static const String _selfUid = 'me';

  /// G7. Her allergy and dietary answers — the input `eatConstraints` reads.
  static final DietaryProfileRepository dietaryRepository =
      InMemoryDietaryProfileRepository();

  static final PrivacyRepository privacyRepository =
      InMemoryPrivacyRepository();
  static final PrivacySettingsService privacyService = PrivacySettingsService(
    privacyRepository,
  );

  static final BlockService blockService = InMemoryBlockService(
    selfUid: _selfUid,
  );
  static final ReportService reportService = InMemoryReportService(
    reporterUid: _selfUid,
  );
  static final NotificationsRepository notificationsRepository =
      InMemoryNotificationsRepository();

  /// G6. **One store behind all three progress repositories.**
  ///
  /// Separate stores would hand P01 her weeks and P03 an empty list of bests,
  /// for the same woman, on two screens one tap apart.
  static final ProgressStore progressStore = ProgressStore();
  static final WeeksRepository weeksRepository = InMemoryWeeksRepository(
    store: progressStore,
  );
  static final BestsRepository bestsRepository = InMemoryBestsRepository(
    store: progressStore,
  );
  static final MeasurementsRepository measurementsRepository =
      InMemoryMeasurementsRepository(store: progressStore);

  /// G9. `periodRepository` shares the cycle store deliberately, so a period
  /// logged on Y09 is already there when Y03 and Y08 render.
  static final InMemoryCycleRepository cycleRepository =
      InMemoryCycleRepository();

  /// Declared as the concrete type so `store` is reachable.
  ///
  /// Every method on `PeriodRepository` returns a `Future`, and route builders
  /// are synchronous. Rather than wrap four screens in a `FutureBuilder` for an
  /// in-memory map, the builders read `store.periods` directly — the same thing
  /// P03 does with `progressStore.bests`. When a real Firestore repository
  /// lands this becomes a stream or a future and the builders change with it.
  static final InMemoryPeriodRepository periodRepository =
      InMemoryPeriodRepository(cycles: cycleRepository);

  /// What she logged on Y04 today.
  ///
  /// **Session-scoped and deliberately not persisted**, in the same spirit as
  /// `lastSignupRole` and `lastVerification` above. The real home for this is
  /// G3's `users/{uid}/checkins/{yyyy-MM-dd}` document — and My cycle must not
  /// write it (G9 OQ-3), because the check-in belongs to Today, not to Cycle.
  /// Holding it here connects Y04 to Y03 without either feature reaching into
  /// the other's collection.
  ///
  /// Until this existed, **`CheckInView.onSaved` was wired to nothing**: she
  /// could log heavy bleeding and the sheet would close having told no one, so
  /// the severe branch was reachable in tests and unreachable in the app.
  static TodayCheckIn todayCheckIn = TodayCheckIn.absent;

  /// `yyyy-MM-dd` for [now], the key both `checkins` and `periods` are keyed by.
  static String dayId(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  /// Her periods, newest first. Synchronous — see [periodRepository].
  static List<PeriodEntry> get periodsSoFar =>
      periodRepository.store.periods.values.toList()
        ..sort((a, b) => b.start.compareTo(a.start));

  // ------------------------------------------------- D12, the admin console
  //
  // Staff state, carried across Z08 → Z09 the way `mealRepository` is carried
  // across the Eat screens. **Nothing here is a member's data**, and a guard in
  // the admin tests fails the build if anything under `lib/features/admin/`
  // ever references `users/`, a cycle, a check-in, a measurement or a log.

  static ContentCollection adminImportCollection = ContentCollection.foods;

  /// The row Z03/Z05 opens on. Empty means "adding", which is D12's case.
  ///
  /// One CSV row of the content library — never a member's data. A guard in the
  /// admin tests fails the build if anything under `lib/features/admin/` so
  /// much as mentions `users/`, a cycle, a check-in or a log.
  static Map<String, String> adminEditingRow = const <String, String>{};

  /// The values of one stored row, for the form to open as an edit.
  ///
  /// Returns empty when the id is not there, which opens the form as an **add**
  /// rather than throwing — a row can be deleted by an import between the list
  /// being built and a tap landing on it.
  static Map<String, String> adminRowValues(
    ContentCollection collection,
    String id,
  ) {
    for (final row in contentRepository.rowsNow(collection)) {
      if (row.id == id) return row.values;
    }
    return const <String, String>{};
  }

  static MediaBundle adminMediaBundle = const MediaBundle([]);

  /// **Where the content library actually lives.**
  ///
  /// Until this existed, the console could be opened, filled in and saved, and
  /// nothing was stored: the form emitted a row that was discarded and the
  /// import commit wrote nothing. Both writers now land here, through the same
  /// document id — which is the id column, never a minted one — so a food added
  /// by hand and the same food imported from a CSV are one document and not two.
  ///
  /// In memory, so it does not survive a restart and reaches no other device. A
  /// Firestore implementation goes behind the same interface.
  static final InMemoryContentRepository contentRepository =
      InMemoryContentRepository(rows: seedContentLibrary());

  /// Choosing a file and uploading media are **honestly unavailable**.
  ///
  /// `pubspec.yaml` carries no picker, so neither can work in this build. The
  /// seams exist and refuse, in the same shape `UnavailableCaptureService` uses
  /// for ID capture — so the buttons render visibly disabled rather than
  /// silently doing nothing, and a real picker drops in without touching a
  /// screen.
  static const MediaPicker mediaPicker = UnavailableMediaPicker();
  static const TextSource csvSource = UnavailableTextSource();

  /// The CSV she chose at Z08, once choosing is possible.
  static String? adminChosenFileName;

  /// Z01's counts, read from the library rather than held beside it.
  ///
  /// This was a `const {}` field, so Z01 reported nothing about any collection
  /// however much had been imported.
  static Map<ContentCollection, CollectionStatus> get adminLibraryStatus =>
      contentRepository.statusNow();

  /// The dry run Z09 renders. Null until a file has actually been checked.
  static ImportPlan? adminImportPlan;

  /// Z09's plan, or an honest stand-in when no file has been chosen.
  ///
  /// An empty table is not a blank slate: `validateImport` returns a plan
  /// carrying one `noHeader` problem, so `canCommit` is false and `writes` is
  /// empty **by construction**. Reaching Z09 without a file therefore reports a
  /// problem with the file rather than an import that is ready to run — which
  /// is the one thing this screen must never say wrongly, because the whole
  /// design of the import is that a single bad row writes nothing at all.
  static ImportPlan get adminPlanOrEmpty =>
      adminImportPlan ??
      validateImport(
        collection: adminImportCollection,
        table: parseCsv(''),
        uploadedMedia: const <String>{},
        existingIds: const <String>{},
      );

  /// P01's view model, assembled from the one progress store.
  ///
  /// `TierLadder.unauthored` is the deliberate value, not a placeholder:
  /// `DECISIONS.md` D6 records that no tier ladder is authoritative yet, so P01
  /// renders no tier at all rather than three invented ones. The moment a
  /// ladder is authored, this is where it arrives.
  static ProgressSummary get progressSummary => ProgressSummary.from(
    goal: progressStore.goal,
    rewards: progressStore.rewards,
    // This week's own document, so P01 counts the sessions she actually
    // logged. Without it P01 said "0 of 3" to a woman whose Home said 1.
    currentWeek: progressStore.weeks[WeekKey.of(DateTime.now()).id],
    // The same catalogue P02 renders, so P01's tile and P02's list cannot
    // disagree about how many milestones exist — the failure that put "Level 7"
    // on Home while Progress showed no tier at all.
    milestoneCount: authoredMilestones.count,
  );

  /// Seeded with this week's plan, so E07 and E08 have something to draw.
  static final MealRepository mealRepository = InMemoryMealRepository(
    plans: {
      WeekKey.of(DateTime.now()).id: sampleMealPlan(
        WeekKey.of(DateTime.now()).id,
      ),
    },
  );

  /// **The one place the product states what it knows about her allergies.**
  ///
  /// `AllergyGuard` is built, correct and tested, and it fails closed on three
  /// different unknowns (see `allergy_guard.dart`). What it has nothing to read
  /// is the two inputs it needs, and both are content obligations rather than
  /// engineering ones:
  ///
  ///   * **No screen captures `profile.allergies`.** `DECISIONS.md` D3 says
  ///     they are collected at sign-up and editable in My Profile; nothing
  ///     implements it. G5 §9 Q10b and G7 Q18 both defer the home to the owner,
  ///     and `RECONCILIATION.md` §4.2 nominates A02.
  ///   * **`foods.allergens[]` is unauthored**, so every dish in the pack
  ///     reports its allergens as unknown.
  ///
  /// That leaves two possible values here and both are wrong in a different
  /// way. `DietaryConstraints.unknown` is the honest description of what we
  /// know — and because §5.1 requires an acknowledgement sheet before any log
  /// under unknown constraints, and **that sheet's three strings are absent
  /// from the dictionary**, it would make the Eat tab unable to log anything at
  /// all. `DietaryConstraints.none` says she was asked and named nothing, which
  /// is not true of anyone yet, but keeps the product working and causes the app
  /// to make no allergy claim anywhere on screen.
  ///
  /// `none` is chosen so the feature functions, and it is recorded here — in one
  /// place, in writing — rather than defaulted invisibly inside eight screens.
  /// **This needs the owner's ratification.**
  ///
  /// ## The capture surface now exists, so this reads it
  ///
  /// `A02` hosts the allergy row and writes [dietaryRepository] — the one thing
  /// the paragraphs above say is missing. So the moment she answers, her answer
  /// is what the Eat screens screen and guard against, and `AllergyGuard`'s
  /// fail-closed behaviour is live with no other change.
  ///
  /// **Until she answers, `none` stands**, for the reason recorded above and for
  /// one more: `DietaryProfile.unasked` maps to `DietaryConstraints.unknown`,
  /// which refuses **every** log in the tab (§5.1 case 3), and the sheet that
  /// would let her past it needs an allergen to name — which no dish in the pack
  /// has. Defaulting to `unknown` would ship an Eat tab that cannot log
  /// anything, for everyone, on day one.
  ///
  /// Note what she gets if she *does* name an allergy: `foods.allergens[]` is
  /// unauthored, so every dish reads as "unknown, therefore unsafe", the
  /// suggestions screen to nothing and every log is refused. The screens say so
  /// out loud (`weCannotCheckTheseDishesForWhat`,
  /// `nobodyHasListedWhatIsInDish`) rather than failing silently. That is the
  /// honest behaviour of a guard with no content behind it, and it is the
  /// clearest possible argument for authoring the allergen data.
  static DietaryConstraints get eatConstraints {
    final profile = dietaryRepository.read();
    return profile.asked ? profile.toConstraints() : DietaryConstraints.none;
  }

  /// Choices made during sign-up that later screens need.
  ///
  /// Held here only until there is a real session store. They are recorded
  /// rather than discarded because each one changes what happens next: the role
  /// decides where `C13` sends her, and the reviewer path has a real
  /// operational cost difference between a video call and a partner gym.
  static SignupRole? lastSignupRole;

  /// The result C12 received, so C13 can state a duration it actually measured.
  static VerificationResult? lastVerification;
  static ReviewerPath? lastReviewerPath;

  // ------------------------------------------------------------- Phase 3
  //
  // One store per feature, for the reason recorded above: a screen that builds
  // its own repository shows an empty copy of her data, and the bug looks like
  // a screen fault while being a wiring fault.
  //
  // **Nothing here is seeded.** `mealRepository` carries a sample week because
  // a content pack was authored for it; there is no authored community pack,
  // no coach and no coaching relationship, so seeding one would put the
  // prototype's Hala Mansour and her 146-session group on screen as facts
  // about the woman holding the phone — the defect `baked_in_samples_test`
  // exists to count. Every Phase 3 screen therefore opens on its own empty
  // state, which is the truthful rendering of what this build knows.

  /// G10. The community documents every M screen reads.
  static final CommunityStore communityStore = CommunityStore(
    selfUid: _selfUid,
  );

  /// Which row she tapped, recorded inline at the tap.
  ///
  /// `goTo` pushes a route **name** and nothing else, so an id cannot ride
  /// along as an argument the way a `LogHandle` does. These are the community
  /// equivalents of `adminEditingRow`: written at the call site, read by the
  /// builder on the other side, and never anything but an id.
  static String? communityOpenPostId;
  static String? communityOpenGroupId;
  static String communityOpenProfileUid = _selfUid;
  static String? communityFollowUpParentId;
  static CommunityTopic? communityTopic;
  static int communitySavedFilter = 0;
  static int communityProfileTab = 0;

  /// Who `M08` is about, and whether the subject is a group.
  static String communitySafetySubject = '';
  static String communitySafetyUid = '';
  static bool communitySafetyInGroup = false;

  static CommunityPost? _communityPost(String? postId) {
    if (postId == null) return null;
    for (final post in communityStore.posts) {
      if (post.postId == postId) return post;
    }
    return null;
  }

  static CommunityGroup? _communityGroup(String? groupId) {
    if (groupId == null) return null;
    for (final group in communityStore.groups) {
      if (group.groupId == groupId) return group;
    }
    return null;
  }

  /// The author of a post, for the safety sheet's subject line. Empty when the
  /// post is not there, which renders the sheet's own unnamed subject rather
  /// than throwing on a post an import or a deletion removed under her.
  static String communityAuthorName(String? postId) =>
      _communityPost(postId)?.authorCard.name ?? '';

  static String communityAuthorUid(String? postId) =>
      _communityPost(postId)?.authorUid ?? '';

  static String get communityGroupName =>
      _communityGroup(communityOpenGroupId)?.name ?? '';

  /// Which of her three profile tabs is open, so `M07` knows whether a tile is
  /// a post or a follow-up thread.
  static ProfileTab get communityProfileTabKind =>
      CommunityState.instance.tabAt(communityProfileTab);

  /// `M01`. Built by [CommunityState], which is also what seeds the curated
  /// groups — so the day-one branch has rooms to offer and the feed shows what
  /// she wrote, filtered exactly as the repository's `feed()` filters it.
  static FeedScreenModel communityFeedModel(AppL10n l10n) =>
      CommunityState.instance.feedModel(l10n);

  /// Opens the text composer over whatever screen she is on, then publishes
  /// what she wrote and offers the same five-second undo every other log does.
  ///
  /// `CommunityState.composeGroupId` pre-selects a room, so "post" reached
  /// from inside a group posts into that group.
  static Future<void> communityWritePost(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final composed = await showPostComposer(
      context,
      groups: CommunityState.instance.groupsModel(l10n).yours,
      initialGroupId: CommunityState.instance.composeGroupId,
    );
    if (composed == null || !context.mounted) return;
    final handle = CommunityState.instance.publishText(
      caption: composed.caption,
      describe: l10n.posted,
      audience: composed.isStory
          ? PostAudience.day
          : (composed.groupId == null ? PostAudience.page : PostAudience.group),
      groupId: composed.groupId,
      topics: composed.topics,
    );
    if (handle == null) return;
    showUndoSnackBar(context, handle: handle, undoLabel: l10n.undo);
  }

  static PostThreadModel get communityPostModel => PostThreadModel.from(
    post: _communityPost(communityOpenPostId),
    viewerUid: communityStore.selfUid,
    comments:
        communityStore.comments[communityOpenPostId ?? ''] ??
        const <CommunityComment>[],
    flags: featureFlags,
  );

  static CreateOptionsModel get communityCreateModel => CreateOptionsModel.from(
    flags: featureFlags,
    // A follow-up needs something to follow up on. Asked of her own posts,
    // so the tile is absent until she has one rather than offering an
    // action that cannot succeed.
    hasParentPost: communityStore.posts.any(
      (post) => post.authorUid == communityStore.selfUid,
    ),
  );

  static GroupsScreenModel communityGroupsModel(AppL10n l10n) =>
      CommunityState.instance.groupsModel(l10n);

  static GroupScreenModel communityGroupModel(AppL10n l10n) {
    CommunityState.instance.ensureSeeded(l10n);
    final group = _communityGroup(communityOpenGroupId);
    if (group == null) {
      // The group is not there. Rendered as the empty group rather than
      // thrown, exactly as `adminRowValues` opens a missing row as an add.
      return GroupScreenModel(
        group: GroupRowModel(
          groupId: communityOpenGroupId ?? '',
          name: '',
          memberCount: 0,
        ),
        postCount: 0,
        isEmpty: true,
      );
    }
    return GroupScreenModel.from(
      group: group,
      postCount: communityGroupPosts.length,
      challenge: communityStore.challenges[group.groupId],
      now: DateTime.now(),
    );
  }

  static List<PostCardModel> get communityGroupPosts => <PostCardModel>[
    for (final post in communityStore.posts)
      if (post.groupId != null && post.groupId == communityOpenGroupId)
        PostCardModel.from(post, viewerUid: communityStore.selfUid),
  ];

  /// `M06`. All zeros when there is no open challenge — and the model divides
  /// by nothing, so the two bars read empty rather than NaN.
  static GroupGoalModel get communityGoalModel {
    final group = _communityGroup(communityOpenGroupId);
    final challenge = group == null
        ? null
        : communityStore.challenges[group.groupId];
    if (challenge == null) {
      return const GroupGoalModel(
        target: 0,
        total: 0,
        perWoman: 0,
        myDone: 0,
        womenFinished: 0,
        womenTaking: 0,
        daysLeft: 0,
      );
    }
    return GroupGoalModel.from(challenge, now: DateTime.now());
  }

  /// `M07`. Her tiles are the ones the open tab is about.
  static ProfileScreenModel communityProfileModel(AppL10n l10n) =>
      CommunityState.instance.profileModel(
        l10n,
        communityOpenProfileUid,
        tabIndex: communityProfileTab,
      );

  /// `M10`. The chip narrows the grid — filtered where the repository filters,
  /// so a topic that matches nothing shows nothing rather than everything.
  static ExploreScreenModel get communityExploreModel =>
      CommunityState.instance.exploreModel(communityTopic);

  /// `M14`. Real activity on her posts, plus the one follow-up nudge.
  static ActivityScreenModel get communityActivityModel =>
      CommunityState.instance.activityModel();

  /// `M15`. Her chip narrows what she saved.
  static SavedScreenModel get communitySavedModel =>
      CommunityState.instance.savedModel(communitySavedFilter);

  static SafetySheetModel get communitySafetyModel => SafetySheetModel.from(
    subjectName: communitySafetySubject,
    inGroup: communitySafetyInGroup,
    isSelf: !communitySafetyInGroup && communitySafetyUid == _selfUid,
  );

  /// The post `M08` is about, **only when it is hers** — which is the whole of
  /// what decides whether the sheet offers to delete it.
  static String? get communityOwnPostInSheet {
    final postId = CommunityState.instance.safetyPostId;
    final post = CommunityState.instance.post(postId);
    if (post == null || post.authorUid != communityStore.selfUid) return null;
    return post.postId;
  }

  static bool get communityGroupIsMuted =>
      CommunityState.instance.isMuted(communitySafetyUid);

  static bool get communityGroupIsJoined =>
      CommunityState.instance.group(communitySafetyUid)?.joined ?? false;

  /// What a follow-up cost her, or null while she has not asked for the card.
  ///
  /// Two integers, both hers: sessions she logged and weeks that counted. Rule
  /// 11 — there is no field here a scale figure could live in.
  static FollowUpCost? get communityFollowUpCost {
    if (!CommunityState.instance.followUpCostOn) return null;
    final weeks = progressStore.weeks.values;
    return FollowUpCost(
      sessions: weeks.fold<int>(0, (n, w) => n + w.creditedSessionIds.length),
      countedWeeks: weeks.where((w) => w.counted).length,
    );
  }

  /// Publishes the follow-up she composed on `M11`, then leaves it to `M12`.
  static void communityPostFollowUp(BuildContext context) {
    final parentId = communityFollowUpParentId;
    if (parentId == null) return;
    final l10n = AppL10n.of(context);
    final handle = CommunityState.instance.publishFollowUp(
      parentPostId: parentId,
      caption: CommunityState.instance.followUpCaption,
      cost: communityFollowUpCost,
      describe: l10n.posted,
    );
    CommunityState.instance.followUpCaption = '';
    if (handle == null) return;
    showUndoSnackBar(context, handle: handle, undoLabel: l10n.undo);
  }

  static FollowUpComposerModel get communityFollowUpComposerModel =>
      FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[
          for (final post in communityStore.posts)
            if (post.authorUid == communityStore.selfUid && !post.isFollowUp)
              post,
        ],
        viewerUid: communityStore.selfUid,
        selectedPostId: communityFollowUpParentId,
        cost: communityFollowUpCost,
      );

  /// `M12`'s thread, assembled from the store the way the repository assembles
  /// it — the same parent-plus-children shape, read synchronously because a
  /// route builder cannot await.
  static FollowUpThreadModel get communityFollowUpThreadModel {
    final parent = _communityPost(communityFollowUpParentId);
    if (parent == null) {
      return const FollowUpThreadModel(
        moments: <FollowUpMomentModel>[],
        authorUid: '',
      );
    }
    final children = <CommunityPost>[
      for (final post in communityStore.posts)
        if (post.parentPostId == parent.postId) post,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return FollowUpThreadModel.from(
      FollowUpChain(
        authorUid: parent.authorUid,
        moments: <FollowUpMoment>[
          FollowUpMoment(
            postId: parent.postId,
            authorUid: parent.authorUid,
            takenAt: parent.createdAt,
            cost: parent.cost,
          ),
          for (final child in children)
            FollowUpMoment(
              postId: child.postId,
              authorUid: child.authorUid,
              takenAt: child.createdAt,
              cost: child.cost,
            ),
        ],
      ),
    );
  }

  /// The post a thread follows. An empty card when it is gone, which renders
  /// as no name and no figures rather than somebody else's post.
  static PostCardModel get communityFollowUpParentCard {
    final parent = _communityPost(communityFollowUpParentId);
    if (parent == null) {
      return PostCardModel(
        postId: communityFollowUpParentId ?? '',
        authorUid: '',
        authorName: '',
        likeCount: 0,
        commentCount: 0,
      );
    }
    return PostCardModel.from(parent, viewerUid: communityStore.selfUid);
  }

  // ------------------------------------------------ G12, the coach's app

  /// Her profile, her desk, her certificates and her offers.
  ///
  /// Constructed with the **default** `CoachProfile`, not
  /// `InMemoryCoachRepository.settingUp()` or `.working()`: those two carry the
  /// prototype's coach, name and all, and they exist so a test can tell a
  /// screen that renders a sample from one that renders her data. A blank
  /// profile is what a coach who has not answered `K01` actually has.
  static final InMemoryCoachRepository coachRepository =
      InMemoryCoachRepository();

  /// `K01`–`K05` write to ONE model, or her name from `K01` would be gone by
  /// `K05`. The same reason `intakeRepository` is a single instance.
  ///
  /// It lives in `app_state/coach_profile_state.dart` now, beside the save
  /// that puts it into `coachRepository`: the form and the write to the one
  /// profile every other screen reads belong together, and a test that resets
  /// the coach needs a form it can replace.
  static CoachSetupViewModel get coachSetupModel =>
      CoachProfileState.instance.setup;

  /// The row she opened on `K07`.
  static String coachOpenRelId = '';

  /// The thread `K16` shows.
  ///
  /// The client she has open, when she has one — `W02` and `W10` both open a
  /// client and never a relationship — and otherwise the desk row she tapped.
  static String get coachThreadRelId {
    final fromClient = coachDesk.relIdFor(coachPlanClient.clientUid);
    return fromClient.isEmpty ? coachOpenRelId : fromClient;
  }

  /// Why that row was waiting. `K07` hands back a relationship id and nothing
  /// else, and the destination depends on the reason, so it is looked up here.
  static DeskReason coachDeskReason(String relId) {
    for (final item in coachRepository.deskUnbilled.queue) {
      if (item.relId == relId) return item.reason;
    }
    return DeskReason.newEnquiry;
  }

  /// What `K09` opens when there is no enquiry behind the row.
  ///
  /// Empty — no client, no situation, no words put in her mouth. The real one
  /// is `CoachingDeskState.enquiryAt`, read back from what `H04` actually
  /// wrote; this is only what a row opened before anybody enquired resolves
  /// to, and the screen then offers neither accept nor decline.
  static Enquiry get coachOpenEnquiry => Enquiry(
    relId: coachOpenRelId,
    coachUid: coachRepository.coachUid,
    clientUid: '',
    status: EnquiryStatus.enquiry,
    enquiredAt: DateTime.now(),
  );

  static CoachTodayViewModel get coachTodayModel => CoachTodayViewModel.from(
    profile: coachRepository.profileUnbilled,
    desk: coachRepository.deskUnbilled,
    now: DateTime.now(),
    flags: featureFlags,
  );

  // ------------------------------------------- G13, her portfolio (B01)

  /// Her draft, her live page, the one canvas every B screen edits, and the
  /// saves between them.
  ///
  /// It moved into `app_state/coach_portfolio_state.dart` when the editors
  /// were given somewhere to save: the draft, the repository that refuses what
  /// Firestore refuses, and the publish that writes `live` belong together,
  /// and a test that resets her page needs a canvas it can replace.
  static CoachPortfolioState get portfolio => CoachPortfolioState.instance;

  // -------------------------------------------- G11, the marketplace (H)
  //
  // **Still nothing is seeded**, for the reason the Phase 3 note above gives:
  // there is no authored coach pack, so putting the prototype's Nourhan
  // El-Sayed and her 1,800 EGP on screen would be telling a woman the mockup's
  // figures as facts about a stranger she is deciding whether to pay.
  //
  // What changed is that a coach can now *get* there. `CoachingLinkState`
  // lists a coach the moment her page goes live, from her own documents, and
  // holds the enquiries and the one relationship this build can produce.

  /// Who is listed, who asked whom, and who ended up working together.
  static CoachingLinkState get coaching => CoachingLinkState.instance;

  /// The coach whose page she opened, recorded inline at the tap.
  static String marketplaceOpenCoachUid = '';

  /// The package she selected on `H03`.
  static String? marketplaceSelectedOfferId;

  /// Whether her account has been through the check, as this build knows it.
  ///
  /// The local echo of what `C12` decided, in the same spirit as
  /// [lastSignupRole] — except that with no account required nothing can check
  /// her, and refusing her would put the whole marketplace out of reach of the
  /// person testing it. `H01` says in words that nobody has been checked.
  static bool get marketplaceVerified => coaching.verified;

  static PackagesViewModel get packagesModel => PackagesViewModel.resolve(
    coachUid: marketplaceOpenCoachUid,
    coachName: coaching.coachNameFor(marketplaceOpenCoachUid),
    // Her own offer documents, the same ones `B06` and `K18` render, so a
    // price cannot be stale in one place and current in the other.
    offers: coaching.offersFor(marketplaceOpenCoachUid),
    stage: coaching.stageWith(marketplaceOpenCoachUid),
    flags: featureFlags,
    verified: marketplaceVerified,
    // There is no connectivity service anywhere in this build. `true` is the
    // neutral value: the gate asks about signal only after it has agreed on
    // everything else.
    online: true,
    coachAcceptingClients: coaching.acceptingClients(marketplaceOpenCoachUid),
    spotsLeft: coaching.spotsLeftFor(marketplaceOpenCoachUid),
    selectedOfferId: marketplaceSelectedOfferId,
  );

  static EnquiryViewModel get enquiryModel => EnquiryViewModel(
    coachUid: marketplaceOpenCoachUid,
    coachName: coaching.coachNameFor(marketplaceOpenCoachUid),
    clientUid: _selfUid,
    stage: coaching.stageWith(marketplaceOpenCoachUid),
    flags: featureFlags,
    verified: marketplaceVerified,
    coachAcceptingClients: coaching.acceptingClients(marketplaceOpenCoachUid),
    // Sent is a fact about the relationship, not about this screen: coming
    // back to `H04` after enquiring shows the thread rather than an empty box
    // she could send a second time.
    phase: switch (coaching.stageWith(marketplaceOpenCoachUid)) {
      MarketplaceStage.browsing => EnquiryPhase.composing,
      _ => EnquiryPhase.sent,
    },
    text:
        coaching
            .enquiries[coaching.relIdOrNull(marketplaceOpenCoachUid) ?? '']
            ?.herWords ??
        '',
  );

  // ------------------------------------------------ G14, her planning desk

  /// Her desk and her month: the roster, the drafts, the splits, the
  /// assessments, the thread and the one published document the coached
  /// screens read back.
  static CoachingDeskState get coachDesk => CoachingDeskState.instance;

  /// The other side of the same relationship — what `G01`–`G16` answer and log.
  static CoachedLifeState get coachedLife => CoachedLifeState.instance;

  /// Her roster: every woman she has accepted. Empty until she accepts one,
  /// and `hasLoaded: true` on `W01` says that honestly.
  static List<CoachClient> get coachPlanClients => coachDesk.clients;

  /// Her splits. Written by `K20`, listed by `K19`.
  static List<coachplan.Split> get coachPlanSplits => coachDesk.splits;

  /// The client she opened, recorded at the tap. Null until she opens one.
  ///
  /// Held on the desk rather than here, so a callback inside
  /// `coaching_desk_state.dart` can open one too — the "Start" on `W01`'s
  /// waiting card and a desk row on `K07` both do.
  static CoachClient? get coachPlanOpenClient => coachDesk.openClient;

  static set coachPlanOpenClient(CoachClient? client) =>
      coachDesk.openClient = client;

  /// The client the planning screens are about.
  ///
  /// The one she opened, or — when she has exactly one client and has tapped
  /// nobody — that client, because a roster of one has no ambiguity and
  /// `W01`'s "Build a plan" would otherwise open a month belonging to nobody.
  /// An empty client when neither holds, rendered as a row with no name rather
  /// than thrown, exactly as `adminRowValues` opens a missing row as an add.
  static CoachClient get coachPlanClient => coachDesk.client;

  /// The day `W04` opens on, and the week `W03` is showing.
  static String? coachPlanOpenDayKey;
  static int coachPlanWeekIndex = 0;

  /// The day `W04` is editing: the row she tapped, or today when she arrived
  /// through "add a workout" rather than from a date.
  static String get coachPlanDayKey =>
      coachPlanOpenDayKey ?? dayId(DateTime.now());

  /// `yyyy-MM` for [now] — how a draft is sharded, one document per month.
  static String monthId(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';

  /// This month's draft for the client she has open.
  ///
  /// **The stored one.** It used to build a new empty `PlanDraft` on every
  /// build, so nothing a coach planned survived the next rebuild; it is now a
  /// read of the one document `W03`–`W07` all write, keyed by the same
  /// deterministic id.
  static PlanDraft get coachPlanDraft =>
      coachDesk.draftFor(coachPlanClient.clientUid);

  /// The split `K20` opens, or null when she tapped "build a split".
  static coachplan.Split? coachPlanOpenSplit;

  /// The split `K20` is editing — the one she opened, or the blank week she
  /// gets when she tapped "build a split".
  ///
  /// The blank one is still seven rest days, for the reason it always was: a
  /// slot with a session in it would be a week somebody authored.
  static coachplan.Split get coachPlanSplit => coachDesk.splitInProgress;

  /// `K21` and `K23` write to ONE form, or her life stage from the first step
  /// would be gone by the second. The same reason `coachSetupModel` is one
  /// instance.
  ///
  /// It lives in `app_state/coaching_desk_state.dart` now, beside the save that
  /// turns it into an `AssessmentRecord`: the two steps are one document, and
  /// the record is what `W02`, `W04` and `K22` read her constraints from.
  static AssessmentForm get coachAssessmentForm => coachDesk.form;

  // ------------------------------------------------ G10, the last three (M)

  /// `M09`. `available` is false while `communityVideo` is off, and the screen
  /// renders its unavailable state rather than an empty player.
  static ReelsScreenModel get communityReelsModel => ReelsScreenModel.from(
    flags: featureFlags,
    reels: <CommunityPost>[
      for (final post in communityStore.posts)
        if (post.kind == PostKind.reel) post,
    ],
  );

  static List<PostCardModel> get communityReelCards => <PostCardModel>[
    for (final post in communityStore.posts)
      if (post.kind == PostKind.reel)
        PostCardModel.from(post, viewerUid: communityStore.selfUid),
  ];

  /// `M13`. Live stories only, oldest first — chronology, not a ranking. An
  /// expired story is absent rather than greyed out.
  static StoryViewerModel get communityStoryModel => StoryViewerModel.from(
    stories: communityStore.posts,
    viewerUid: communityStore.selfUid,
    now: DateTime.now(),
    openPostId: communityOpenPostId,
    flags: featureFlags,
  );

  /// `M16`. Which modes the rail offers is the flags' answer, not a layout
  /// decision — the Reel tile returns with no code change when video is on.
  static RecordScreenModel get communityRecordModel =>
      RecordScreenModel.from(flags: featureFlags);

  /// How many of the product's screens are implemented.
  static int get builtCount => _built.length;

  /// Whether a screen id has a widget behind it. False means the route
  /// resolves to [NotBuiltYet] rather than to a screen.
  static bool isBuilt(String screenId) => _built.containsKey(screenId);

  /// Navigates by screen id rather than by route string, so a screen never has
  /// to know another screen's path.
  static void goTo(BuildContext context, String screenId) {
    final route = appDestinations[screenId];
    if (route == null) return;
    Navigator.of(context).pushNamed(route.name);
  }

  // My cycle's three tabs are mapped INLINE at each call site above, not in a
  // helper here. That looks like duplication and is not.
  //
  // `nav_reachability_test` recovers the navigation graph by reading which
  // screen ids each builder mentions. A helper hides them: with the mapping in
  // one function, `'Y08'` and `'Y10'` appeared nowhere in Y03's builder, so the
  // calendar and patterns tabs were invisible edges and four built screens —
  // Y08, Y09, Y10, Y13 — were reported stranded with no way in. The test was
  // right: a reader of Y03's builder could not see where its tabs went either.

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => NotBuiltYet(
        screenId: '—',
        title: 'No screen serves ${settings.name ?? "this route"}',
      ),
    );
  }
}

/// Deliberately conspicuous. The brief forbids a silent stub that looks finished,
/// so an unbuilt destination names itself and says it is not built, rather than
/// showing a plausible-looking empty page that reads as done.
class NotBuiltYet extends StatelessWidget {
  const NotBuiltYet({super.key, required this.screenId, required this.title});

  final String screenId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLow,
      appBar: AppBar(title: Text(screenId, style: AppText.titleM)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppText.titleL, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Not built yet. Routing is wired; this screen is waiting on its '
                'feature group implementation.',
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A screen that exists but whose feature is switched off.
///
/// Deliberately distinct from [NotBuiltYet]: "we have not built this" and "this
/// is built and currently off" are different facts, and collapsing them would
/// make the switchboard impossible to reason about during a release.
class FeatureOff extends StatelessWidget {
  const FeatureOff({super.key, required this.screenId, required this.title});

  final String screenId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLow,
      appBar: AppBar(title: Text(screenId, style: AppText.titleM)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppText.titleL, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Switched off. This screen is built and tested; its feature '
                'flag is currently off.',
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
