import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show PlatformDispatcher;

// The ID token, and nothing else from this package. `verified` is a custom
// claim the Cloud Function mints and the security rules read, so it is the one
// answer to "has she passed the check" that the client cannot forge. See
// `AppRouter.readVerificationClaim`.
// `kReleaseMode` — the admin console is compiled out of reach in a release
// binary. See `AppRouter.resolvesInThisBuild`.
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
// `Clipboard` — Z11 hands the export over on it, because nothing in this build
// can write a file.
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;

import '../app_state/account_data.dart';
import '../app_state/admin_backends.dart';
import '../app_state/app_changes.dart';
import '../app_state/blocking.dart';
import '../app_state/cloud_store.dart';
import '../app_state/analytics_consent.dart';
import '../app_state/crash_consent.dart';
import '../app_state/crash_reports.dart';
// Read, never written: `FirebaseBoot.isReady` is what decides whether the
// identity check can be built against real Cloud Functions or has to refuse
// honestly. See `_newIdentityCheck`.
import '../app_state/firebase_boot.dart';
import '../app_state/verification_memory.dart';
import '../config/admin_build.dart';
import '../config/care_links.dart';
import '../config/legal_links.dart';
import '../app_state/coach_invite_state.dart';
import '../app_state/coach_portfolio_state.dart';
import '../app_state/coach_profile_state.dart';
import '../app_state/coached_life_state.dart';
import '../app_state/coaching_desk_state.dart';
import '../app_state/coaching_link_state.dart';
import '../app_state/community_state.dart';
import '../app_state/cycle_state.dart';
import '../app_state/eat_state.dart';
import '../app_state/events_state.dart';
import '../app_state/exercise_library_state.dart';
import '../app_state/first_gym_guide_state.dart';
import '../app_state/workout_library_state.dart';
import '../app_state/demo_mode.dart';
import '../app_state/honest_notice.dart';
import '../app_state/onboarding_state.dart';
import '../app_state/pledge.dart';
import '../app_state/notification_sync.dart';
import '../app_state/push_registration.dart';
import '../app_state/reminder_scheduler.dart';
import '../app_state/role_state.dart';
import '../app_state/open_app_settings.dart';
import '../app_state/open_link.dart';
import '../app_state/workout_session_state.dart';
import '../app_state/rewards_state.dart';
import '../domain/rewards/credit_outcome.dart';
import '../app_state/training_streak_state.dart';
import '../domain/rewards/training_streak.dart';
import '../domain/clock/app_clock.dart';
import '../domain/rewards/level_curve.dart';
import '../features/testing/presentation/all_screens_view.dart';

import '../domain/analytics/analytics_gateway.dart';
import '../domain/flags/feature_flags.dart';
import '../domain/format/day_key.dart';
import '../domain/format/number_label.dart' show countLabel;
import '../ui/app_step_progress.dart';
import '../ui/app_undo_snackbar.dart';
import '../ui/screen_scope.dart';
import '../domain/identity/user_roles.dart';
import '../domain/rewards/personal_best_ledger.dart';
import '../domain/week/week_key.dart';
import '../features/eat/domain/allergy_guard.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/eat/domain/recipe.dart' show Recipe, RecipeSource;
import '../features/eat/domain/meal_repository.dart' as eat_plan show PlanDay;
import '../features/eat/presentation/allergy_question_view.dart';
import '../features/eat/presentation/eat_sample_library.dart';
import '../features/eat/presentation/eat_view.dart';
import '../features/eat/presentation/grocery_list_view.dart';
import '../features/eat/presentation/rahma_letter_view.dart';
import '../features/eat/presentation/rahma_recipe_view.dart';
import '../features/eat/presentation/recipe_view.dart';
import '../features/eat/presentation/recipes_view.dart';
import '../features/eat/presentation/say_it_view.dart';
import '../features/eat/presentation/type_it_view.dart';
import '../features/eat/presentation/week_plan_view.dart';
import '../features/onboarding/domain/intake_repository.dart';
import '../features/onboarding/domain/intake.dart' show TrainingPlace;
import '../features/onboarding/presentation/equipment_view.dart';
import '../features/onboarding/presentation/goal_view.dart';
import '../features/onboarding/presentation/her_answers.dart';
import '../features/onboarding/presentation/life_stage_view.dart';
import '../features/onboarding/presentation/place_view.dart';
import '../features/onboarding/presentation/schedule_view.dart';
import '../features/onboarding/presentation/starting_program_view.dart';
import '../features/signup/data/callable_capture_consent_store.dart';
import '../features/signup/data/callable_legal_acceptance_store.dart';
import '../features/signup/data/firebase_auth_repository.dart';
import '../features/signup/data/identity_check.dart';
import '../features/signup/data/verification_backend.dart';
import '../features/signup/domain/auth_repository.dart';
import '../features/signup/domain/capture_consent.dart';
import '../features/signup/domain/id_capture.dart';
import '../features/signup/domain/legal_acceptance.dart';
import '../features/signup/domain/locale_preference.dart';
import '../features/signup/domain/review_request.dart';
import '../features/signup/domain/server_verification.dart';
import '../features/signup/domain/verification.dart';
import '../features/signup/domain/verification_provider.dart';
import '../features/coach/domain/coach_invite.dart';
import '../features/coach/presentation/certificate_camera_view.dart';
import '../features/signup/presentation/being_checked_view.dart';
import '../features/signup/presentation/coach_interest_sheet.dart';
import '../features/signup/presentation/invite_code_sheet.dart';
import '../features/signup/presentation/checking_view.dart';
import '../features/signup/presentation/code_view.dart';
import '../features/signup/presentation/consent_view.dart';
import '../features/signup/presentation/demo/demo_stops.dart' show DemoStop;
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
import '../features/today/domain/today_day.dart'
    show FirstWeekStep, WeekProgress;
import '../features/today/domain/today_repository.dart';
import '../features/today/presentation/already_did_it_view.dart';
import '../features/today/presentation/first_week_view.dart';
import '../features/today/presentation/lock_screen_nudge_view.dart';
import '../features/today/presentation/quiet_week_view.dart';
import '../features/today/presentation/tier_slip_view.dart';
import '../domain/logging/log_command_bus.dart';
import '../features/today/presentation/streak_sheet.dart';
import '../features/today/presentation/today_view.dart';
import '../features/train/domain/library_recommendation.dart';
import '../features/train/domain/own_best_challenge.dart';
import '../features/train/domain/rest_policy.dart';
import '../features/train/domain/session_bests_bridge.dart';
import '../features/train/domain/set_history.dart';
import '../features/train/domain/exercise_library.dart' show LibraryExercise;
import '../features/train/domain/train_repository.dart';
import '../features/train/presentation/exercise_labels.dart' show equipmentLine;
import '../features/train/presentation/change_set_view.dart';
import '../features/train/presentation/set_labels.dart' show moveTitle;
import '../features/train/presentation/exercise_video_view.dart';
import '../features/train/domain/notification_plan.dart';
import '../features/train/domain/training_reminders.dart';
import '../features/train/presentation/finished_view.dart';
import '../features/train/presentation/notification_explainer.dart';
import '../features/train/presentation/reminder_sheet.dart';
import '../features/train/presentation/follow_along_view.dart';
import '../features/train/presentation/logged_from_memory_view.dart';
import '../features/train/presentation/mid_set_view.dart';
import '../features/train/presentation/move_logged_view.dart';
import '../features/train/presentation/first_gym_guide_view.dart';
import '../features/train/presentation/program_view.dart';
import '../features/train/presentation/resting_view.dart';
import '../features/train/presentation/swap_move_view.dart';
import '../features/train/presentation/train_view.dart';
import '../features/train/presentation/workout_day_view.dart';
import '../features/train/presentation/exercise_demo_view.dart';
import '../features/train/presentation/exercise_library_view.dart';
import '../features/train/presentation/workout_library_view.dart';
import '../features/account/domain/account_deletion_service.dart';
import '../features/account/data/callable_health_consent_store.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/account/domain/health_backup.dart';
import '../features/account/domain/notifications.dart';
import '../features/account/domain/privacy_settings.dart';
import '../features/account/domain/safety.dart';
import '../features/account/presentation/legal_update_sheet.dart';
import '../features/account/presentation/notifications_view.dart';
import '../features/account/presentation/privacy_view.dart';
import '../features/account/presentation/profile_view.dart';
import '../features/account/presentation/safety_centre_view.dart';
import '../features/account/presentation/your_data_sheet.dart';
import '../features/admin/domain/csv_parser.dart';
import '../features/admin/domain/content_schema.dart';
import '../features/admin/domain/export_manifest.dart' show buildExportBundle;
import '../features/admin/domain/import_validator.dart';
import '../features/admin/domain/console_source.dart';
import '../features/admin/domain/content_documents.dart';
import '../features/admin/domain/remote_content_repository.dart';
import '../features/admin/domain/media_bundle.dart';
import '../features/admin/domain/media_picker.dart';
import '../features/admin/domain/seed_library.dart';
import '../features/admin/domain/text_source.dart';
import '../features/admin/presentation/bulk_import_view.dart';
import '../features/admin/presentation/collection_view.dart';
import '../features/admin/presentation/content_form_view.dart';
import '../features/admin/presentation/content_library_view.dart';
import '../features/admin/presentation/dashboard_view.dart';
import '../features/admin/presentation/event_form_view.dart';
import '../features/admin/presentation/events_admin_view.dart';
import '../features/admin/presentation/logs_view.dart';
import '../features/admin/presentation/export_view.dart';
import '../features/admin/presentation/import_check_view.dart';
import '../features/admin/presentation/media_library_view.dart';
import '../features/coach/domain/coach_desk.dart';
import '../features/eat/data/seeded_recipe_library.dart'
    show SeededRecipeLibrary, kRahmaRecipesAsset;
import '../features/events/domain/event_repository.dart';
import '../features/events/domain/hub_event.dart';
import '../features/events/presentation/events_view.dart';
import '../features/onboarding/domain/starting_program.dart'
    show StartingProgram, StartingProgrammes, selectStartingProgram;
import '../domain/training/prescribed_set.dart' show PrescribedSet;
import '../features/train/domain/load_advice.dart';
import '../features/train/domain/weight_label.dart' show weightLabel;
import '../features/train/domain/programme_week.dart';
import '../features/train/domain/workout_library.dart'
    show AuthoredProgramme, AuthoredSession;
import '../features/train/presentation/authored_workout.dart';
import '../features/coach/domain/coach_repository.dart';
import '../features/coach/domain/enquiry.dart';
import '../features/coach/presentation/coach_basics_view.dart';
import '../features/coach/presentation/coach_how_you_coach_view.dart';
import '../features/coach/presentation/coach_photo_view.dart';
import '../features/coach/presentation/coach_results_step_view.dart';
import '../features/coach/presentation/coach_reviews_step_view.dart';
import '../features/coach/presentation/coach_rules_view.dart';
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
import '../features/cycle/domain/meal_picks.dart';
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
import '../features/progress/domain/progress_repository.dart';
import '../features/progress/presentation/body_privately_view.dart';
import '../features/progress/domain/milestone.dart';
import '../features/progress/presentation/milestones_view.dart';
import '../features/progress/presentation/personal_bests_view.dart';
import '../features/progress/presentation/progress_view.dart';
import '../features/progress/presentation/progress_view_model.dart';
import '../features/progress/presentation/share_progress_view.dart';
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
import 'screen_features.dart';

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
  /// Where usage statistics go: the tour, each sign-up step reached and
  /// completed, the ID check's steps, her first workout and meal, a weekly
  /// target reached, the screens of the tabs she uses, and a few settings.
  /// `main()` hands them to Firebase in a release build, which sends nothing
  /// until she allows it ("Help improve Own Hub"), and to the console in a
  /// debug one; a test swaps in a recording sink.
  ///
  /// Never called from the cycle flow, and no screen of it is reported:
  /// `cycle_no_analytics_call_sites_test` holds that for the feature itself
  /// and [reportsScreenView] holds it here.
  static AnalyticsGateway analytics = const AnalyticsGateway(
    NullAnalyticsSink(),
  );

  /// The flows whose screen views are reported: sign-up and setup, to see
  /// where women stop between installing and day one, and the four tabs and
  /// her account screens, to see what she uses. Never the cycle flow.
  static const Set<String> _reportsScreenViews = {
    'signup',
    'onboarding',
    'today',
    'train',
    'eat',
    'progress',
    'account',
  };

  /// Screens of a reported flow whose id alone would say something about
  /// her body: her measurements (`P04`) and what she cannot eat (`E10`).
  static const Set<String> _neverReported = {'P04', 'E10'};

  /// Whether opening [id] is counted as a screen view, and named in a crash
  /// report. Everything else is `private` there.
  @visibleForTesting
  static bool reportsScreenView(String id) {
    final route = appDestinations[id];
    return route != null &&
        _reportsScreenViews.contains(route.flow) &&
        !_neverReported.contains(id);
  }

  /// Resolves a route name to a page. Returns null for anything that is not a
  /// destination, so a first-run state fails loudly at the navigator rather than
  /// quietly rendering an empty-state screen over real data.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;
    final id = screenIdForRoute(name);
    if (id == null) return null;

    // The admin console is not in a shipped build at all. Returning null is
    // the same answer this method gives a name no screen serves, so the route
    // lands on `onUnknownRoute` exactly as a typo would.
    if (!resolvesInThisBuild(id)) return null;

    final route = appDestinations[id]!;

    // D25. A screen whose feature is switched off is not reachable, even when
    // it is fully built and its route resolves. Without this check
    // `featureFlags` is a claim with no mechanism: every Phase 3 screen would
    // be one deep link away from a woman the moment it compiled.
    if (!screenIsOn(id)) {
      return MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) => FeatureOff(screenId: id, title: route.title),
      );
    }

    // The whole-app gate. She cannot use the product before the check
    // completes, and this is the only place that can actually enforce it.
    //
    // Enforced at the route rather than by hiding controls, because hiding a
    // control is a rendering decision and this is a gate. The platform hands
    // [onGenerateRoute] whatever name it is given — a deep link, a notification
    // payload, `main.dart`'s initial route, another app on the handset — so
    // anything that can name `/train/r01` reaches Train unless the answer is
    // given here. It is the same argument `resolvesInThisBuild` makes about the
    // admin console, for the same reason.
    //
    // Returning her route rather than null: null lands on `onUnknownRoute`,
    // which says "no screen serves this route". That is untrue and it is a
    // developer's sentence. [verificationGate] answers with the screen she
    // should be on instead, in her language, and the recursion is one level
    // deep because nothing it can name is itself behind the gate.
    final gate = verificationGate(id);
    if (gate != null) return onGenerateRoute(RouteSettings(name: gate));

    // And nothing opens a lens before her agreement has been written down.
    //
    // Unconditional, unlike the gate above: a camera on a woman's face and her
    // national ID with no record that she agreed to it is not a release
    // decision, and it does not become acceptable because a feature flag is
    // off. `C09b` is therefore the only door into the three capture screens,
    // and this is what makes that true for a deep link as well as for a tap.
    //
    // `ConsentView` sets [consentRecorded] only after the write has returned,
    // and `beginIdentityCheck` lifts it for a woman who agreed to this same
    // wording on an earlier visit. A failed write leaves it false and she stays
    // on the consent screen, which is the correct failure.
    if (_opensALens.contains(id) && !consentRecorded) {
      return onGenerateRoute(
        RouteSettings(name: appDestinations['C09b']!.name),
      );
    }

    final reported = reportsScreenView(id);
    if (reported) {
      unawaited(
        analytics.track(AnalyticsEvent.screenViewed, {
          AnalyticsProp.screenId: AnalyticsValue.token(id),
          AnalyticsProp.flow: AnalyticsValue.token(route.flow),
        }),
      );
    }
    // The screen a crash happened on, only with her consent to crash
    // reports, and `private` for every screen not counted above.
    unawaited(CrashReports.screen(reported ? id : 'private'));
    _trackRouteOpened(id);

    final built = _built[id];
    return MaterialPageRoute<dynamic>(
      settings: settings,
      // ScreenScope tells the screen its own id, which is how AppScaffold finds
      // this screen's illustrations in ScreenArt. Only the router does this, so
      // widget tests that build a screen directly draw no illustration.
      builder: built == null
          ? (_) => NotBuiltYet(screenId: id, title: route.title)
          // Redrawn whenever shared state changes, so a screen underneath
          // another is current again the moment she comes back to it — and,
          // since `RedrawOnChange` replaced the `ListenableBuilder` that was
          // here, not while it is buried under one. See `app_changes.dart` for
          // what the plain listener cost at six screens deep.
          : (_) => RedrawOnChange(
              builder: (context) =>
                  ScreenScope(screenId: id, child: built(context)),
            ),
    );
  }

  /// Whether [screenId] may resolve to anything at all in this build.
  ///
  /// False for the admin console, `Z01` to `Z14`, in a release binary, and for
  /// nothing else, ever.
  ///
  /// # Why a compile-time gate rather than a feature flag
  ///
  /// `Feature.adminConsole` already gates the flow, and it is not enough.
  /// `Z14` is the switchboard itself: it can turn **every** flag on, including
  /// `Feature.accountRequired`, and turning that one off removes sign-up,
  /// prints the one sign-in code the in-memory auth accepts, opens the index of
  /// every screen in the product and opens a test payment rail. A flag cannot
  /// guard the screen that edits flags.
  ///
  /// And a route that resolves is reachable. The platform hands
  /// [onGenerateRoute] whatever route name it is given, so anything that can
  /// name `/admin/z14` (a deep link, a notification payload, another app on the
  /// handset) is one string away from the console. `kReleaseMode` is const, so
  /// in release the admin arm below is the only answer the compiler keeps and
  /// the check costs nothing at run time.
  ///
  /// A debug build keeps the console, for working on it. A profile build keeps
  /// it only when it is the owner's admin build (`--dart-define=ADMIN_BUILD=
  /// true`, made by `tool/admin_access.sh build`), which is how she runs the
  /// console on her own phone. A release build never does, whatever was
  /// defined: `release` is checked first, so `ADMIN_BUILD` cannot put the
  /// console in a store binary. See `lib/config/admin_build.dart`.
  ///
  /// The three are parameters because a widget test cannot be compiled in
  /// release or profile mode. They default to the real thing and are passed
  /// only by the tests that prove the refusal, in
  /// `test/release_readiness_test.dart`.
  static bool resolvesInThisBuild(
    String screenId, {
    bool release = kReleaseMode,
    bool debug = kDebugMode,
    bool adminBuild = kAdminBuild,
  }) =>
      appRoutes[screenId]?.flow != 'admin' ||
      (!release && (debug || adminBuild));

  /// The flags a build starts with: what ships, with the console switched on
  /// in the owner's admin build and nowhere else.
  static FeatureFlags startingFlags({
    bool release = kReleaseMode,
    bool adminBuild = kAdminBuild,
  }) => adminBuild && !release
      ? FeatureFlags.shipped.with_({Feature.adminConsole: true})
      : FeatureFlags.shipped;

  /// Whether A02 offers the way into the console: in a build that resolves it
  /// and with its switch on. False in every store build.
  static bool get adminConsoleOffered =>
      resolvesInThisBuild('Z01') && screenIsOn('Z01');

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

  /// Screens no switch can close.
  ///
  /// `C02` is the language chooser. It sits in the sign-up flow because that is
  /// where she first meets it, but choosing between Arabic and English is a
  /// setting, not a step of registration: `A02` carries a row into it, and
  /// `C02`'s own copy promises "you can change this any time in your profile".
  /// With sign-up dark the row landed on [FeatureOff], so the first release
  /// would have shipped in whatever language the handset happened to be in,
  /// with no way to change it.
  ///
  /// `A01`–`A04` and `O01`–`O06` are the two flows [featureForFlow] leaves
  /// ungated, named here one by one so a new screen in either has to be
  /// placed on purpose: her settings, her data and her way out, and the
  /// setup questions between signing up and having an account. A flag flip
  /// must never trap a woman.
  ///
  /// An entry here has to carry that kind of reason. It is not a place for a
  /// screen somebody wants reachable early. Every other screen has a switch
  /// in [screenFeatures].
  static const Set<String> ungatedScreens = {
    'C02',
    'A01',
    'A02',
    'A03',
    'A04',
    'O01',
    'O02',
    'O03',
    'O04',
    'O05',
    'O06',
  };

  /// The switch every gated screen answers to, beside its flow's
  /// (`lib/routing/screen_features.dart`).
  static const Map<String, Feature> screenFeatures = kScreenFeatures;

  /// The bar title of the short "Your week": "1 of 3 · Your week" before she
  /// has an account, which counts the three parts of joining, and nothing
  /// after it. The line under the title counts the questions either way.
  static String _shortSetupTitle(BuildContext context) =>
      OnboardingState.instance.beforeSignup
      ? signupPhaseLabel(AppL10n.of(context), SignupPhase.week)
      : '';

  /// Whether a control that leads to [screenId] may be drawn at all.
  ///
  /// The one question every screen asks before it renders a row, a chip, a
  /// button or a step that opens another screen. A control whose destination
  /// is dark lands on [FeatureOff] — a door drawn on a wall, which is App
  /// Review 2.1 and, on the screens in the store listing, the first thing a
  /// woman meets.
  ///
  /// `app_nav_bar.dart` asked this question for the bottom bar before anything
  /// else did; it now asks it here, so the bar and the screens cannot come to
  /// different answers about the same feature.
  ///
  /// A screen is on when its flow's switch and its own switch are both on.
  /// An unknown id is **on**: this is not a gate (that is [onGenerateRoute]'s
  /// job, and it is the one that has to be conservative) but a rendering
  /// decision, and a typo should show a broken link rather than silently
  /// delete a control nobody can then find.
  static bool screenIsOn(String screenId) {
    if (ungatedScreens.contains(screenId)) return true;
    final flow = appRoutes[screenId]?.flow;
    final flowFeature = flow == null ? null : featureForFlow(flow);
    if (flowFeature != null && !featureFlags.isOn(flowFeature)) return false;
    final own = screenFeatures[screenId];
    return own == null || featureFlags.isOn(own);
  }

  // ------------------------------------------------- The whole-app gate (G1)
  //
  // The owner's decision, and it replaced a narrower one: a pending check used
  // to close only the community, and training, recipes and coach profiles were
  // open while she waited. They are not any more. Nothing opens until the check
  // completes, and `C14` says exactly that.
  //
  // **This is built and switched on.** The gate closes when
  // `Feature.accountRequired` is on, and that flag ships on in
  // `FeatureFlags.shipped` (2026-10-02). See the note on [testingAidsAllowed]
  // for the release ordering that has to come before a build with it on.
  //
  // The setup questions (`onboarding`) are open before verification, which is
  // what lets a new woman build her week on `O03` and `O05` before she is asked
  // for her number. Nothing behind the gate moved.
  //
  // Nor did the tour move it. `C04` shows the real Home, Train, Eat, My cycle
  // and Progress screens before sign-up, but it is a `signup` screen that
  // builds them itself with a sample week, and [goTo] refuses every route
  // asked for inside it. No product route opens for a woman who is not
  // verified, from the tour or from anywhere else.

  /// Flows a woman reaches before, or instead of, being verified.
  ///
  /// Everything not listed here is behind the gate: Today, Train, Eat,
  /// Progress, My cycle, the community, the marketplace, the coached life and
  /// every coach surface. Each entry below has to carry a reason that survives
  /// being read out to the owner, because each one is a hole in a women-only
  /// gate.
  ///
  ///   * **`signup`** — it IS the check. Gating it would mean a woman who
  ///     cannot verify because she cannot reach the screen that verifies her.
  ///   * **`onboarding`** — the four setup questions. `main.dart` opens them on
  ///     top of the front door on a first launch, and the same argument
  ///     [featureForFlow] makes applies: a half-registered woman must never be
  ///     stranded with no way forward and no way back.
  ///   * **`account`** — her privacy centre, her export and her account
  ///     deletion. PDPL erasure is not something to put behind a check she has
  ///     not passed, and a woman who is refused must still be able to take her
  ///     data and leave. Refusing her the app AND the door out is the one
  ///     combination this product must never produce.
  ///   * **`admin`** — staff tooling, already compiled out of a release binary
  ///     by [resolvesInThisBuild] and gated on a server-minted `admin` claim in
  ///     the rules. It is not the product, and asking the person who loads the
  ///     recipe library for an Egyptian national ID card would be nonsense.
  static const Set<String> openBeforeVerification = {
    'signup',
    'onboarding',
    'account',
    'admin',
  };

  /// Whether [screenId] is part of the product she must be verified to use.
  static bool behindVerification(String screenId) {
    final flow = appRoutes[screenId]?.flow;
    // An unknown id is behind the gate. The opposite of [screenIsOn]'s answer
    // to the same question, and deliberately: that one is a rendering decision
    // where a typo should show a broken link, this one is a gate where a typo
    // must not be a way in.
    return flow == null || !openBeforeVerification.contains(flow);
  }

  /// Whether the server says this account has passed the check.
  ///
  /// Two sources, both of which are the server's:
  ///
  ///   * the `verified` custom claim, read at start-up into [_verifiedClaim].
  ///     `firebase/firestore.rules` reads `request.auth.token.verified == true`
  ///     in 864 lines of rules, and the function mints that exact name, so it
  ///     is the name this reads.
  ///   * [lastVerification], which is what `C12` received a moment ago in this
  ///     session. It exists because the claim is only visible after a token
  ///     refresh, and a woman told "You're in" on `C13` must not meet a locked
  ///     app on `C16`.
  ///
  /// **Nothing here is the client deciding.** Both are readings of a decision
  /// made by a Cloud Function; there is no branch that grants access on
  /// anything the phone worked out.
  ///
  /// Two more readings, for a woman the network cannot answer for (R1):
  ///
  ///   * [serverVerification] saying `approved`. Only the server writes that
  ///     state, and a woman it names is never shown "waiting": she is let in
  ///     and the token refresh is retried on resume and on reconnect.
  ///   * [_verifiedOnThisPhone]: a fresh token proved this uid verified on
  ///     this phone before ([VerificationMemory]), and today the token cannot
  ///     be read for want of a network, or Firebase did not come up at all.
  ///     Offline first: her own week is on this phone. Server data stays
  ///     behind the rules, which read the real claim.
  ///
  /// Those two count only while no fresh claim has been read in this session
  /// ([_freshClaimRead]). Once a token has been read, its claim is the truth:
  /// staff can revoke a claim after approval while the document still says
  /// `approved`, and a fresh `false` must close the gate (N2).
  ///
  /// No evidence at all still means no product (Protected List 4).
  static bool get isVerified =>
      _verifiedClaim ||
      lastVerification != null ||
      (!_freshClaimRead &&
          (serverVerification?.state == ServerVerificationState.approved ||
              _verifiedOnThisPhone));

  static bool _verifiedClaim = false;
  static bool _verifiedOnThisPhone = false;

  /// Whether a claim has been read from a token in this session, newer than
  /// the last approval the server reported ([markApprovedByServer]).
  static bool _freshClaimRead = false;

  /// Bumped by [forgetVerification]. A claim read started under an older
  /// generation answers for a session that has ended, and is dropped (N6).
  static int _claimGeneration = 0;

  /// Where the claim and the server state are read from. Replaced in tests.
  @visibleForTesting
  static VerificationBackend verificationBackend =
      const FirebaseVerificationBackend();

  /// How long [readVerificationClaim] waits for a token.
  static const Duration claimTimeout = Duration(seconds: 3);

  /// Re-reads the `verified` custom claim from her ID token.
  ///
  /// Called from `main()` through [readVerificationAtLaunch], after
  /// `FirebaseBoot.start()`, so the answer is already in hand by the time the
  /// first route is generated: [onGenerateRoute] is synchronous and cannot
  /// wait for a token.
  ///
  /// Never throws and never waits more than [claimTimeout] for the token. A
  /// fresh `true` is remembered for this uid on this phone; a fresh `false`
  /// forgets it. A token that cannot be read for a network reason falls back
  /// to that memory, or to a cached `approved` state; any other failure, no
  /// user, or no memory leaves her unverified. Assuming verified on a bare
  /// failed read would be a women-only gate that opens whenever the network
  /// is bad.
  static Future<void> readVerificationClaim() async {
    final backend = verificationBackend;
    final generation = _claimGeneration;
    _verifiedOnThisPhone = false;
    final remembered = await VerificationMemory.verifiedUid();
    if (!backend.isReady) {
      // No Firebase on this phone today. Her product is local-first, and a
      // phone that proved her verified before opens it again (R1), but only
      // for the account last signed in on it (N5).
      _verifiedClaim = false;
      _verifiedOnThisPhone =
          remembered != null &&
          remembered == await VerificationMemory.lastSignedInUid();
      return;
    }
    final uid = backend.currentUid;
    if (uid == null) {
      _verifiedClaim = false;
      await VerificationMemory.forgetSignedIn();
      return;
    }
    await VerificationMemory.rememberSignedIn(uid);
    try {
      final verified = await backend.verifiedClaim().timeout(claimTimeout);
      if (!_stillAbout(uid, generation)) return;
      _verifiedClaim = verified;
      _freshClaimRead = true;
      if (verified) {
        await VerificationMemory.rememberVerified(uid);
      } else if (remembered == uid) {
        await VerificationMemory.forget();
      }
    } catch (error) {
      if (!_stillAbout(uid, generation)) return;
      _verifiedClaim = false;
      if (!isUnreachableFailure(error)) return;
      if (remembered == uid) {
        _verifiedOnThisPhone = true;
        return;
      }
      try {
        final cached = await backend.cachedStatus(uid);
        if (cached != null) serverVerification = cached;
      } catch (_) {}
    }
  }

  /// Everything about her check that `main()` reads before the first frame,
  /// bounded by [bound] as a whole. Whatever is still running when it runs
  /// out finishes in the background and lands in the same fields.
  static Future<void> readVerificationAtLaunch({
    Duration bound = const Duration(seconds: 5),
  }) async {
    if (await _openFromMemoryThenConfirm()) return;
    try {
      await () async {
        await readVerificationClaim();
        // A token that carries the claim decides the gate on its own
        // ([gateDestination] lets a verified woman through whatever the
        // status says), so for her the status read waits for after the first
        // frame: one round trip less on every launch of a verified member.
        if (_verifiedClaim) {
          unawaited(readVerificationStatus());
          return;
        }
        await readVerificationStatus();
      }().timeout(bound);
    } catch (_) {
      // Out of time. The claim read is bounded on its own, so its fallback
      // has already been applied.
    }
  }

  /// The fast launch for a woman this phone already knows (D44): it
  /// remembered her verified ([VerificationMemory]) AND the on-device copy of
  /// her check, read with no network (about a second at most), says
  /// `approved`. Both must agree, for the account signed in right now, or this
  /// returns false and the full read above runs as before.
  ///
  /// Then the first frame does not wait for a token: the gate opens on the
  /// same evidence the offline launch already accepts (R1), and the real
  /// claim is read right behind it. [_settleClaim] applies it, so a claim that
  /// has been revoked closes the gate and the widgets, and the server rules
  /// read the real claim on every request whatever the phone believed.
  static Future<bool> _openFromMemoryThenConfirm() async {
    final backend = verificationBackend;
    if (!backend.isReady) return false;
    final uid = backend.currentUid;
    if (uid == null) return false;
    try {
      if (await VerificationMemory.verifiedUid() != uid) return false;
      final cached = await backend.cachedStatus(uid);
      if (cached?.state != ServerVerificationState.approved) return false;
      serverVerification = cached;
    } catch (_) {
      return false;
    }
    final generation = _claimGeneration;
    _verifiedOnThisPhone = true;
    unawaited(_confirmRememberedLaunch(uid, generation));
    return true;
  }

  static Future<void> _confirmRememberedLaunch(
    String uid,
    int generation,
  ) async {
    try {
      final verified = await verificationBackend.verifiedClaim().timeout(
        claimTimeout,
      );
      _settleClaim(uid, verified, generation);
    } catch (error) {
      if (!_stillAbout(uid, generation)) return;
      if (!isUnreachableFailure(error)) {
        // Not the network: the same refusal the full read makes. The memory
        // and the cached approval no longer speak for her, and the widgets
        // follow the gate.
        final wasVerified = isVerified;
        _verifiedOnThisPhone = false;
        serverVerification = null;
        if (wasVerified != isVerified) AppChanges.bump();
        return;
      }
      // No network or no answer: the memory stands, as it does offline.
    }
    if (!_stillAbout(uid, generation)) return;
    await readVerificationStatus();
  }

  /// How long the reads after a confirmed code may take, all together.
  @visibleForTesting
  static const Duration afterSignInCap = Duration(seconds: 8);

  /// Everything read once her code is accepted, side by side under one cap:
  /// her claim, her check's status and the legal versions she accepted (M1).
  /// They used to run one after another, so three slow round trips added up.
  /// The acceptance she made at C06 goes to the server here; if it cannot be
  /// shown to cover the versions in force, `legalUpdateDue` says so and she
  /// answers the legal update sheet before anything else.
  ///
  /// Whatever is still running when the cap is reached finishes in the
  /// background and lands in the same fields. A legal read that never landed
  /// is asked again at the next launch ([checkLegalAtLaunch]), and the gate
  /// still fails closed on a claim not yet read. Never throws.
  static Future<void> readAfterSignIn({Duration cap = afterSignInCap}) async {
    try {
      await Future.wait<void>([
        readVerificationClaim(),
        readVerificationStatus(),
        reconcileLegal(),
      ]).timeout(cap);
    } catch (_) {
      // Out of time or a read failed; each read is safe to leave unfinished.
    }
  }

  /// Retries the token refresh when the server says approved, or this phone
  /// remembers her verified, but the token in hand does not carry the claim.
  /// Called on resume. Never throws.
  static Future<void> refreshVerificationIfOwed() async {
    if (_verifiedClaim) return;
    final backend = verificationBackend;
    if (!backend.isReady || backend.currentUid == null) return;
    if (serverVerification?.state != ServerVerificationState.approved &&
        !_verifiedOnThisPhone) {
      return;
    }
    await refreshVerificationClaim();
  }

  static StreamSubscription<Object?>? _tokenWatch;

  /// Follows every new ID token, so a refresh Firebase makes by itself once
  /// she is back online carries the claim into the gate. Called once from
  /// `main()`.
  static void watchVerificationToken() {
    unawaited(_tokenWatch?.cancel());
    _tokenWatch = verificationBackend.tokenChanges().listen(
      (_) => unawaited(_rereadClaimQuietly()),
      onError: (Object _) {},
    );
  }

  static Future<void> _rereadClaimQuietly() async {
    final backend = verificationBackend;
    final uid = backend.currentUid;
    if (!backend.isReady || uid == null) return;
    final generation = _claimGeneration;
    try {
      final verified = await backend.verifiedClaim().timeout(claimTimeout);
      _settleClaim(uid, verified, generation);
    } catch (_) {
      // Unreadable now: nothing changes.
    }
  }

  /// Whether a read started for [uid] under [generation] still speaks for the
  /// session in hand: nobody forgot her verification since, and the same uid
  /// is signed in.
  static bool _stillAbout(String uid, int generation) =>
      generation == _claimGeneration && verificationBackend.currentUid == uid;

  /// A claim read from a token the server just issued, for [uid], started
  /// under [generation]. A stale read changes nothing (N6).
  static void _settleClaim(String uid, bool verified, int generation) {
    if (!_stillAbout(uid, generation)) return;
    final wasVerified = isVerified;
    _verifiedClaim = verified;
    _freshClaimRead = true;
    // The gate moved: the widgets open or close with it (home_widget_sync).
    if (isVerified != wasVerified) AppChanges.bump();
    // Just verified: the exercise library she could not read until now.
    if (isVerified && !wasVerified) {
      unawaited(ExerciseLibraryState.instance.refresh());
    }
    unawaited(VerificationMemory.rememberSignedIn(uid));
    if (verified) {
      unawaited(VerificationMemory.rememberVerified(uid));
    } else {
      _verifiedOnThisPhone = false;
      unawaited(VerificationMemory.forgetVerified());
    }
  }

  /// Every source of "she is verified" back to nothing (R2): the claim, the
  /// session result, the server state, the phone's memory and the review
  /// flags. Called on sign-out and on account deletion.
  static Future<void> forgetVerification() async {
    _claimGeneration++;
    _verifiedClaim = false;
    _verifiedOnThisPhone = false;
    _freshClaimRead = false;
    lastVerification = null;
    serverVerification = null;
    awaitingReviewer = false;
    reviewAsked = false;
    OnboardingState.instance
      ..beforeSignup = false
      ..shortSetupAfterSignup = false
      ..whileWaiting = false;
    await VerificationMemory.forget();
  }

  /// The route she should be on instead of [screenId], or null to let her
  /// through.
  ///
  /// In the shipped build `Feature.accountRequired` is on, so every product
  /// screen answers with the sign-up chain until she is verified.
  static String? verificationGate(String screenId) => gateDestination(
    screenId,
    gateClosed: featureFlags.isOn(Feature.accountRequired),
    signedIn: signedInUid != null,
    verified: isVerified,
    waitingOnAReviewer: awaitingReviewer,
  );

  /// The gate's decision, as a function of the four facts it turns on.
  ///
  /// Split out from [verificationGate] so the decision can be proved for a
  /// woman who is signed in, and for one waiting on a video call, in a test
  /// binary where neither state can be produced: `authRepository` is a real
  /// `FirebaseAuthRepository` and there is no Firebase behind it, so
  /// [signedInUid] is always null there. The alternative was a settable uid on
  /// the router, which is a way into the product that exists only for tests —
  /// and this file is not where one of those belongs. This function reads its
  /// inputs and holds no state, so proving it proves the gate.
  @visibleForTesting
  static String? gateDestination(
    String screenId, {
    required bool gateClosed,
    required bool signedIn,
    required bool verified,
    required bool waitingOnAReviewer,
  }) {
    if (!gateClosed) return null;
    if (!behindVerification(screenId)) return null;
    if (verified) return null;

    // Where she goes instead. Not a wall: every one of these is a screen she
    // can act on.
    //
    //   * signed out — `C01`, the front door, because there is no account to
    //     verify yet.
    //   * waiting on a person — `C14`, which says a woman will call and that
    //     the app opens when the check is done. Sending her back to "here is
    //     why we check" would read as though the check she completed never
    //     happened.
    //   * otherwise — `C09b`, the check itself, which is the one thing
    //     standing between her and the app. It opens with C09's promise and
    //     carries C09's niqab link, so she reads it once, on one screen.
    final id = switch ((signedIn, waitingOnAReviewer)) {
      (false, _) => 'C01',
      (_, true) => 'C14',
      _ => 'C09b',
    };
    return appDestinations[id]?.name;
  }

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

  /// Whether this build may carry the affordances that exist only for walking
  /// the product: the index of every screen, the sign-in code printed on the
  /// screen that asks for it, the test payment rail.
  ///
  /// They used to key off [Feature.accountRequired] alone. They now need a
  /// debug build as well, so no flag and no runtime switch can turn them on in
  /// a release. `accountRequired` ships on, so this getter is false in every
  /// build of the shipped configuration, debug included; it is true only in a
  /// debug build of a configuration with no account required, such as
  /// [FeatureFlags.everything].
  ///
  /// # `Feature.accountRequired` is on in the shipped build
  ///
  /// It is the switch that closes the whole app: [verificationGate] refuses
  /// every product route to an account that has not passed the check, which is
  /// the gate the owner asked for, and it ships on (2026-10-02). With it on,
  /// this getter is false in every build, so no testing aid can appear.
  ///
  /// The order of the release steps still matters. A build with this on, run
  /// against a project where `functions/` is not deployed, locks out every
  /// woman, silently: `start_verification` and `verify_identity` would answer
  /// `not-found` and everyone would wait on `C14` for a call nothing books.
  /// So: deploy the functions, verify one real account end to end against
  /// them, and only then release this build.
  static bool get testingAidsAllowed =>
      kDebugMode && !featureFlags.isOn(Feature.accountRequired);

  /// Screens that actually exist. Everything absent renders [NotBuiltYet], so
  /// the gap between what is designed and what is built is visible rather than
  /// guessed at — and this map is the honest measure of progress.
  static final Map<String, WidgetBuilder> _built = {
    // "Show me around" opens the tour (`C04`): the real screens with a sample
    // week, before she is asked for anything. "Skip the tour and join" is the
    // value-first start without it: her week before her number. The short
    // setup (`O03`, then `O05`) is open before verification, so the gate is
    // untouched; a woman who already built her week and closed the app goes
    // straight back to it. The language is two chips on this screen, so a
    // first run no longer passes `C02`.
    //
    // One literal `goTo` per destination, so `nav_reachability_test` can see
    // both edges (see the note at Y03's tabs).
    'C01': (context) => WelcomeView(
      preference: localePreference,
      onLookAround: () => goTo(context, 'C04'),
      // "Skip the tour and join" is in the More sheet and opens the pitch
      // (C03), whose button starts her week. With C03 off it starts her week
      // itself, so the way in is never lost.
      onWhatsInside: () {
        if (!screenIsOn('C03')) {
          OnboardingState.instance
            ..beforeSignup = true
            ..whileWaiting = false;
          unawaited(
            analytics.track(AnalyticsEvent.signUpStarted, {
              AnalyticsProp.source: const AnalyticsValue.token('welcome'),
            }),
          );
          if (intakeRepository.setupDone) {
            goTo(context, 'O05');
          } else {
            goTo(context, 'O03');
          }
          return;
        }
        goTo(context, 'C03');
      },
      onSignIn: () => goTo(context, 'C06'),
      // While the coach app is off a coach is not asked at C08, so she says
      // so here and the team hears from her (R1-P25). While it is on, a woman
      // her coach invited keeps the code for after her check (R1-P18).
      onCoachInterest: featureFlags.isOn(Feature.coachApp)
          ? null
          : () => showCoachInterestSheet(context, open: openOutside),
      onInviteCode: featureFlags.isOn(Feature.coachApp)
          ? () => unawaited(keepInviteCode(context))
          : null,
      // Her week, built before sign-up, stays on this phone if she stops
      // there. This is the way to remove it without an account: the same
      // wipe as A02's, then the front door again, drawn from empty.
      onDeleteSaved: intakeRepository.setupDone && signedInUid == null
          ? () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.maybeOf(context);
              final done = AppL10n.of(context).deletedFromThisPhone;
              await deleteEverythingOnThisPhone();
              OnboardingState.instance.beforeSignup = false;
              if (!navigator.mounted) return;
              unawaited(
                navigator.pushNamedAndRemoveUntil(
                  appRoutes['C01']!.name,
                  (_) => false,
                ),
              );
              showHonestNoticeOn(messenger, done);
            }
          : null,
    ),
    // Reached from her profile: the language is two chips on C01, so a first
    // run never passes it (`ungatedScreens`). For a signed-in woman
    // "Continue" is "done" and goes back where she came from. It used to
    // continue to C03, "What's inside / Create my account", which told a
    // signed-in, verified woman to create the account she was already using.
    // Only with no account does it still lead on to the pitch.
    'C02': (context) => LanguageView(
      preference: localePreference,
      onBack: () => Navigator.of(context).maybePop(),
      // Before she has an account, Skip goes straight to sign-in, and is not
      // drawn while sign-in is switched off.
      onSkip: signedInUid == null && screenIsOn('C06')
          ? () => goTo(context, 'C06')
          : null,
      onContinue: screenIsOn('C03') && signedInUid == null
          ? () => goTo(context, 'C03')
          : () => Navigator.of(context).maybePop(),
    ),
    'C03': (context) => WhatsInsideView(
      // The value-first start: her week, then her number. It used to be C01's
      // "Skip the tour and join"; C03 is where the pitch is, so it lives here.
      onCreateAccount: () {
        OnboardingState.instance
          ..beforeSignup = true
          ..whileWaiting = false;
        unawaited(
          analytics.track(AnalyticsEvent.signUpStarted, {
            AnalyticsProp.source: const AnalyticsValue.token('welcome'),
          }),
        );
        if (intakeRepository.setupDone) {
          goTo(context, 'O05');
        } else {
          goTo(context, 'O03');
        }
      },
      onLookAround: () => goTo(context, 'C04'),
      onSkip: screenIsOn('C06') ? () => goTo(context, 'C06') : null,
      onBack: () => Navigator.of(context).maybePop(),
    ),
    // The tour: the real Home, Train, Eat, My cycle and Progress screens with
    // a sample week, before she has an account. It is in the `signup` flow,
    // so the gate is untouched: the tour builds those screens itself, inside
    // `DemoScope`, and never routes to one. See `look_around_view.dart`.
    //
    // Every exit is built here, above the scope, so none of them is caught by
    // it. "Join" and "Make it mine" start the same value-first sign-up as
    // C01's "Skip the tour and join": her week, then her number. Back from
    // `O03` returns her to the stop she left, because the tour stays under it.
    //
    // Opened from C14 too, by a woman already signed up and waiting on her
    // check. "Join" must not start sign-up over again for her: it reads
    // "Back to my check" and returns her there. `pop` rather than `maybePop`
    // for the exits, because the tour holds system back to walk its stops.
    //
    // The ids stay written out here, not in `_lookAround`, so the navigation
    // graph `nav_reachability_test` reads still sees these edges.
    'C04': (context) => _lookAround(
      context,
      toSignUp: () => intakeRepository.setupDone
          ? goTo(context, 'O05')
          : goTo(context, 'O03'),
      toSignIn: () => goTo(context, 'C06'),
    ),
    // C05 is C04 with the join sheet raised, not a separate page. The route
    // exists so the design can be reviewed screen by screen, and shares C04's
    // exits, so a woman waiting on her check is never sent to sign up again.
    'C05': (context) => _lookAround(
      context,
      openJoinPrompt: true,
      toSignUp: () => intakeRepository.setupDone
          ? goTo(context, 'O05')
          : goTo(context, 'O03'),
      toSignIn: () => goTo(context, 'C06'),
    ),
    // Her tap here is the acceptance of the Terms and the Privacy Policy
    // (M1), written to this phone before the code is sent and to the server
    // once the code is accepted. The documents open in her language.
    //
    // Usage statistics ("Help improve Own Hub") are a second optional switch
    // here, separate from crash reports and from the acceptance, off unless
    // she turns it on. Applied before the code is sent, so her own sign-up
    // is counted from the next step only if she said yes.
    'C06': (context) => PhoneNumberView(
      repository: authRepository,
      onCodeSent: () {
        unawaited(analytics.track(AnalyticsEvent.signUpCodeSent));
        goTo(context, 'C07');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onOpenTerms: openTermsFor(context),
      onOpenPrivacy: openPrivacyFor(context),
      crashReportsInitially: CrashConsent.instance.allowed,
      onCrashReportsChosen: CrashConsent.instance.set,
      analyticsInitially: AnalyticsConsent.instance.allowed,
      onAnalyticsChosen: AnalyticsConsent.instance.set,
    ),
    'C07': (context) => CodeView(
      repository: authRepository,
      // Only while no account is required, like every other test affordance.
      // Against a real provider there is no such code and none is claimed.
      testCode: testingAidsAllowed ? testCodeOf(authRepository) : null,
      // A woman who is already verified (signing in again, or on a new phone)
      // is not sent through the ID check a second time. Her claim and her
      // server state are read now, since they were read at launch for a
      // different sign-in. Setup is walked only if it is not done here, which
      // is the case on a new phone with the health backup off (N2): her life
      // stage did not travel, so she is asked.
      //
      // With the coach app off there is one role to choose, so `C08` is not
      // asked: she is a trainee, the check begins here, and she goes straight
      // to the one screen that explains it and asks for her agreement.
      onConfirmed: () async {
        final navigator = Navigator.of(context);
        // She has an account now: the short setup is no longer "before".
        OnboardingState.instance.beforeSignup = false;
        await readAfterSignIn();
        // Firebase's recommended `sign_up` for an account new to the check,
        // `login` for a woman already verified. The method is the only
        // parameter, and it is always the phone.
        unawaited(
          analytics.track(
            isVerified
                ? AnalyticsEvent.loggedIn
                : AnalyticsEvent.signUpCompleted,
            {AnalyticsProp.method: const AnalyticsValue.token('phone')},
          ),
        );
        if (!navigator.mounted || !context.mounted) return;
        if (!await answerLegalUpdate(context)) return;
        // A returning verified woman with her backup on has her setup in the
        // cloud. One bounded pull first, so she is not walked through setup
        // again on a new phone (R9).
        if (isVerified) await pullBeforeSetupChoice();
        // A verified woman on a new phone: the side of the app she holds,
        // from the server's copy (R1-P17). Only while there is a coach side.
        if (!context.mounted) return;
        if (isVerified) await restoreRolesFromServer(context);
        if (!navigator.mounted || !context.mounted) return;
        if (!isVerified && featureFlags.isOn(Feature.coachApp)) {
          goTo(context, 'C08');
        } else if (!isVerified) {
          lastSignupRole = SignupRole.trainee;
          RoleScope.maybeOf(context)?.value = SignupRole.trainee.toRoles();
          beginIdentityCheck();
          goTo(context, 'C09b');
        } else if (frontDoor != appRoutes['T01']!.name) {
          // A coach opens on her own side: K01 until her setup is in, K07
          // after. Setup questions are a trainee's, so they are not asked.
          navigator.pushNamedAndRemoveUntil(frontDoor, (_) => false);
        } else if (intakeRepository.setupDone) {
          navigator.pushNamedAndRemoveUntil(
            appRoutes['T01']!.name,
            (_) => false,
          );
        } else {
          OnboardingState.instance.enteredFromSignup = true;
          goTo(context, 'O01');
        }
      },
      // "Send it again" has to answer. In this build nothing is sent, so the
      // answer names the code instead of promising a message.
      onResent: () {
        unawaited(
          analytics.track(AnalyticsEvent.codeResent, {
            AnalyticsProp.outcome: const AnalyticsValue.token('sent'),
          }),
        );
        showHonestNotice(context, switch (featureFlags.isOn(
              Feature.accountRequired,
            )
            ? null
            : testCodeOf(authRepository)) {
          final code? => AppL10n.of(context).testBuildNoTextMessageIsSent(code),
          null => AppL10n.of(context).aNewCodeIsOnItsWay,
        });
      },
      onResendRefused: () {
        unawaited(
          analytics.track(AnalyticsEvent.codeResent, {
            AnalyticsProp.outcome: const AnalyticsValue.token('limit'),
          }),
        );
        showHonestNotice(
          context,
          AppL10n.of(context).tooManyTriesWaitAMinuteThen,
        );
      },
      onBack: () => Navigator.of(context).maybePop(),
      onEditNumber: () => Navigator.of(context).maybePop(),
    ),
    // Her answer is carried, not discarded: a coach and a client are verified
    // the same way here, but the role decides where C13 sends her afterwards.
    'C08': (context) => RoleView(
      // No coach or "both" answer while the coach app is off: it would lead
      // to K01 saying the feature is off.
      offerCoach: featureFlags.isOn(Feature.coachApp),
      onContinue: (role) {
        lastSignupRole = role;
        // Writes into the app-level scope, so the navigation she sees after
        // sign-up is already hers (D11). In production `roles.held` is
        // server-written — this is the local echo of what the sign-up call
        // records, and picking "coach" still earns nothing until the coach
        // application and its certificate checks pass.
        RoleScope.maybeOf(context)?.value = role.toRoles();
        // Kept past a relaunch on this phone, and on the server for a new
        // one (R1-P17). The server copy is best effort: the phone's stands.
        RoleState.instance.keep(role.toRoles());
        if (signedInUid != null) {
          unawaited(roleRecordStore.record(role).catchError((Object _) {}));
        }
        // The check begins here rather than at the first camera: C09 is already
        // part of it, and the niqab path leaves from C09 without ever opening a
        // lens. One [IdentityCheck] now covers everything from "why we check"
        // to the decision, whichever way she goes.
        beginIdentityCheck();
        goTo(context, 'C09');
      },
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'C09': (context) => WhyWeCheckView(
      // Not straight to the camera. `C09b` is the consent step, and it is the
      // only door into `C10`: her agreement to where her face and her national
      // ID go is written down before a lens opens, never after.
      // C09b repeats this screen's promise for a woman who arrives there
      // straight, so from here it is told not to: one promise, read once.
      onScanId: () =>
          Navigator.of(context)
              .pushNamed(appRoutes['C09b']!.name, arguments: _fromWhyWeCheck),
      // The niqab path. Nothing on this route may ask for a selfie.
      onNiqabPath: () {
        pendingReviewPath = ReviewPath.niqab;
        goTo(context, 'C15');
      },
      onBack: () => Navigator.of(context).maybePop(),
    ),
    // The consent step, between "one check and you are in" and the first lens.
    //
    // The uid is hers when she is signed in, and the stand-in otherwise, which
    // is what a walk through this flow with no account required produces. A
    // record written against the stand-in is written into the in-memory store
    // (see `_newIdentityCheck`), so it is a rehearsal and not a consent record
    // claiming to be about somebody.
    //
    // It opens with C09's promise (what is read, what is matched, how long),
    // so the first run is one screen, not two. The disclosure under it is the
    // v2 text, every bullet visible. The niqab path leaves from here too.
    'C09b': (context) => ConsentView(
      uid: signedInUid ?? _selfUid,
      store: identityCheck.consent,
      showPromise:
          ModalRoute.of(context)?.settings.arguments != _fromWhyWeCheck,
      title: signupPhaseLabel(AppL10n.of(context), SignupPhase.check),
      onOpenPrivacy: openPrivacyFor(context),
      onNiqabPath: () {
        pendingReviewPath = ReviewPath.niqab;
        goTo(context, 'C15');
      },
      // Only ever after the write returned. `ConsentView` enforces that half;
      // this records it for the guard in `onGenerateRoute`, so a deep link
      // straight to `/signup/c10` cannot skip the screen she just agreed on.
      onAgreed: () {
        consentRecorded = true;
        unawaited(analytics.track(AnalyticsEvent.checkConsentGiven));
        goTo(context, 'C10');
      },
      // "I would rather not" is a real answer, and it leads somewhere: a woman
      // reviewer, no camera, no processor outside Egypt.
      onDeclined: () {
        pendingReviewPath = ReviewPath.declined;
        goTo(context, 'C15');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSignInAgain: () => unawaited(signInAgain(context)),
    ),
    // Both sides of the card, in two passes of one screen.
    //
    // The capture service comes from [identityCheck], never from a fresh one:
    // `C10` and `C10b` fill the same `VerificationEvidence` that `C12` submits.
    // Two services would mean two evidence holders, and the failure would
    // surface three files away as "the server says the card is missing".
    //
    // A camera that cannot run is never a dead end: "Open settings" when she
    // turned access off, "Try again" otherwise, and on either a woman reviewer
    // with no camera. Whatever was photographed so far is dropped first.
    'C10': (context) => IdCaptureView(
      captureService: identityCheck.capture,
      onUnavailable: _trackCameraUnavailable,
      onCaptured: () => goTo(context, 'C10b'),
      onClose: () => Navigator.of(context).maybePop(),
      onOpenSettings: () => unawaited(openAppSettings()),
      onAskReviewer: (reason) {
        identityCheck.evidence.shred();
        pendingReviewPath = reason == CaptureUnavailableReason.permissionDenied
            ? ReviewPath.declined
            : ReviewPath.error;
        goTo(context, 'C15');
      },
    ),
    // The back. It prints her sex as a word, أنثى or ذكر, which is the
    // independent reading the 13th digit of the number is cross-checked
    // against — and `verify_identity` refuses a submission carrying only one
    // side, so skipping this pass is a call that cannot be answered.
    //
    // The liveness session is minted HERE, on the way out, and not before
    // `C10`. It expires on a wall clock measured in a minute or two, and
    // starting it while she is still finding the card in her bag spends most of
    // it on the two card steps. `startLiveness` is what hands the one
    // server-chosen challenge to the capture service and the repository
    // together.
    'C10b': (context) => IdCaptureView(
      captureService: identityCheck.capture,
      side: CaptureTarget.idBack,
      onUnavailable: _trackCameraUnavailable,
      // Written out here rather than in a helper, because the two destinations
      // have to be visible in this map: `nav_reachability_test` recovers the
      // navigation graph from the literal ids each builder mentions, and an
      // edge hidden inside a function is an edge no measurement can see. The
      // Cycle tabs are commented at the foot of this file for the same reason.
      onHandOff: () async {
        final navigator = Navigator.of(context);
        final started = await identityCheck.startLiveness();
        _trackLivenessStart(started);
        // She can close the capture while the call is in flight, and pushing
        // onto a dead navigator throws.
        if (!navigator.mounted || !context.mounted) {
          return CaptureHandOff.moved;
        }
        final repository = identityCheck.verificationRepository;
        switch (started) {
          case LivenessStart.started:
            _livenessOffline = 0;
            goTo(context, 'C11');
          case LivenessStart.offline:
            // A dropped connection is a retry, not a review. Her photographs
            // stay where they are, and after two retries that fail too a
            // woman reviewer is offered beside "Try again".
            _livenessOffline++;
            return _livenessOffline >= 3
                ? CaptureHandOff.offlineOfferReviewer
                : CaptureHandOff.offline;
          case LivenessStart.failed:
            // No session, so there is nothing for a selfie to answer. She is
            // offered the woman reviewer rather than spending two minutes on
            // frames the server has no challenge to score.
            pendingReviewPath = ReviewPath.error;
            goTo(context, 'C15');
          case LivenessStart.tryTomorrow:
          case LivenessStart.checksUsedUp:
          case LivenessStart.appCannotReach:
          case LivenessStart.signInAgain:
            // A limit, a copy of the app the server refuses, or a sign-in it
            // does not accept, told on C12 without submitting anything. Never
            // a review.
            identityCheck.evidence.shred();
            _automaticSubmitted = true;
            repository.settle(switch (started) {
              LivenessStart.tryTomorrow =>
                const VerificationState.tryTomorrow(),
              LivenessStart.checksUsedUp =>
                const VerificationState.checksUsedUp(),
              LivenessStart.signInAgain =>
                const VerificationState.signInAgain(),
              _ => const VerificationState.appCannotReach(),
            });
            goTo(context, 'C12');
          case LivenessStart.consentNeeded:
            consentRecorded = false;
            goTo(context, 'C09b');
          case LivenessStart.reviewOpen:
            identityCheck.evidence.shred();
            awaitingReviewer = true;
            goTo(context, 'C14');
          case LivenessStart.closed:
            identityCheck.evidence.shred();
            serverVerification = const ServerVerification(
              ServerVerificationState.rejected,
            );
            goTo(context, 'C14');
        }
        return CaptureHandOff.moved;
      },
      onClose: () => Navigator.of(context).maybePop(),
      onOpenSettings: () => unawaited(openAppSettings()),
      onAskReviewer: (reason) {
        identityCheck.evidence.shred();
        pendingReviewPath = reason == CaptureUnavailableReason.permissionDenied
            ? ReviewPath.declined
            : ReviewPath.error;
        goTo(context, 'C15');
      },
    ),
    'C11': (context) => SelfieCaptureView(
      captureService: identityCheck.capture,
      onUnavailable: _trackCameraUnavailable,
      onCaptured: () => goTo(context, 'C12'),
      onClose: () => Navigator.of(context).maybePop(),
      onOpenSettings: () => unawaited(openAppSettings()),
      onAskReviewer: (reason) {
        identityCheck.evidence.shred();
        pendingReviewPath = reason == CaptureUnavailableReason.permissionDenied
            ? ReviewPath.declined
            : ReviewPath.error;
        goTo(context, 'C15');
      },
    ),
    // The submit for the automatic path happens as this screen opens.
    //
    // Nothing called it before: `C15` submitted the niqab path and the
    // automatic path submitted nothing at all, so `C12` listened to a
    // repository that had never been asked a question and every woman who
    // photographed her card sat on the ring for ever. `_checkingRepository`
    // submits once per attempt and hands back the same repository the frames
    // were captured into.
    'C12': (context) => CheckingView(
      reassuringSteps: featureFlags.isOn(Feature.reassuringWaits),
      repository: _checkingRepository(),
      // C13 becomes the root: nothing of sign-up stays behind "You're in" for
      // a back gesture to find, the camera least of all.
      onVerified: (result) {
        _trackDecided('verified');
        _trackYoureIn('automatic');
        // Kept so C13 can state a measured duration instead of inventing one.
        lastVerification = result;
        unawaited(redeemPendingInvite());
        Navigator.of(context)
            .pushNamedAndRemoveUntil(appRoutes['C13']!.name, (_) => false);
      },
      // Both "waiting for a reviewer" and "needs another look" land on the
      // same screen. Neither is a rejection (DECISIONS.md D8).
      onAwaitingReviewer: () {
        _trackDecided('reviewer');
        awaitingReviewer = true;
        goTo(context, 'C14');
      },
      // `RETRY_CAPTURE` and `RETRY_REQUIRED`, and an expired liveness session,
      // all arrive here. Her move, not a reviewer's: both sides of the card
      // again, a fresh challenge before `C11`, and a fresh submit — which is
      // why the guard is lifted rather than left standing from the attempt
      // that asked her to do this.
      onRetake: () {
        _trackDecided('retake');
        _automaticSubmitted = false;
        goTo(context, 'C10');
      },
      // "Try again" on a slow check: her choice, so no decision is recorded.
      onTryAgain: () {
        _automaticSubmitted = false;
        goTo(context, 'C10');
      },
      // Refused for good. C14 says so plainly, with where to delete her data.
      onRejected: () {
        _trackDecided('rejected');
        serverVerification = const ServerVerification(
          ServerVerificationState.rejected,
        );
        goTo(context, 'C14');
      },
      // The server has no record of her agreement: ask again.
      onConsentNeeded: () {
        consentRecorded = false;
        _automaticSubmitted = false;
        goTo(context, 'C09b');
      },
      // No automatic checks left, a check that could not finish, or a slow
      // one. A reviewer only if she asks for one. C15 opens over this screen,
      // so a verdict that still arrives routes from here.
      onAskForReviewer: () {
        pendingReviewPath = ReviewPath.error;
        goTo(context, 'C15');
      },
      onAskForReviewerWhileChecking: () {
        pendingReviewPath = ReviewPath.error;
        reviewAskedWhileChecking = true;
        goTo(context, 'C15');
      },
      // The daily limit, or a copy of the app that cannot reach Own Hub. To
      // the front door computed now, with the sign-up stack cleared (R10):
      // Home for a signed-in woman, where the gate holds her at the check.
      // Popping to the first route put her on C01 "Get started" while signed
      // in.
      onClose: () {
        _automaticSubmitted = false;
        Navigator.of(context).pushNamedAndRemoveUntil(frontDoor, (_) => false);
      },
      onSignInAgain: () => unawaited(signInAgain(context)),
    ),
    // With the community off the primary is "Start day 1": her week over Home
    // when she built it before signing up, else the short "Your week" first
    // and then day one. The pledge waits for the community it is about.
    'C13': (context) => YoureInView(
      // Her measured time, or nothing at all. Null is the honest answer when
      // the check was never timed — this screen used to state the prototype's
      // 74 seconds as a fact about her own verification.
      verifiedInSeconds: lastVerification?.took?.inSeconds,
      onReadTheRules: () => goTo(context, 'C16'),
      onCoachSetup: () => goTo(context, 'K01'),
      isCoach:
          lastSignupRole == SignupRole.coach ||
          lastSignupRole == SignupRole.both,
      alsoTrains: lastSignupRole != SignupRole.coach,
      onStartDay1: () {
        final navigator = Navigator.of(context);
        if (intakeRepository.setupDone) {
          navigator.pushNamedAndRemoveUntil(
            appRoutes['T01']!.name,
            (_) => false,
          );
          navigator.pushNamed(appRoutes['R03']!.name);
          return;
        }
        OnboardingState.instance
          ..enteredFromSignup = true
          ..shortSetupAfterSignup = true
          ..whileWaiting = false;
        goTo(context, 'O03');
      },
      onGoHome: () =>
          Navigator.of(context)
              .pushNamedAndRemoveUntil(appRoutes['T01']!.name, (_) => false),
    ),
    // Nothing is open to her while she waits.
    //
    // This used to pass three callbacks — workouts, recipes, coach profiles —
    // from the model where a pending check closed only the community. The owner
    // has chosen the whole-app gate, so those rows would have been three doors
    // into screens [verificationGateCloses] now refuses. They are gone from the
    // widget as well as from here: a callback wired to nothing is a row waiting
    // to be drawn again by somebody who finds it.
    'C14': (context) => BeingCheckedView(
      status: serverVerification,
      // The week she built before signing up, so the wait has something of
      // hers on it.
      savedWeek: intakeRepository.setupDone
          ? herAnswersLine(
              AppL10n.of(context),
              intakeRepository.read(),
              placeAnswered: intakeRepository.placeAnswered,
            )
          : null,
      updates: verificationStatusUpdates(),
      // A reviewer approved her. `approved` from the server opens the product
      // by itself (R1); the token refresh is tried here and again on resume
      // and on reconnect, never only once, and a failed one does not hold her
      // on a "waiting" screen.
      onApproved: () {
        markApprovedByServer();
        _trackYoureIn('reviewer');
        unawaited(redeemPendingInvite());
        Navigator.of(context)
            .pushNamedAndRemoveUntil(appRoutes['C13']!.name, (_) => false);
      },
      onLookAround: () => goTo(context, 'C04'),
      // One push, "your check is done", only if she asks for it here.
      onNotifyMe: signedInUid == null
          ? null
          : () async {
              final locale = Localizations.localeOf(context).languageCode;
              final outcome = await pushRegistrar.optIn(
                uid: signedInUid!,
                locale: locale,
              );
              if (outcome == PushOptIn.on) unawaited(startPushWatch(locale));
              return outcome;
            },
      onOpenSettings: () => unawaited(openAppSettings()),
      // A woman waiting with no week of hers yet builds it here: the short
      // "Your week" (O03, O05), which ends back on this screen.
      onBuildWeek: intakeRepository.setupDone
          ? null
          : () {
              OnboardingState.instance
                ..beforeSignup = false
                ..shortSetupAfterSignup = true
                ..whileWaiting = true;
              goTo(context, 'O03');
            },
      // Straight to the check, which carries C09's promise and niqab link.
      onTryAgain: () {
        beginIdentityCheck();
        goTo(context, 'C09b');
      },
      onDeleteMyData: () => goTo(context, 'A02'),
      onSelectTab: (screenId) => goToTab(context, screenId),
      // R4: a flag the automatic check raised is not her asking for a call.
      reviewAsked: reviewAsked,
      requester: identityCheck.reviews,
      onAskedForCall: markReviewAsked,
      onSignInAgain: () => unawaited(signInAgain(context)),
    ),
    // Which path she chose matters operationally — a video check and a partner
    // gym cost very different things — so it is recorded rather than dropped.
    // G1 flagged that the two share one VerificationMethod today (F8).
    // She reaches C14 only after `request_review` answered. A failed call
    // keeps her here with an honest retry.
    'C15': (context) => WomanReviewerView(
      requester: identityCheck.reviews,
      path: pendingReviewPath,
      checkStillRunning: reviewAskedWhileChecking,
      onBooked: (path) {
        lastReviewerPath = path;
        markReviewAsked();
        awaitingReviewer = true;
        serverVerification = const ServerVerification(
          ServerVerificationState.pending,
        );
        goTo(context, 'C14');
      },
      // The server says she is already verified. That is evidence on its own
      // (R1): a refresh that fails must not put her on C14 pending (R10).
      onAlreadyVerified: () {
        markApprovedByServer();
        _trackYoureIn('reviewer');
        unawaited(redeemPendingInvite());
        Navigator.of(context)
            .pushNamedAndRemoveUntil(appRoutes['C13']!.name, (_) => false);
      },
      onRejected: () {
        serverVerification = const ServerVerification(
          ServerVerificationState.rejected,
        );
        goTo(context, 'C14');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSignInAgain: () => unawaited(signInAgain(context)),
    ),
    'C16': (context) => PledgeView(
      // Setup after sign-up ends on Home with the sign-up stack cleared, not
      // back on this pledge. See `OnboardingState.leaveSetup`.
      onAgree: () {
        recordPledge(context);
        OnboardingState.instance.enteredFromSignup = true;
        goTo(context, 'O01');
      },
      onBack: () => Navigator.of(context).maybePop(),
    ),

    // Setup. Every step writes to the SAME repository instance, or her answers
    // would not survive the walk from O01 to O05.
    //
    // `onClose` is the X in the corner, and it was passed by nobody: the button
    // rendered on all four questions and did nothing, so the one control that
    // promises she is not trapped in setup was the one control that could not
    // let her out. It leaves the walk now, exactly as the last step does —
    // `OnboardingState.leaveSetup` records that she has been asked, applies
    // whatever she answered, and pops back to the screen she came from (Home on
    // a first launch, A02 when she reopened the questions from her profile).
    // Back on the FIRST question is not a step backwards, it is the way out —
    // whether she got here on a fresh install (Home is underneath) or from her
    // profile (A02 is). So it leaves setup properly rather than popping
    // silently and asking her the same four questions on the next launch.
    // Every way out of O01 clears the sign-up flag, the system back gesture
    // included, so a later walk from A02 does not inherit it and end on
    // Home (N15).
    //
    // Skip is a text button in the top bar of every question. The answers are
    // all preselected, so it leaves with them standing: to Home, or, before she
    // has an account, to sign-in (C06), where the terms and the women-only
    // check still wait for her. See `OnboardingState.skipSetup`.
    'O01': (context) => PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) OnboardingState.instance.enteredFromSignup = false;
      },
      child: GoalView(
        repository: intakeRepository,
        onContinue: () => goTo(context, 'O02'),
        onSkip: () {
          OnboardingState.instance.skippingSetup = true;
          goTo(context, 'O04');
        },
        onBack: () => OnboardingState.instance.leaveSetup(context),
        onClose: () => OnboardingState.instance.leaveSetup(context),
      ),
    ),
    // Where she trains. Home alone adds one question about what she has there
    // (O06); a gym, or both, goes straight to her days.
    'O02': (context) => PlaceView(
      repository: intakeRepository,
      onContinue: () => intakeRepository.read().place == TrainingPlace.home
          ? goTo(context, 'O06')
          : goTo(context, 'O03'),
      onSkip: () {
        OnboardingState.instance.skippingSetup = true;
        goTo(context, 'O04');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onClose: () => OnboardingState.instance.leaveSetup(context),
    ),
    'O06': (context) => EquipmentView(
      repository: intakeRepository,
      onContinue: () => goTo(context, 'O03'),
      onSkip: () {
        OnboardingState.instance.skippingSetup = true;
        goTo(context, 'O04');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onClose: () => OnboardingState.instance.leaveSetup(context),
    ),
    // Days and minutes together, then what to train around. The full walk
    // reaches them after her goal and her place. The short "Your week" starts
    // here: before she has an account (from C01), or after her check when she
    // had not built her week yet (from C13 or C14). Before sign-up the bar
    // says "1 of 3 · Your week" and there is no X, because there is no Home to
    // close to; Skip goes to sign-in.
    'O03': (context) => OnboardingState.instance.shortSetup
        ? ScheduleView(
            repository: intakeRepository,
            titleOverride: _shortSetupTitle(context),
            onContinue: () => goTo(context, 'O04'),
            onSkip: () {
              OnboardingState.instance.skippingSetup = true;
              goTo(context, 'O04');
            },
            onBack: () => Navigator.of(context).maybePop(),
          )
        : ScheduleView(
            repository: intakeRepository,
            onContinue: () => goTo(context, 'O04'),
            onSkip: () {
              OnboardingState.instance.skippingSetup = true;
              goTo(context, 'O04');
            },
            onBack: () => Navigator.of(context).maybePop(),
            onClose: () => OnboardingState.instance.leaveSetup(context),
          ),
    // The life-stage question is the one Skip never bypasses, and it has no
    // Skip of its own: "Nothing right now" is the quick answer. When she got
    // here through a Skip, her answer here ends setup the way that Skip would
    // have: Home, back to the wait, or sign-in before she has an account.
    'O04': (context) => OnboardingState.instance.shortSetup
        ? LifeStageView(
            repository: intakeRepository,
            titleOverride: _shortSetupTitle(context),
            continueLabel: OnboardingState.instance.skippingSetup
                ? null
                : AppL10n.of(context).seeMyWeek,
            onContinue: () {
              if (OnboardingState.instance.skippingSetup) {
                OnboardingState.instance.skipSetup(
                  context,
                  toSignIn: () {
                    if (screenIsOn('C06')) goTo(context, 'C06');
                  },
                );
                return;
              }
              goTo(context, 'O05');
            },
            onBack: () => Navigator.of(context).maybePop(),
          )
        : LifeStageView(
            repository: intakeRepository,
            onContinue: () {
              if (OnboardingState.instance.skippingSetup) {
                OnboardingState.instance.skipSetup(
                  context,
                  toSignIn: () {
                    if (screenIsOn('C06')) goTo(context, 'C06');
                  },
                );
                return;
              }
              goTo(context, 'O05');
            },
            onBack: () => Navigator.of(context).maybePop(),
          ),
    // The end of the walk. All three doors leave setup first, so the questions
    // are gone from the history whichever one she takes and no back gesture can
    // walk her into them again.
    //
    // After sign-up (`enteredFromSignup`) she lands on Home with the sign-up
    // stack cleared: "Start tomorrow" gives `[T01]`, "Start now" `[T01, R03]`.
    //
    // Before sign-up it ends in "Save my week and join": her week is marked
    // done and her weekly target applied here, on the phone, and then she is
    // asked for her number. Nothing behind the gate opens.
    'O05': (context) => OnboardingState.instance.whileWaiting
        // Built while a reviewer has her check (from C14): saved, and back
        // to the wait. Day one opens with the app.
        ? StartingProgramView(
            showSteps: featureFlags.isOn(Feature.reassuringWaits),
            repository: intakeRepository,
            onBack: () => Navigator.of(context).maybePop(),
            title: '',
            onSaveMyWeek: () {
              OnboardingState.instance.finish();
              // whileWaiting is only set by C14's own button, so C14 is in
              // the stack: back to it by name, never to whatever is first.
              Navigator.of(context)
                  .popUntil(ModalRoute.withName(appRoutes['C14']!.name));
            },
          )
        : OnboardingState.instance.beforeSignup
        ? StartingProgramView(
            showSteps: featureFlags.isOn(Feature.reassuringWaits),
            repository: intakeRepository,
            beforeSignup: true,
            title: signupPhaseLabel(AppL10n.of(context), SignupPhase.week),
            onBack: () => Navigator.of(context).maybePop(),
            onSaveAndJoin: () {
              OnboardingState.instance.finish();
              unawaited(analytics.track(AnalyticsEvent.intakeCompleted));
              goTo(context, 'C06');
            },
          )
        : StartingProgramView(
            showSteps: featureFlags.isOn(Feature.reassuringWaits),
            repository: intakeRepository,
            onStartNow: () {
              if (OnboardingState.instance.enteredFromSignup) {
                OnboardingState.instance.leaveSetupToHome(
                  context,
                  home: 'T01',
                  then: 'R03',
                );
                return;
              }
              OnboardingState.instance.leaveSetup(context);
              goTo(context, 'R03');
            },
            onStartTomorrow: () {
              if (OnboardingState.instance.enteredFromSignup) {
                OnboardingState.instance.leaveSetupToHome(context, home: 'T01');
                return;
              }
              OnboardingState.instance.leaveSetup(context);
            },
            // Goes to the workout library, not a picker — no picker exists among
            // the 161 screens. Recorded as F4 in PHASE1-FINDINGS.md.
            onPickDifferentProgram: () {
              if (OnboardingState.instance.enteredFromSignup) {
                OnboardingState.instance.leaveSetupToHome(
                  context,
                  home: 'T01',
                  then: 'R11',
                );
                return;
              }
              OnboardingState.instance.leaveSetup(context);
              goTo(context, 'R11');
            },
          ),

    // Today. T06 is a state inside T01, never a route. T08 is a state inside
    // T07 too, and is built below anyway: see the note at its entry.
    'T01': (context) => TodayView(
      repository: todayRepository,
      // What her plan calls today's session, or nothing. Home's cover was the
      // fixed `l10n.legsAndGlutes` while Train, one tap away, named
      // "Postpartum rebuild" — two names for one programme, neither of them
      // hers. Null until a plan says otherwise, and the card then heads itself
      // "Today's workout" rather than naming a programme she never chose.
      //
      // `trainRepository.day` is never set, so this was always null and the
      // cover always read "Today's workout". It is the session R03 will open:
      // her pick from the library, or the bundled one.
      sessionTitle:
          (chosenWorkoutDay(context) ?? sampleWorkoutDay(AppL10n.of(context)))
              .title,
      // D37 and D38: one line each under the week's marks, when they are on
      // and have something true to say.
      // Reminders on her training days, offered once as one line after a
      // session she finished. "Not now" is an answer: the offer is not made
      // again, and Notifications (A01) keeps the way in.
      offerReminders:
          featureFlags.isOn(Feature.trainingReminders) &&
          ReminderState.instance.offerDue,
      onChooseReminderDays: () => unawaited(openTrainingReminders(context)),
      onDismissReminderOffer: () {
        ReminderState.instance.offered = true;
        AppChanges.bump();
      },
      trainingStreak: trainingStreakNow,
      onOpenStreak: () => unawaited(openTrainingStreak(context)),
      challengeLine: challengeLineFor(
        context,
        chosenWorkoutDay(context) ?? sampleWorkoutDay(AppL10n.of(context)),
      ),
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
      // Eat, where day one offers one-tap starter plates. It opened E02, a
      // blank field to type into, which is the slowest way to log a meal.
      onTellUsWhatYouEat: () => goTo(context, 'E01'),
      onOpenBeginnersGroup: () => goTo(context, 'M01'),
      // Day one names her week and offers the two things she came for besides
      // training: planning dinners, and her cycle.
      intake: intakeRepository.read(),
      intakePlaceAnswered: intakeRepository.placeAnswered,
      onOpenWeekPlan: () => goTo(context, 'E07'),
      offerCycleSetup:
          cycleRepository.current == null &&
          !OnboardingState.instance.cycleRowDismissed,
      onTrackCycle: () => goTo(context, 'Y01'),
      onNotNowCycle: () {
        OnboardingState.instance.cycleRowDismissed = true;
        AppChanges.bump();
      },
      // The owner's next event, when Feature.events is on and one is planned.
      nextEvent: EventsState.instance.upcoming.firstOrNull,
      onOpenEvents: () => goTo(context, 'T09'),
      // The bottom bar on the app's landing tab. Without this, TodayView's
      // AppNavBar had nothing to call and tapping Train, Community or Eat from
      // Home did nothing at all — on the first screen she sees after sign-up.
      // app_nav_bar_test.dart could not catch it: it builds the bar directly
      // and supplies its own onSelect.
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'T02': (context) => AlreadyDidItView(
      repository: todayRepository,
      // The line under "Legs and glutes, today's plan" is the plan's own
      // summary, read off the one authored session. It was a fixed
      // "15 min · 5 moves · last week's weights" — a claim about weights from a
      // week she may not have trained — and the router passed nothing.
      //
      // There is deliberately no `lastOtherTitle`: nothing here knows what her
      // last other session was called, so T02 draws no second row rather than
      // offering "Upper body, like last Thursday" and writing it into her log.
      plannedDetail: sampleWorkoutDay(AppL10n.of(context)).summary,
      // A session she did without her phone counts the same everywhere a
      // trained one does. Today's own copy is credited by the repository
      // above; this credits the week document and her points.
      //
      // **The id is the session's own, not one invented here.** It used to be
      // `recalled-<day>`, one per day, while Today keyed its copy per row
      // (`-planned`, `-other`, `-time<minutes>`). Both sides deduped and the
      // two still came apart, because they were deduping different things: a
      // planned session and a walk on one day was 2 on Home and 1 on Progress.
      // Counted weeks and tier standing come off Progress, so Home was the one
      // lying. Same id, same ledger.
      onLogged: (session) {
        unawaited(noteSessionLogged());
        lastRecallOutcome = WorkoutSessionState.creditSession(
          sessionId: session.id,
          source: SessionSource.recalled,
          today: todayRepository,
          progress: progressStore,
          creditToday: false,
        );
        goTo(context, 'R12');
      },
      onStartSession: () => goTo(context, 'R03'),
      onOpenMeal: () => goTo(context, 'E01'),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'T03': (context) => LockScreenNudgeView(
      repository: todayRepository,
      onLogged: () => goTo(context, 'T01'),
      onSomethingElse: () => goTo(context, 'E02'),
    ),
    'T04': (context) => QuietWeekView(
      repository: todayRepository,
      // Her counters. The screen's own doc says it "says nothing about her
      // counted weeks rather than guessing" when this is null, and the router
      // was the caller that never wired it — so on a fresh install T04 could
      // only report a repair it had no evidence for.
      goal: progressStore.goal,
      onStartShortSession: () => goTo(context, 'R03'),
      onOpenMeal: () => goTo(context, 'E01'),
      onOpenWeek: () => goTo(context, 'P01'),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'T05': (context) => TierSlipView(
      repository: todayRepository,
      onStartShortSession: () => goTo(context, 'R03'),
      onStartSession: () => goTo(context, 'R03'),
      onRecall: () => goTo(context, 'T02'),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'T07': (context) => FirstWeekView(
      repository: todayRepository,
      // Her points and her level, from the same rewards object R10's bar is
      // drawn from. Nothing passed them, so both screens fell back to the
      // widget's own defaults — the prototype's 90 and 2 — and told a woman who
      // had logged nothing that she had 90 points on the screen whose whole
      // subject is what she has done this week.
      points: progressStore.rewards.points,
      level: progressStore.rewards.level,
      onClose: () => Navigator.of(context).maybePop(),
      onStartSession: () => goTo(context, 'R03'),
      onOpenStep: (screenId) => goTo(context, screenId),
      onBackToToday: () => goTo(context, 'T01'),
      onSeeProgress: () => goTo(context, 'P01'),
    ),
    // T08 is the finished state of T07 and is rendered by the same widget, in
    // place, the moment the arc completes. It is not somewhere you go.
    //
    // But it IS in `appDestinations`, so `/today/t08` resolved to a route with
    // no builder and a woman following that link landed on the developer
    // placeholder. Two ways out: take it out of the destinations, or give it
    // the screen it names. This is the second, because the first makes the link
    // fail rather than arrive, and `FirstWeekView` already decides which of the
    // two states to draw from her own arc — so t08 lands on her first week in
    // whatever state it is actually in, and never claims she has finished it.
    'T08': (context) => FirstWeekView(
      repository: todayRepository,
      // The same two figures as T07: this is the same widget in its other
      // state, so a number wired on one route and defaulted on the other would
      // change when the arc completed.
      points: progressStore.rewards.points,
      level: progressStore.rewards.level,
      onClose: () => Navigator.of(context).maybePop(),
      onStartSession: () => goTo(context, 'R03'),
      onOpenStep: (screenId) => goTo(context, screenId),
      onBackToToday: () => goTo(context, 'T01'),
      onSeeProgress: () => goTo(context, 'P01'),
    ),
    // Feature.events. Read again when she opens it, at most once an hour.
    'T09': (context) {
      unawaited(EventsState.instance.refresh());
      return EventsView(
        events: EventsState.instance.upcoming,
        onBack: () => Navigator.of(context).maybePop(),
        onOpenLink: (url) => openExternalLink(context, url),
      );
    },

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
      showGentlerOption: canSwap(
        WorkoutSessionState.instance.currentMove?.exerciseId,
      ),
      // The first "Short ones that still count" tile, as the design has it.
      // A follow-along starts from a session: R03 opens R06 itself for a
      // hold move, with a live session to log into.
      onFollowAlong: () => goTo(context, 'R03'),
      onShortSession: () => goTo(context, 'R03'),
      // Offered only once the phone holds a library to open. Asking here, on
      // the Train tab, is what brings it in for a woman verified since the
      // app launched: the check is rate-limited and returns at once when it
      // is not due.
      onOpenExerciseLibrary: _exerciseLibraryReady
          ? () => goTo(context, 'R14')
          : null,
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'R02': (context) {
      final l10n = AppL10n.of(context);
      final language = Localizations.localeOf(context).languageCode;
      final intake = intakeRepository.read();
      final her = herProgramme;
      final sessions = her == null
          ? const <AuthoredSession>[]
          : programmeSessionsFor(her.content, intake.lifeStage);
      final done = sessionsDoneThisWeek(trainRepository.sessions);
      final next = nextSlot(intake.days, done);
      void open(int? slot) {
        WorkoutLibraryState.instance
          ..chosenRowId = null
          ..openedSlot = slot;
        goTo(context, 'R03');
      }

      return ProgramView(
        onBack: () => Navigator.of(context).maybePop(),
        onChangeProgram: () => goTo(context, 'R11'),
        onStart: () => open(null),
        title: her == null
            ? null
            : (language == 'ar' ? her.content.titleAr : her.content.titleEn),
        promise: her == null
            ? null
            : StartingProgrammes.summary(her.program.programId, language),
        sessionsDone: sessions.isEmpty ? null : done.clamp(0, intake.days),
        sessionsTarget: sessions.isEmpty ? null : intake.days,
        days: [
          for (final slot in weekSlots(
            sessions,
            days: intake.days,
            minutes: intake.minutes,
            done: done,
          ))
            ProgramDay(
              title: slot.session.title(language),
              detail: l10n.minutesMinutesMovesMoves(
                countLabel(slot.session.minutes),
                countLabel(slot.session.moves.length),
              ),
              done: slot.done,
              today: slot.index == next,
              onTap: () => open(slot.index),
            ),
        ],
      );
    },
    'R03': (context) => WorkoutDayView(
      repository: trainRepository,
      // The session she chose on R11, when it came from the owner's library
      // and still suits her life stage. Null is the bundled session, which is
      // what day one always is.
      day: chosenWorkoutDay(context),
      // Only a library pick is written for her stage. The starting plans are
      // drafts until Rahma signs them off, so they never claim it.
      writtenForHerStage:
          WorkoutLibraryState.instance.chosenFor(
            intakeRepository.read().lifeStage,
          ) !=
          null,
      // Pregnant or after a birth: day one was not written for her, and the
      // screen says so before she starts.
      lifeStage: intakeRepository.read().lifeStage,
      // This week's challenge, marked on the move it is about (D38).
      challengeExerciseId: challengeFor(
        chosenWorkoutDay(context) ?? sampleWorkoutDay(AppL10n.of(context)),
      )?.challenge.exerciseId,
      challengeNote: challengeLineFor(
        context,
        chosenWorkoutDay(context) ?? sampleWorkoutDay(AppL10n.of(context)),
      ),
      onBack: () => Navigator.of(context).maybePop(),
      // Starts the session this screen is listing, so R07 opens on its first
      // move and its first set rather than on a fixed example.
      onStart: () {
        void begin() {
          unawaited(
            analytics.track(AnalyticsEvent.sessionStarted, {
              AnalyticsProp.isFirstTime: AnalyticsValue.flag(
                todayRepository.day.isDayOne,
              ),
            }),
          );
          final plan =
              chosenWorkoutDay(context) ??
              sampleWorkoutDay(AppL10n.of(context));
          WorkoutSessionState.instance.start(
            plan,
            trainRepository,
            challenge: challengeFor(plan),
          );
          WorkoutLibraryState.instance.openedSlot = null;
          if (_holdIsNext()) {
            goTo(context, 'R06');
          } else {
            goTo(context, 'R07');
          }
        }

        // "First time at the gym?", once, before her first session there. She
        // may read it or skip it; either way it is not offered again, and her
        // session starts from the guide's own button or from here.
        final gym = intakeRepository.read().place != TrainingPlace.home;
        if (gym && !FirstGymGuideState.instance.seen) {
          FirstGymGuideState.instance.seen = true;
          AppChanges.bump();
          unawaited(
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (guide) => FirstGymGuideView(
                  onStartWorkout: () {
                    Navigator.of(guide).pop();
                    begin();
                  },
                  onClose: () => Navigator.of(guide).pop(),
                ),
              ),
            ),
          );
          return;
        }
        begin();
      },
      // The move she tapped, carried through. It was discarded, so tapping
      // "Dead bug" opened a demo of a goblet squat.
      canOpenMove: (move) => clipFor(move.exerciseId) != null,
      onOpenMove: (move) {
        WorkoutSessionState.instance.openMove(move);
        goTo(context, 'R04');
      },
    ),
    'R04': (context) {
      final opened = WorkoutSessionState.instance.openedMove;
      final library = opened == null ? null : clipFor(opened.exerciseId);
      // A move the library does not hold has no clip to show: R15's empty
      // state, never a placeholder that pretends to be a video.
      if (opened != null && library == null) {
        return ExerciseDemoView(
          media: ExerciseLibraryState.instance.media,
          onClose: () => Navigator.of(context).maybePop(),
          onOpenLibrary: screenIsOn('R14') ? () => goTo(context, 'R14') : null,
        );
      }
      return ExerciseVideoView(
        move: opened,
        clip: library,
        media: ExerciseLibraryState.instance.media,
        players: ExerciseLibraryState.instance.players,
        canSwap: canSwap(WorkoutSessionState.instance.currentMove?.exerciseId),
        onClose: () => Navigator.of(context).maybePop(),
        onBackToWorkout: () => goTo(context, 'R03'),
        onSwap: () => goTo(context, 'R05'),
      );
    },
    'R05': (context) => SwapMoveView(
      repository: trainRepository,
      sessionId: WorkoutSessionState.instance.sessionId,
      exerciseId:
          WorkoutSessionState.instance.currentMove?.exerciseId ??
          'goblet_squat',
      moves: WorkoutSessionState.instance.moves,
      title: WorkoutSessionState.instance.day?.title,
      onBack: () => Navigator.of(context).maybePop(),
      // The swap replaces the move she is on, carrying its prescription with
      // it. It used to be assigned to a field nothing read, so she chose an
      // alternative and then trained the move she had just replaced.
      onSwapped: (alternative) {
        lastSwappedFor = alternative;
        WorkoutSessionState.instance.swapCurrent(alternative, trainRepository);
        if (_holdIsNext()) {
          goTo(context, 'R06');
        } else {
          goTo(context, 'R07');
        }
      },
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'R06': (context) {
      final session = WorkoutSessionState.instance;
      final move = session.currentMove;
      final set = session.currentSet;
      final l10n = AppL10n.of(context);
      return FollowAlongView(
        // The move and the hold she is on. Without a live hold set the screen
        // only draws the design, and logs nothing.
        moveName: move == null ? null : localisedMove(l10n, move).name,
        positionLabel: session.day == null
            ? null
            : moveTitle(l10n, session.moveIndex + 1, session.moveCount),
        holdSeconds: set?.holdSeconds,
        set: set,
        repository: trainRepository,
        sessionId: session.sessionId,
        clip: move == null ? null : clipFor(move.exerciseId),
        media: ExerciseLibraryState.instance.media,
        players: ExerciseLibraryState.instance.players,
        bus: session.bus,
        onAttach: session.attachScreen,
        onDetach: session.detachScreen,
        // The clock running out logs the set, exactly as R07's tap does, and
        // goes on to the rest.
        onSetLogged: (handle) {
          session.setLogged();
          _trackSetLogged('set');
          _goCarryingHandle(context, 'R09', handle);
        },
        // Skipping logs nothing: R07 offers the same set to log by hand.
        onSkip: () => goTo(context, 'R07'),
      );
    },
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
      //
      // The fallback is the first move of the one authored session, not the
      // widget's own fixture. R07 opened without a live session — from the
      // all-screens index, or a deep link — fell through to that fixture and
      // prescribed 12 kg inside a session whose own subtitle on R03 reads
      // "Quiet · no equipment · floor". Every move the app actually has is
      // bodyweight.
      move: loadFor(
        context,
        WorkoutSessionState.instance.currentMove ??
            sampleWorkoutDay(AppL10n.of(context)).moves.first,
      ).move,
      progressionLine: loadFor(
        context,
        WorkoutSessionState.instance.currentMove ??
            sampleWorkoutDay(AppL10n.of(context)).moves.first,
      ).line,
      setIndex: WorkoutSessionState.instance.setIndex,
      // Which move of how many. The bar read a fixed "Move 2 of 5".
      moveNumber: WorkoutSessionState.instance.moveIndex + 1,
      moveCount: WorkoutSessionState.instance.moveCount,
      // What she actually lifted for this move last time, read from her own
      // logged sets and excluding the session she is in. Null on a first
      // session, which is the case the sage note used to get wrong: it stated
      // "Last Tuesday: 10 kg × 10" to a woman who had never trained.
      lastLogged: lastLoggedOutcome(
        trainRepository,
        WorkoutSessionState.instance.currentMove?.exerciseId,
        exceptSessionId: WorkoutSessionState.instance.sessionId,
      ),
      // The session's one bus, so a set inside its five seconds is committed
      // when she leaves rather than dropped with this screen (D41, G02).
      bus: WorkoutSessionState.instance.bus,
      onAttach: WorkoutSessionState.instance.attachScreen,
      onDetach: WorkoutSessionState.instance.detachScreen,
      sets: _setsProgress,
      onClose: () => Navigator.of(context).maybePop(),
      onChange: () => goTo(context, 'R08'),
      onSetLogged: (handle) {
        WorkoutSessionState.instance.setLogged();
        _trackSetLogged('set');
        _goCarryingHandle(context, 'R09', handle);
      },
      onMoveLogged: (handle) {
        WorkoutSessionState.instance.moveLogged();
        _trackSetLogged('move');
        _goCarryingHandle(context, 'R13', handle);
      },
    ),
    'R08': (context) => ChangeSetView(
      repository: trainRepository,
      sessionId: WorkoutSessionState.instance.sessionId,
      // Which move of how many. The bar read a fixed "Move 2 of 5".
      moveNumber: WorkoutSessionState.instance.moveIndex + 1,
      moveCount: WorkoutSessionState.instance.moveCount,
      // The first set of the one authored session when there is no live one.
      // This was a hand-written goblet squat at 12 kg, so R08 opened cold
      // offered 10/12/14 kg inside a session whose own subtitle promises no
      // equipment at all.
      prescribed: _setWithAdvice(
        context,
        WorkoutSessionState.instance.currentSet ??
            sampleWorkoutDay(AppL10n.of(context)).moves.first.sets.first,
      ),
      moveName: WorkoutSessionState.instance.currentMove?.name,
      // Her planned weight and a step either side. Nothing was passed, so a
      // 17.5 kg set opened on the widget's own 10/12/14 with 10 chosen.
      //
      // A loaded move the plan gave no weight offers the weights around what
      // she lifted last time, or a starting ladder on a first session, so the
      // weight can be recorded at all.
      weightOptionsKg: _weightOptionsFor(context),
      askWeight:
          WorkoutSessionState.instance.currentMove?.needsEquipment ?? false,
      progressionLine: _loadAdviceLine(context),
      bus: WorkoutSessionState.instance.bus,
      onAttach: WorkoutSessionState.instance.attachScreen,
      onDetach: WorkoutSessionState.instance.detachScreen,
      sets: _setsProgress,
      onClose: () => Navigator.of(context).maybePop(),
      // Carries the handle, exactly as R07 does. It used to assign the
      // change to a field nothing read, which silently discarded her
      // override and left R09 announcing the numbers she had corrected.
      onSaved: (handle) {
        WorkoutSessionState.instance.setLogged();
        _trackSetLogged('set');
        _goCarryingHandle(context, 'R09', handle);
      },
    ),
    'R09': (context) => RestingView(
      handle: handleFrom(context),
      // Which move of how many. The bar read a fixed "Move 2 of 5".
      moveNumber: WorkoutSessionState.instance.moveIndex + 1,
      moveCount: WorkoutSessionState.instance.moveCount,
      // A full minute, from full. Nothing was passed, so the clock opened at
      // the preview's 0:38 of 60 and the "Up next" card never appeared.
      remaining: kRestDuration,
      total: kRestDuration,
      upNext: WorkoutSessionState.instance.isComplete
          ? null
          : _upNext(AppL10n.of(context)),
      upNextPrescription: WorkoutSessionState.instance.isComplete
          ? null
          : WorkoutSessionState.instance.currentMove?.prescriptionLabel,
      sets: _setsProgress,
      // Rest is measured against a deadline, and a phone put down mid-rest
      // is told when it ends (F504).
      onBackgrounded: (deadline) => unawaited(
        NotificationSync.restBackgrounded(
          reminderScheduler,
          deadline,
          now: AppClock.now(),
        ),
      ),
      onAlertCancel: () =>
          unawaited(NotificationSync.restCancelled(reminderScheduler)),
      // The bus took the set back; this puts her back on it.
      // Back to the set she took back, on R07 — never to R08 if the set was
      // saved from there.
      onUndo: () {
        if (WorkoutSessionState.instance.undoLast()) _backToSet(context);
      },
      onClose: () => Navigator.of(context).maybePop(),
      // The next set, or the end of the session when there is no next set.
      onReady: () {
        if (WorkoutSessionState.instance.isComplete) {
          _finishWorkout();
          goTo(context, 'R10');
        } else {
          if (_holdIsNext()) {
            goTo(context, 'R06');
          } else {
            goTo(context, 'R07');
          }
        }
      },
    ),
    'R10': (context) => FinishedView(
      // The session this page is reporting on. Without it the page could not
      // tell a measured session from a recalled one and drew the personal-best
      // card for every woman who finished anything at all.
      session: WorkoutSessionState.instance.lastFinished,
      // What the session really was, once its credit has landed (D40). R10
      // redraws when it does.
      summary: WorkoutSessionState.instance.lastSummary,
      awaitingSummary:
          WorkoutSessionState.instance.lastFinished != null &&
          WorkoutSessionState.instance.lastSummary == null,
      // The kitten cheers her first sessions and the one that counts her
      // week, within its one-per-sitting budget.
      cheer: _cheerOnFinish,
      // Her week, her points — the same numbers Home and Progress read.
      sessionsThisWeek: todayRepository.day.week.sessionsLogged,
      sessionsPrescribed: todayRepository.day.week.sessionsTarget,
      levelProgressPercent: _levelProgressPercent,
      // Home with the session's screens cleared, so a back gesture from Home
      // does not walk back through the finished workout.
      onBackToToday: () =>
          Navigator.of(context)
              .pushNamedAndRemoveUntil(appRoutes['T01']!.name, (_) => false),
      onShare: () => goTo(context, 'M03'),
    ),
    // The row she taps is the session she gets.
    //
    // This was `onOpenWorkout: (_) => goTo(context, 'R03')` under a list of
    // three rows with three different titles, so she chose "Upper body at
    // home" and was given "Legs and glutes". The argument is no longer thrown
    // away: `workoutDayFor` resolves the row she tapped to the session behind
    // it, and R03 is opened only when there is one.
    //
    // There is exactly one authored workout, and `sampleWorkoutLibrary` is
    // derived from it, so today the lookup always finds it — which is the
    // point. The day a second workout is written, this lookup is where R03
    // starts taking an id, and `train_honesty_test.dart` fails until it does
    // rather than quietly opening the wrong session again.
    'R11': (context) => WorkoutLibraryView(
      // The bundled session, then every library session that suits her life
      // stage. Pregnant or after a birth she is offered only sessions the
      // owner marked for that.
      workouts: [
        ...sampleWorkoutLibrary(AppL10n.of(context)),
        for (final entry in WorkoutLibraryState.instance.sessionsFor(
          intakeRepository.read().lifeStage,
        ))
          libraryRowFrom(
            AppL10n.of(context),
            Localizations.localeOf(context).languageCode,
            entry.programme,
            entry.session,
          ),
      ],
      // One session set apart above the rest (§15): the one she chose, else
      // the first that fits her answers.
      recommendedId: recommendedWorkout(
        [
          ...sampleWorkoutLibrary(AppL10n.of(context)),
          for (final entry in WorkoutLibraryState.instance.sessionsFor(
            intakeRepository.read().lifeStage,
          ))
            libraryRowFrom(
              AppL10n.of(context),
              Localizations.localeOf(context).languageCode,
              entry.programme,
              entry.session,
            ),
        ],
        intakeRepository.read(),
        chosenRowId: WorkoutLibraryState.instance.chosenRowId,
      )?.id,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenWorkout: (workout) {
        final library = WorkoutLibraryState.instance;
        if (workout.id.startsWith('library:')) {
          library.chosenRowId = workout.id;
          if (library.chosenFor(intakeRepository.read().lifeStage) == null) {
            library.chosenRowId = null;
            return;
          }
          library.openedSlot = null;
          goTo(context, 'R03');
          return;
        }
        if (workoutDayFor(AppL10n.of(context), workout.id) == null) return;
        library.chosenRowId = null;
        goTo(context, 'R03');
      },
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onOpenWeekPlan: () => goTo(context, 'E07'),
      onType: () => goTo(context, 'E02'),
      onSpeak: () => goTo(context, 'E03'),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      foodPointsPreview: _foodPointsPreview(handleFrom(context)),
      onOpenRecipes: () => goTo(context, 'E05'),
      onOpenWeekPlan: () => goTo(context, 'E07'),
      onType: () => goTo(context, 'E02'),
      onSpeak: () => goTo(context, 'E03'),
      onLogged: (handle) => _goCarryingHandle(context, 'E04', handle),
      onBlocked: (refused) =>
          EatAppState.instance.explainRefusal(context, refused),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'E05': (context) => RecipesView(
      // Kicked off here rather than in `main()`: a build that never opens Eat
      // never reads the asset, and three screens calling it is harmless because
      // the load is idempotent.
      book: (EatAppState.instance..ensureRecipeBook()).recipeBook,
      constraints: eatConstraints,
      asked: dietaryRepository.read().asked,
      onAnswerAllergies: () => goTo(context, 'E10'),
      onOpenLetter: () => goTo(context, 'E11'),
      onBack: () => Navigator.of(context).maybePop(),
      // The row she tapped, recorded inline at the tap — the same arrangement
      // the community ids use, because `goTo` pushes a route name and nothing
      // else. Without it E06 opened on koshari whichever recipe she chose.
      onOpenRecipe: (recipeId) {
        EatAppState.instance.openRecipeId = recipeId;
        goTo(context, 'E06');
      },
      onOpenWeekPlan: () => goTo(context, 'E07'),
      onSelectTab: (screenId) => goToTab(context, screenId),
      // Pick mode, opened from a day on E07: the recipe she taps goes on that
      // day, and she is back on the week.
      pickLabel: switch (_pickDayOf(context)) {
        final day? => AppL10n.of(
          context,
        ).pickADinnerForDay(weekdayLabelFor(AppL10n.of(context), day)),
        null => null,
      },
      onPick: switch (_pickDayOf(context)) {
        final day? => (recipeId) async {
          final navigator = Navigator.of(context);
          await mealRepository.swapDinner(
            weekId: WeekKey.of(AppClock.now()).id,
            day: day,
            recipeId: recipeId,
          );
          if (navigator.mounted) navigator.maybePop();
        },
        null => null,
      },
    ),
    // One route, two pages, because they are two different kinds of thing.
    //
    // A `rahma_` id is one of her cards: her text, her card, both tabs, cook
    // mode. Anything else is a prototype row, which is still built from the
    // *food* pack because no recipe exists behind it — see `recipe_view.dart`.
    // Branching here rather than inside one widget keeps every test written
    // against the old page pointed at the old page.
    'E06': (context) =>
        _rahmaRecipe(context) ??
        RecipeView(
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
      // A day is chosen on E05 in pick mode; the week reads itself again
      // once she is back.
      onPickDinner: (day) =>
          Navigator.of(context)
              .pushNamed(appRoutes['E05']!.name, arguments: day),
      fillFrom: rahmaDinners(),
      recipeTitle: (recipeId) =>
          EatAppState.instance.recipeBook.byId(recipeId)?.titleEn,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenRecipe: (recipeId) {
        EatAppState.instance.openRecipeId = recipeId;
        goTo(context, 'E06');
      },
      onOpenGroceryList: () => goTo(context, 'E08'),
    ),
    'E10': (context) => AllergyQuestionView(
      initial: dietaryRepository.read(),
      onBack: () => Navigator.of(context).maybePop(),
      onOpenProfile: () => goTo(context, 'A02'),
      // An empty allergy set here is her answer, not a default, which is the
      // one thing that turns `DietaryConstraints.none` from a fiction into a
      // statement. `save` writes both fields and nothing else.
      onAnswered: (allergies, dietary) async {
        await dietaryRepository.save(allergies: allergies, dietary: dietary);
        AppChanges.bump();
        if (context.mounted) Navigator.of(context).maybePop();
      },
    ),
    'E11': (context) => RahmaLetterView(
      letterAr: (EatAppState.instance..ensureRecipeBook()).recipeBook.letterAr,
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'E08': (context) => GroceryListView(
      repository: mealRepository,
      // The list is her dinners' own ingredients: Rahma's recipes only, and
      // nothing at all until she has planned some.
      recipeOf: rahmaRecipe,
      recipeTitle: (recipeId) => rahmaRecipe(recipeId)?.titleEn,
      onPlanWeek: () => goTo(context, 'E07'),
      onBack: () => Navigator.of(context).maybePop(),
      // There is no share plugin in `pubspec.yaml`, so nothing here can open an
      // OS share sheet. G5 §9 Q8 stands; this says what the build can do.
      onShare: () => showHonestNotice(
        context,
        AppL10n.of(context).sharingIsNotConnectedInThisBuild,
      ),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),

    'R12': (context) => LoggedFromMemoryView(
      // What the ledger actually granted. It printed "+15 points" whatever
      // happened, a capped third session of the day included.
      // Nothing credited, nothing claimed: zero draws no points line.
      // The session and, when it counted her week, the week too.
      pointsGranted: lastRecallOutcome?.pointsGranted ?? 0,
      sessionsThisWeek: todayRepository.day.week.sessionsLogged,
      sessionsPrescribed: todayRepository.day.week.sessionsTarget,
      levelProgressPercent: _levelProgressPercent,
      onBackToToday: () => goTo(context, 'T01'),
    ),
    // Logs a whole move and returns to the move list — the session does NOT end.
    'R13': (context) => MoveLoggedView(
      handle: handleFrom(context),
      moves: WorkoutSessionState.instance.moves,
      // Moves struck off, not sets. This passed `loggedSetCount` into a count
      // rendered as moves, so two moves of three sets each read "6 of 5" over
      // a list of five, every row struck through and none marked next.
      loggedCount: WorkoutSessionState.instance.moveIndex,
      title: WorkoutSessionState.instance.day?.title,
      sets: _setsProgress,
      // Back to the set she took back, on R07 — never to R08 if the set was
      // saved from there.
      onUndo: () {
        if (WorkoutSessionState.instance.undoLast()) _backToSet(context);
      },
      onClose: () => Navigator.of(context).maybePop(),
      // The next move, or the end of the session when that was the last one.
      onNextMove: () {
        if (WorkoutSessionState.instance.isComplete) {
          _finishWorkout();
          goTo(context, 'R10');
        } else {
          if (_holdIsNext()) {
            goTo(context, 'R06');
          } else {
            goTo(context, 'R07');
          }
        }
      },
      onFinishHere: () {
        // Read before the finish lands: with moves still left, this session
        // ended early. Sent ahead of the `workout_complete` every finish sends.
        if (!WorkoutSessionState.instance.isComplete) {
          unawaited(analytics.track(AnalyticsEvent.workoutEndedEarly));
        }
        _finishWorkout();
        goTo(context, 'R10');
      },
    ),
    // The exercise library (D42): every move the owner filmed, by the part of
    // the body it works, screened for her life stage before anything is drawn.
    'R14': (context) {
      unawaited(ExerciseLibraryState.instance.refresh());
      final stage = intakeRepository.read().lifeStage;
      final screened = ExerciseLibraryState.instance.screenedFor(stage);
      return ExerciseLibraryView(
        exercises: screened.shown,
        hiddenFor: screened.someHidden ? stage : null,
        media: ExerciseLibraryState.instance.media,
        onBack: () => Navigator.of(context).maybePop(),
        onOpenExercise: (exercise) {
          ExerciseLibraryState.instance.openExerciseId = exercise.id;
          goTo(context, 'R15');
        },
        onSelectTab: (screenId) => goToTab(context, screenId),
      );
    },
    // One move's clip. Re-screened here, so a move hidden for her cannot be
    // reached by an id left over from before her answers changed.
    'R15': (context) => ExerciseDemoView(
      exercise: ExerciseLibraryState.instance.openedFor(
        intakeRepository.read().lifeStage,
      ),
      media: ExerciseLibraryState.instance.media,
      players: ExerciseLibraryState.instance.players,
      onClose: () => Navigator.of(context).maybePop(),
      onOpenLibrary: () => goTo(context, 'R14'),
    ),

    // ---------------------------------------------------- Progress (G6)
    //
    // P01 carries the ONLY inbound edges T04 and T05 have anywhere in the
    // design. Until it was built, both were implemented, routable and
    // reachable by nobody — the same fault T07 had before T06 was wired.
    'P01': (context) => ProgressView(
      summary: progressSummary,
      // Her first week, so the row that opens T07 counts it instead of
      // stating "All five done" to a woman who has done none of it.
      firstWeek: todayRepository.day.arc,
      trainingStreak: trainingStreakNow,
      onOpenStreak: () => unawaited(openTrainingStreak(context)),
      // The milestone nearest to done, from her real counts (§15).
      nextMilestone: _nextMilestone,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenMilestones: () => goTo(context, 'P02'),
      onOpenBests: () => goTo(context, 'P03'),
      onOpenBody: () => goTo(context, 'P04'),
      onOpenShare: () => goTo(context, 'P05'),
      onOpenFirstWeek: () => goTo(context, 'T07'),
      onOpenRestWeek: () => goTo(context, 'T04'),
      onOpenTierSlip: () => goTo(context, 'T05'),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    // Her progress card: what she did, on one card she can share. Read from
    // her own stores on this phone; her weigh-ins only through
    // historyForOwner, and the weight line only if she switches it on there.
    'P05': (context) => ShareProgressView(
      story: ProgressStory(
        sessions: progressStore.rewards.sessionsLogged,
        countedWeeks: progressStore.goal.countedWeeks,
        bestRun: progressStore.goal.bestRun,
        mealsAdded: mealRepository.mealsAdded,
        bests: progressStore.rewards.bestsCount,
        milestones: progressStore.rewards.milestones.length,
      ),
      loadWeighIns: () async => [
        for (final m in await measurementsRepository.historyForOwner(
          limit: 1000,
        ))
          if (m.weightKg case final kg?) (at: m.takenAt, kg: kg),
      ],
      onShare: shareProgressCard,
      onShared: () => unawaited(analytics.track(AnalyticsEvent.progressShared)),
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goToTab(context, screenId),
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
        // Her real counts (D41). This was all zeros, so "Ten sessions" read
        // "0 of 10" to a woman on her twelfth.
        counts: RewardsState.instance.milestoneCounts(progressStore),
      ),
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'P03': (context) => PersonalBestsView(
      bests: progressStore.bests.values.toList(),
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'P04': (context) => BodyPrivatelyView(
      repository: measurementsRepository,
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),

    // ----------------------------------------------------- Account (G7)
    'A01': (context) => NotificationsView(
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goToTab(context, screenId),
      remindersOn: ReminderState.instance.schedule != null,
      onOpenReminders: featureFlags.isOn(Feature.trainingReminders)
          ? () => unawaited(openTrainingReminders(context))
          : null,
      prefs: ReminderState.instance.permitted
          ? ReminderState.instance.prefs
          : null,
      onPrefsChanged: (prefs) => unawaited(setNotificationPrefs(prefs)),
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
      // D3's other half — "ask early, editable forever". The four setup
      // questions had no door outside the switched-off sign-up flow, so
      // "forever" was false in the shipped build and a woman who skipped setup,
      // or whose life changed, had to reinstall to say so. This row runs the
      // identical walk, and `O05` pops back here rather than to Home because
      // leaving setup returns her to wherever she entered it from.
      // Setup from her profile never ends on Home: whatever an earlier walk
      // left in the sign-up flag, this one did not come from sign-up (N15).
      onOpenTraining: () {
        OnboardingState.instance
          ..enteredFromSignup = false
          ..shortSetupAfterSignup = false
          ..beforeSignup = false
          ..whileWaiting = false;
        goTo(context, 'O01');
      },
      onOpenLanguage: () => goTo(context, 'C02'),
      onOpenNotifications: () => goTo(context, 'A01'),
      onOpenPrivacy: () => goTo(context, 'A03'),
      onOpenSafetyCentre: () => goTo(context, 'A04'),
      // Apple 5.1.1(v). The row rendered and this callback was never passed,
      // so "Your data" was a tap that did nothing on the one screen where the
      // stores require an action. It is a sheet rather than a destination:
      // there is no screen id for deletion among the 161, and HANDOFF rule 16
      // forbids minting one for a state.
      onOpenYourData: () => openYourData(context),
      // Every screen, one tap away, in a build that is not going to a store.
      // The owner's admin build only. A store build resolves no admin route,
      // so the row is never drawn there.
      onOpenAdmin: adminConsoleOffered ? () => goTo(context, 'Z01') : null,
      onOpenAllScreens: !testingAidsAllowed
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AllScreensView()),
            ),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'A03': (context) => PrivacyView(
      service: privacyService,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenCycleSharing: () => goTo(context, 'Y12'),
      // The published pages. Both stores want the policy reachable from inside
      // the app; the rows only exist once `LegalLinks` has an address.
      // In her language: the Arabic pages live under /ar/.
      onOpenPrivacyPolicy: openPrivacyFor(context),
      onOpenTerms: openTermsFor(context),
      onSelectTab: (screenId) => goToTab(context, screenId),
      healthBackup: healthBackupController(),
      onSignInAgain: () => unawaited(signInAgain(context)),
      // Crash reports by consent (M3), off unless she allowed them.
      crashReportsAllowed: CrashConsent.instance.allowed,
      onCrashReportsChanged: CrashConsent.instance.set,
      analyticsAllowed: AnalyticsConsent.instance.allowed,
      onAnalyticsChanged: AnalyticsConsent.instance.set,
    ),
    // Four of A04's five rows drew a chevron and had no callback at all, which
    // on the safety screen is the worst place in the product for a control
    // that looks live and is not. Each one now does the thing or stops
    // claiming it can; the view's own note records which is which.
    'A04': (context) => SafetyCentreView(
      blockService: blockService,
      reportService: reportService,
      onBack: () => Navigator.of(context).maybePop(),
      // Reporting a woman needs a woman to report. `M08` collects the reason
      // against her post or her page; from here there is no subject, so the
      // row says where a report starts rather than opening an empty picker.
      onReportSomeone: () => showHonestNotice(
        context,
        AppL10n.of(context).reportHerFromHerPostOrHer,
      ),
      // The published support page, on exactly the rule A03 follows: the row
      // is drawn only once the page has an address, so the app never shows a
      // control that opens nothing.
      onTalkToAHuman: LegalLinks.support.isEmpty
          ? null
          : () => unawaited(openExternalLink(context, LegalLinks.support)),
      // A name for a woman she blocked, from the store that has one. Empty
      // when this build has never seen her name, and the row then carries the
      // unblock action alone rather than a uid dressed up as a person.
      nameOf: (uid) =>
          communityStore.profiles[uid]?.name ??
          communityStore.posts
              .where((p) => p.authorUid == uid)
              .map((p) => p.authorCard.name)
              .firstOrNull ??
          '',
      onSelectTab: (screenId) => goToTab(context, screenId),
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
    // Every save goes through `saveToLibrary`, which writes to Firestore
    // (`RemoteContentRepository`) and closes the form only once the library
    // holds the row. The rules accept those writes from the `admin` claim
    // alone. A recipe is written with the index and version the member app
    // reads, so it reaches members; see `remote_content_repository.dart`.
    //
    // Choosing a file and uploading media are still unwired: there is no file
    // picker dependency, and wiring them to something that looks like it
    // works is the one outcome worse than a control that visibly does not.
    'Z01': (context) => ContentLibraryView(
      status: adminLibraryStatusLoading,
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
      onOpenDashboard: () => goTo(context, 'Z15'),
      onOpenLogs: () => goTo(context, 'Z16'),
      onOpenEvents: () => goTo(context, 'Z17'),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'Z02': (context) => CollectionView(
      collection: ContentCollection.exercises,
      rows: adminRowsNow(ContentCollection.exercises),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'Z03': (context) => ContentFormView(
      collection: ContentCollection.exercises,
      values: adminEditingRow,
      // Written to the library first, and closed only once it is there.
      onSave: (row) => saveToLibrary(
        context,
        collection: ContentCollection.exercises,
        values: row,
      ),
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),
    'Z04': (context) => CollectionView(
      collection: ContentCollection.foods,
      rows: adminRowsNow(ContentCollection.foods),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'Z05': (context) => ContentFormView(
      collection: ContentCollection.foods,
      values: adminEditingRow,
      // Written to the library first, and closed only once it is there.
      onSave: (row) => saveToLibrary(
        context,
        collection: ContentCollection.foods,
        values: row,
      ),
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),
    'Z06': (context) => CollectionView(
      collection: ContentCollection.recipes,
      rows: adminRowsNow(ContentCollection.recipes),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'Z07': (context) => CollectionView(
      collection: ContentCollection.programmes,
      rows: adminRowsNow(ContentCollection.programmes),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
        // Recipe rows are published exactly as Z12 publishes one, and a row
        // the member app would refuse writes nothing; the notice says so.
        onCommit: () => unawaited(commitImport(context, plan.writes)),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      sections: adminRecipeSectionsLoading,
      // Written with its method (the `method_ar` column) and the member app's
      // own recipe rules run before anything is sent.
      onSave: (row) => saveToLibrary(
        context,
        collection: ContentCollection.recipes,
        values: row,
      ),
      onClose: () {
        adminEditingRow = const <String, String>{};
        Navigator.of(context).maybePop();
      },
    ),
    'Z13': (context) => ContentFormView(
      collection: ContentCollection.programmes,
      values: adminEditingRow,
      // Its sessions, built from the exercise library, and whether members
      // see them. The member app's own workout rules run before it is sent.
      exercises: [
        for (final row in adminRowsNow(ContentCollection.exercises))
          (row.id, row.value('name_en')),
      ],
      sessions: contentRepository.sessionsFor(
        adminEditingRow['programId'] ?? '',
      ),
      published: contentRepository.isPublished(
        adminEditingRow['programId'] ?? '',
      ),
      onSaveProgramme: (row, sessions, published) => saveToLibrary(
        context,
        collection: ContentCollection.programmes,
        values: row,
        sessions: sessions,
        published: published,
      ),
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
      // Skipping costs nothing, and lands her back where she came from. It
      // pushed a second Home on top of the first.
      onSkip: () => Navigator.of(context).maybePop(),
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
      // Y14's consent row. The symptom-only path never passes Y02, so this is
      // the only place that woman can say the app may offer her a gentler
      // session — and the gentler card is gated on exactly this field.
      onSetWorkoutSuggestions: (on) =>
          unawaited(CycleAppState.instance.setWorkoutSuggestions(on)),
      onOpenMeals: screenIsOn('Y07') ? () => goTo(context, 'Y07') : null,
      onAddDates: () => goTo(context, 'Y02'),
      // Y11's two outward routes, and what they say is what is actually
      // missing.
      //
      // They used to say "maps are not connected in this build" and "opening
      // web links is not connected in this build". Both were untrue:
      // `url_launcher` ships, `openExternalLink` exists, and A03 and A04 in
      // this same file already use it. What is missing is CONTENT, not
      // capability, and blaming the wrong thing on the screen a woman reaches
      // in severe pain means the day the content lands nobody knows the button
      // was ever ready.
      //
      // The care directory is the one that needs authoring: a clinically
      // reviewed list of Egyptian clinics, `CareDirectory.bundled`, OQ-11.
      //
      // TWO THINGS ROUND ONE AND TWO RECORDED HERE AND THIS CHANGE DOES NOT
      // SETTLE, because both are the owner's:
      //   * the guidance button is labelled "Read NHS guidance on period
      //     pain", and the NHS is a British health service being cited to an
      //     Egyptian woman. The source has to be chosen before the link is
      //     filled in, and the label changes with it.
      //   * `122`, the Egyptian emergency line, is in the dictionary and
      //     renders on A04. Whether it belongs on this card is a clinical
      //     question about when severe period pain is an emergency, and it is
      //     not one a fixing pass answers.
      onFindCare: () => showHonestNotice(
        context,
        AppL10n.of(context).weDoNotHaveACareDirectory,
      ),
      // Wired the moment there is an address, on exactly the rule A03 and A04
      // already follow for the published pages.
      onReadGuidance: CareLinks.periodPainGuidance.isEmpty
          ? () => showHonestNotice(
              context,
              AppL10n.of(context).weDoNotHaveAGuidancePage,
            )
          : () => unawaited(
              openExternalLink(context, CareLinks.periodPainGuidance),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      // Taking the option is an answer too, so the hub stops asking — the same
      // as "Keep my workout" and rest. Without this she came back from the
      // gentler session to a card still offering it.
      onUseOption: () {
        CycleAppState.instance.decideToday();
        goTo(context, 'R03');
      },
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
      // Up to three of Rahma's recipes, from what she logged today and what
      // the recipes are tagged. The allergy guard has already taken out what
      // she cannot eat, and nothing here reads a date.
      options: [
        for (final pick in mealsForToday(todayCheckIn, rahmaRecipes()))
          cycleMealOption(AppL10n.of(context), pick),
      ],
      // Onto the week, never into what she has eaten.
      onAddToPlan: (option) => unawaited(_addToWeek(context, option.recipeId)),
      onBack: () => Navigator.of(context).maybePop(),
      onSelectTab: (screenId) => goToTab(context, screenId),
    ),
    'Y08': (context) => CycleCalendarView(
      cycle: cycleRepository.current,
      year: AppClock.now().year,
      month: AppClock.now().month,
      // The calendar drew no logged days and no check-in days at all, because
      // neither list was ever passed.
      periods: periodsSoFar,
      checkInDays: todayCheckIn == TodayCheckIn.absent
          ? const <String>{}
          : <String>{dayId(AppClock.now())},
      onBack: () => Navigator.of(context).maybePop(),
      onSettings: () => goTo(context, 'Y12'),
      onLogPeriod: () => goTo(context, 'Y09'),
      onAboutPhases: () => goTo(context, 'Y13'),
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      // To the calendar it was saved into, or back where she came from when
      // the calendar is switched off.
      onSaved: () => screenIsOn('Y08')
          ? goTo(context, 'Y08')
          : Navigator.of(context).maybePop(),
    ),
    'Y10': (context) => CyclePatternsView(
      // Y10 rendered its empty state permanently: no starts, no check-ins, so
      // the chart never drew and its caption never appeared in the app.
      recentStarts: cycleRepository.current?.recentStarts ?? const <String>[],
      checkIns: todayCheckIn == TodayCheckIn.absent
          ? const <String, TodayCheckIn>{}
          : <String, TodayCheckIn>{dayId(AppClock.now()): todayCheckIn},
      easierWhenLowEnergy:
          cycleRepository.current?.adaptation.easierWhenLowEnergy ?? false,
      onBack: () => Navigator.of(context).maybePop(),
      onSettings: () => goTo(context, 'Y12'),
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
    // The rules come first. A woman who has not agreed to them (C16) is shown
    // them in place of the feed, and the feed takes their place once she
    // agrees: nothing in the community is open before that.
    'M01': (context) => !PledgeState.instance.agreed
        ? PledgeView(
            onAgree: () {
              recordPledge(context);
              AppChanges.bump();
            },
            onBack: () => Navigator.of(context).maybePop(),
          )
        : FeedView(
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
            onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
    // One thing a screen, in her order: photo, name and city, what she
    // coaches, how she coaches, prices and plans, results, what clients say,
    // certificates, the three rules, getting paid, the check. A step whose
    // screen is switched off (results and reviews live under her portfolio)
    // is skipped, written out arm by arm so the navigation graph sees each
    // edge.
    'K01': (context) => CoachPhotoView(
      model: coachSetupModel,
      onTakePhoto: () => photographHerself(context),
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K08');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K08': (context) => CoachBasicsView(
      model: coachSetupModel,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K03');
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
      // A photo of the certificate, taken live and sent for a woman reviewer
      // (R1-P15). In a build with testing aids a certificate is recorded
      // without one, and `K02` draws the row as a test nobody has reviewed.
      onAddCertificate: CoachProfileState.isTestMode
          ? (credentialId) =>
                CoachProfileState.instance.addTestCertificate(credentialId)
          : (credentialId) =>
                unawaited(addCertificatePhoto(context, credentialId)),
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K13');
      },
      // Back is back: the step before is already under this screen (M3).
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K03': (context) => CoachSpecialtiesView(
      model: coachSetupModel,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K10');
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K10': (context) => CoachHowYouCoachView(
      model: coachSetupModel,
      onContinue: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K04');
      },
      onBack: () => Navigator.of(context).maybePop(),
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
        if (screenIsOn('K11')) {
          goTo(context, 'K11');
        } else if (screenIsOn('K12')) {
          goTo(context, 'K12');
        } else {
          goTo(context, 'K02');
        }
      },
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K11': (context) => CoachResultsStepView(
      onContinue: () =>
          screenIsOn('K12') ? goTo(context, 'K12') : goTo(context, 'K02'),
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    'K12': (context) => CoachReviewsStepView(
      onContinue: () => goTo(context, 'K02'),
      onBack: () => Navigator.of(context).maybePop(),
      onSaveAndClose: () {
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K07');
      },
    ),
    // The community's three rules, agreed here rather than on C16: a coach
    // goes from C13 into her own setup (R1-P16). A woman who has already
    // agreed finds the box ticked.
    'K13': (context) => CoachRulesView(
      model: coachSetupModel
        ..rulesAgreed =
            coachSetupModel.rulesAgreed || PledgeState.instance.agreed,
      onContinue: () {
        if (!PledgeState.instance.agreed) recordPledge(context);
        CoachProfileState.instance.saveSetup();
        goTo(context, 'K05');
      },
      onBack: () => Navigator.of(context).maybePop(),
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
      // "Add payout later": the application goes in without a payout method,
      // which she adds before she can be paid (R1-P15).
      onPayoutLater: () {
        CoachProfileState.instance.completeSetup(payoutLater: true);
        goTo(context, 'K06');
      },
      onBack: () => Navigator.of(context).maybePop(),
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
      // K06's promise kept on her desk: she builds while she is checked.
      onBuildFirstPlan: () => goTo(context, 'K20'),
      // Her code for a woman she already coaches. Only once she may accept
      // a client: the server mints no code before then (R1-P18).
      onInviteClient:
          coachRepository.profileUnbilled.verification.mayAcceptClients
          ? () => unawaited(shareCoachInvite(context))
          : null,
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
        onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
                ? AppL10n.of(context).eaten
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
          : AppL10n.of(context).tapOneAndItsSavedYouCan,
      onUndo: coachedLife.lastLogged == null
          ? null
          : () {
              coachedLife.undoLastMeal();
              goTo(context, 'G04');
            },
      onEdit: () => goTo(context, 'G10'),
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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
      onTab: (screenId) => goToTab(context, screenId),
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
      onTab: (screenId) => goToTab(context, screenId),
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
            // The draft is the assistant's. With it off there is no button.
            onDraftForMe: screenIsOn('K26') ? () => goTo(context, 'K26') : null,
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
        onDraftAWeek: screenIsOn('K27') ? () => goTo(context, 'K27') : null,
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
      onTab: (screenId) => goToTab(context, screenId),
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
      onTab: (screenId) => goToTab(context, screenId),
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
      onSelectTab: (screenId) => goToTab(context, screenId),
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

    // The owner's operations. Each is served by an admin-only callable or by
    // rules that accept the admin claim only, so a build that carries these
    // screens still shows nothing to an account without it.
    'Z15': (context) => DashboardView(
      source: consoleSource,
      onBack: () => Navigator.of(context).maybePop(),
      onOpenLogs: () => goTo(context, 'Z16'),
      onOpenEvents: () => goTo(context, 'Z17'),
    ),
    'Z16': (context) => LogsView(
      source: consoleSource,
      onBack: () => Navigator.of(context).maybePop(),
    ),
    'Z17': (context) => EventsAdminView(
      store: eventAdminStore,
      revision: adminEventsRevision,
      onBack: () => Navigator.of(context).maybePop(),
      onAdd: () {
        adminEditingEvent = null;
        goTo(context, 'Z18');
      },
      onOpen: (event) {
        adminEditingEvent = event;
        goTo(context, 'Z18');
      },
    ),
    'Z18': (context) => EventFormView(
      store: eventAdminStore,
      event: adminEditingEvent,
      mediaNames: [for (final f in adminMediaBundle.files) f.name],
      onSaved: (event) {
        adminEditingEvent = null;
        adminEventsRevision++;
        showHonestNotice(context, AppL10n.of(context).savedToTheLibrary);
        Navigator.of(context).maybePop();
        AppChanges.bump();
      },
      onFailed: () => showHonestNotice(
        context,
        AppL10n.of(context).couldNotSaveCheckTheConnectionAnd,
      ),
      onClose: () {
        adminEditingEvent = null;
        Navigator.of(context).maybePop();
      },
    ),
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
    // Every meal she logs, from Home or from Eat, arrives on E04 through here.
    // Her first is the one held while Home is still on day one: the write is
    // in its five-second undo window as this runs.
    if (screenId == 'E04') {
      unawaited(
        analytics.track(AnalyticsEvent.mealLogged, {
          AnalyticsProp.isFirstTime: AnalyticsValue.flag(
            todayRepository.day.isDayOne,
          ),
        }),
      );
    }
    Navigator.of(context).pushNamed(route.name, arguments: handle);
  }

  /// One coarse word per liveness start, from a closed vocabulary. A refused
  /// account or an open review is `other`: that is a verification state, and
  /// verification results never reach analytics.
  static void _trackLivenessStart(LivenessStart started) => unawaited(
    analytics.track(AnalyticsEvent.livenessStartOutcome, {
      AnalyticsProp.outcome: AnalyticsValue.token(livenessStartToken(started)),
    }),
  );

  /// The word [_trackLivenessStart] sends for [started].
  @visibleForTesting
  static String livenessStartToken(LivenessStart started) => switch (started) {
    LivenessStart.started => 'started',
    LivenessStart.offline => 'offline',
    LivenessStart.failed => 'failed',
    LivenessStart.tryTomorrow || LivenessStart.checksUsedUp => 'limit',
    _ => 'other',
  };

  /// The check's outcome as a token: verified, reviewer, retake or rejected.
  /// Never why: a refusal's reason is about her sex, her age or her card.
  static void _trackDecided(String outcome) => unawaited(
    analytics.track(AnalyticsEvent.verificationDecided, {
      AnalyticsProp.outcome: AnalyticsValue.token(outcome),
    }),
  );

  /// "You're in": `automatic` after the check, `reviewer` after a woman
  /// reviewer approved her.
  static void _trackYoureIn(String method) => unawaited(
    analytics.track(AnalyticsEvent.youreIn, {
      AnalyticsProp.method: AnalyticsValue.token(method),
    }),
  );

  /// The camera could not run, by its technical cause alone.
  static void _trackCameraUnavailable(CaptureUnavailableReason reason) =>
      unawaited(
        analytics.track(AnalyticsEvent.cameraUnavailable, {
          AnalyticsProp.reason: AnalyticsValue.token(cameraReasonToken(reason)),
        }),
      );

  /// The word [_trackCameraUnavailable] sends for [reason].
  @visibleForTesting
  static String cameraReasonToken(CaptureUnavailableReason reason) =>
      switch (reason) {
        CaptureUnavailableReason.permissionDenied => 'permission_denied',
        CaptureUnavailableReason.noCamera => 'no_camera',
        CaptureUnavailableReason.notImplemented => 'not_implemented',
        CaptureUnavailableReason.providerUnavailable => 'provider_unavailable',
        CaptureUnavailableReason.offline => 'offline',
      };

  /// The word a reviewer path is counted as. The niqab path and "I would
  /// rather not" are both `chosen`: which one she took is hers, and the
  /// niqab is a religious practice. A check that could not run is
  /// `unavailable`.
  @visibleForTesting
  static String reviewerPathToken(ReviewPath path) => switch (path) {
    ReviewPath.niqab || ReviewPath.declined => 'chosen',
    ReviewPath.error => 'unavailable',
  };

  /// A set logged in a workout: `set` for one (`R07`, `R08`), `move` for a
  /// whole move at once (`R13`). Never the move, the load or the reps.
  static void _trackSetLogged(String source) => unawaited(
    analytics.track(AnalyticsEvent.setLogged, {
      AnalyticsProp.source: AnalyticsValue.token(source),
    }),
  );

  /// Her reminders, as one word: `on`, `off`, `denied` or `unavailable`.
  /// Never the days or the times she chose.
  static void _trackReminders(String outcome) => unawaited(
    analytics.track(AnalyticsEvent.remindersChanged, {
      AnalyticsProp.outcome: AnalyticsValue.token(outcome),
    }),
  );

  /// The word [_trackReminders] sends when the phone did not allow them.
  @visibleForTesting
  static String remindersOutcomeToken(ReminderPermission permission) =>
      switch (permission) {
        ReminderPermission.granted => 'on',
        ReminderPermission.denied => 'denied',
        ReminderPermission.unavailable => 'unavailable',
      };

  /// Hands her progress card (P05) to the phone's share sheet, anchored at
  /// the button for an iPad. The PNG goes from the screen to the app she
  /// picks; nothing is uploaded anywhere.
  static Future<void> shareProgressCard(Uint8List png, Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(png, mimeType: 'image/png', name: 'own-hub.png'),
        ],
        fileNameOverrides: const ['own-hub.png'],
        sharePositionOrigin: origin == Rect.zero ? null : origin,
      ),
    );
  }

  /// The stop she was last on in the tour, so leaving it can say where.
  static int _lastTourStop = 0;

  /// Events that belong to a screen opening rather than to a tap: the tour
  /// beginning (`C04`) and a reviewer path (`C15`).
  static void _trackRouteOpened(String id) {
    switch (id) {
      case 'C04':
        _lastTourStop = 0;
        unawaited(analytics.track(AnalyticsEvent.tourStarted));
      case 'C15':
        unawaited(
          analytics.track(AnalyticsEvent.reviewerPathChosen, {
            AnalyticsProp.outcome: AnalyticsValue.token(
              reviewerPathToken(pendingReviewPath),
            ),
          }),
        );
    }
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
    // Read before the finish lands: whether this was her first session, and
    // how far her week was from its target.
    final firstEver = todayRepository.day.isDayOne;
    final before = todayRepository.day.week;
    final plan = WorkoutSessionState.instance.day;
    unawaited(
      WorkoutSessionState.instance
          .finish(
            repository: trainRepository,
            today: todayRepository,
            progress: progressStore,
            challengeNow: plan == null ? null : () => challengeFor(plan),
          )
          .then((_) => _trackWorkoutFinished(firstEver, before))
          .then((_) => noteSessionLogged()),
    );
  }

  /// What the meal behind [handle] will pay when its window closes (D41).
  ///
  /// Five for the first meal of its day, under the cap; nothing once that day
  /// has paid, and nothing for a second meal logged while the first of the
  /// same day is still inside its undo window — only one of them will pay.
  static int _foodPointsPreview(LogHandle? handle) {
    if (handle == null) return 0;
    final pending = EatAppState.instance.session.pending;
    final index = pending.indexWhere((meal) => identical(meal.handle, handle));
    final day = dayKey(index < 0 ? AppClock.now() : pending[index].at);
    final earlier =
        index > 0 && pending.take(index).any((meal) => dayKey(meal.at) == day);
    return RewardsState.instance.foodDayPointsAvailable(
      day,
      anotherPendingToday: earlier,
    );
  }

  /// Her training streak for the screens that show it (D37), or null when it
  /// is switched off — by the build or by her. A null draws nothing anywhere.
  static StreakStatus? get trainingStreakNow {
    if (!featureFlags.isOn(Feature.trainingStreak)) return null;
    final status = TrainingStreakState.instance.status(progress: progressStore);
    return status.enabled ? status : null;
  }

  /// The streak sheet: the rule, the pauses, resume, and the off switch.
  static Future<void> openTrainingStreak(BuildContext context) {
    final state = TrainingStreakState.instance;
    return showTrainingStreakSheet(
      context,
      status: state.status(progress: progressStore),
      onPause: state.pause,
      onResume: state.resume,
      onSwitch: (on) => state.setEnabled(on, progress: progressStore),
    );
  }

  /// The moves R05 offers in place of [exerciseId], from the exercise library
  /// and in the language she reads, or none when the library does not hold the
  /// move. Sync, so an entry point can hide itself without waiting.
  static List<MoveAlternative> swapOptionsFor(String exerciseId) {
    final candidates = ExerciseLibraryState.instance.swapCandidates(
      exerciseId,
      intakeRepository.read(),
    );
    if (candidates.isEmpty) return const <MoveAlternative>[];
    final code =
        localePreference.read()?.code ??
        PlatformDispatcher.instance.locale.languageCode;
    final language = code == 'ar' ? 'ar' : 'en';
    final l10n = lookupAppL10n(Locale(language));
    return [
      for (final e in candidates)
        MoveAlternative(
          exerciseId: e.id,
          name: e.name(language),
          reason: [
            equipmentLine(l10n, e.equipment),
            if (e.quiet) l10n.quiet,
          ].join(' · '),
        ),
    ];
  }

  /// Whether the move has a swap to offer.
  static bool canSwap(String? exerciseId) =>
      exerciseId != null && swapOptionsFor(exerciseId).isNotEmpty;

  /// The library's clip for a move, or null: R04 has nothing to show without
  /// one, so nothing opens it.
  static LibraryExercise? clipFor(String exerciseId) => ExerciseLibraryState
      .instance
      .clipFor(exerciseId, intakeRepository.read().lifeStage);

  /// Whether R01 and R11 offer the exercise library: only once the phone
  /// holds one. Asks for it on the way, so a woman verified since the app
  /// launched does not wait for the next launch to get it; the check is
  /// rate-limited and returns at once when it is not due.
  static bool get _exerciseLibraryReady {
    unawaited(ExerciseLibraryState.instance.refresh());
    return !ExerciseLibraryState.instance.library.isEmpty;
  }

  /// This week's challenge as Home and R03 state it, or null.
  static String? challengeLineFor(BuildContext context, WorkoutDay plan) {
    final progress = challengeFor(plan);
    if (progress == null) return null;
    final l10n = AppL10n.of(context);
    final challenge = progress.challenge;
    final name = localisedMove(
      l10n,
      plan.moves.firstWhere((m) => m.exerciseId == challenge.exerciseId),
    ).name;
    final amount = challenge.unit == ChallengeUnit.reps
        ? l10n.repsReps(countLabel(challenge.lastWeek))
        : l10n.secondsSeconds(countLabel(challenge.lastWeek));
    return challenge.kind == ChallengeKind.beat
        ? l10n.moveMoreThanLastWeeksAmount(name, amount)
        : l10n.moveMatchLastWeeksAmount(name, amount);
  }

  /// The authored milestone nearest to done that she has not earned.
  static MilestoneStanding? get _nextMilestone {
    final ahead = MilestonesSummary.from(
      catalogue: authoredMilestones,
      earnedAt: progressStore.rewards.milestones,
      counts: RewardsState.instance.milestoneCounts(progressStore),
    ).ahead;
    for (final standing in ahead) {
      // "Came back" is not something to aim at; it only happens. Programme
      // days are not counted on the phone, so a milestone measured in them
      // would stand at nothing however much she trained.
      if (standing.milestone.measure == MilestoneMeasure.cameBack ||
          standing.milestone.measure == MilestoneMeasure.programDays) {
        continue;
      }
      return standing;
    }
    return null;
  }

  /// Whether R10's kitten cheers: the first three sessions she ever finishes,
  /// and the session that counts her week.
  static bool get _cheerOnFinish {
    final summary = WorkoutSessionState.instance.lastSummary;
    if (summary == null) return false;
    return summary.credit.weekCountedNow ||
        progressStore.rewards.sessionsLogged <= 3;
  }

  /// What T02's last credit actually did, for R12.
  static CreditOutcome? lastRecallOutcome;

  /// Sets of today's session behind her and all of them, for the bar on the
  /// training screens. Null outside a live session.
  static ({int done, int total})? get _setsProgress {
    final session = WorkoutSessionState.instance;
    if (session.day == null || session.setsTotal <= 0) return null;
    return (done: session.setsDone, total: session.setsTotal);
  }

  /// Pops back to the R07 under this screen: R09 or R13 sits on R07, or on
  /// R08 over R07 when the set was changed there. Never more than two
  /// screens, so a stack shaped any other way is left where it is rather than
  /// emptied down to whatever happens to be first.
  static void _backToSet(BuildContext context) {
    final r07 = appRoutes['R07']!.name;
    final r06 = appRoutes['R06']!.name;
    var popped = 0;
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == r07 ||
          route.settings.name == r06 ||
          popped++ >= 2,
    );
  }

  /// Whether the set she is on is a hold, which R06 counts down; every other
  /// set is R07's. The callers spell out both `goTo`s so the route graph can
  /// see both edges.
  static bool _holdIsNext() {
    final set = WorkoutSessionState.instance.currentSet;
    final hold = set != null && set.reps == null && (set.holdSeconds ?? 0) > 0;
    return hold && screenIsOn('R06');
  }

  /// R09's "Up next": the move and set she goes back to.
  static String? _upNext(AppL10n l10n) {
    final session = WorkoutSessionState.instance;
    final move = session.currentMove;
    if (move == null) return null;
    return l10n.moveSetSet(
      localisedMove(l10n, move).name,
      countLabel(session.setIndex + 1),
    );
  }

  /// A finished workout, and the week's target when this one reached it.
  static void _trackWorkoutFinished(bool firstEver, WeekProgress before) {
    unawaited(
      analytics.track(AnalyticsEvent.sessionFinished, {
        AnalyticsProp.isFirstTime: AnalyticsValue.flag(firstEver),
      }),
    );
    if (weekTargetReached(before, todayRepository.day.week)) {
      unawaited(analytics.track(AnalyticsEvent.weekCounted));
    }
  }

  /// Whether the session that turned [before] into [after] is the one that
  /// reached the week's target. Once a week, not on every session past it.
  @visibleForTesting
  static bool weekTargetReached(WeekProgress before, WeekProgress after) =>
      after.sessionsTarget > 0 &&
      before.sessionsLogged < before.sessionsTarget &&
      after.sessionsLogged >= after.sessionsTarget;

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
  static FeatureFlags featureFlags = startingFlags();

  static final LocalePreference localePreference = InMemoryLocalePreference();

  /// Real phone sign-in, against the `own-hub` Firebase project.
  ///
  /// `static final` is lazy in Dart, so `FirebaseAuth.instance` is not touched
  /// until something first asks for the repository, which is always after
  /// `FirebaseBoot.start()` in `main()`. That ordering is not luck and should
  /// not be traded away for an eager field.
  ///
  /// It is also safe when Firebase did not come up at all: the repository
  /// resolves through `FirebaseBoot.isReady`, starts `signedOut`, and answers
  /// `AuthFailure.network` rather than throwing. A woman with no signal sees
  /// the honest message, not a crash.
  ///
  /// [FakeAuthRepository] is untouched and is still what the tests use. The
  /// one visible difference is that its printed test code no longer exists in
  /// this build, because `testCodeOf` returns null for anything that is not
  /// the fake.
  static final AuthRepository authRepository = FirebaseAuthRepository();

  /// Her uid, or null when nobody is signed in.
  ///
  /// Synchronous on purpose: `onGenerateRoute` cannot await, and the gate below
  /// has to answer before a route is built rather than a frame later.
  /// The health backup switch for A03, or null when there is no account to
  /// back up to. Built only when Firebase is up and she is signed in, because
  /// the consent store touches Firebase in its constructor.
  static HealthBackupController? healthBackupController() {
    if (!FirebaseBoot.isReady || signedInUid == null) return null;
    final controller = HealthBackupController(
      store: CallableHealthConsentStore(),
      // A pending withdrawal is retried only for the account that made it.
      uid: signedInUid,
      // N5: the server purged the cloud copy when it was last switched off,
      // so the whole history goes up again, not only what changed since.
      onEnabled: () => unawaited(
        CloudStore.instance.forgetHealthUploads().then(
          (_) => CloudStore.instance.syncNow(),
        ),
      ),
      onDisabled: () => unawaited(CloudStore.instance.forgetHealthUploads()),
    );
    // A03 is where she looks for it, so a withdrawal she made offline is
    // retried when it opens. Once per attempt, not on every redraw.
    if (HealthBackupPreference.instance.withdrawPending && !_withdrawRetrying) {
      _withdrawRetrying = true;
      unawaited(
        controller.retryPendingWithdraw().whenComplete(
          () => _withdrawRetrying = false,
        ),
      );
    }
    return controller;
  }

  static bool _withdrawRetrying = false;

  /// Start-up: if this phone thinks the health backup is on but the server
  /// holds no granted consent, turn it off here. The server wins.
  static Future<void> reconcileHealthBackup() async {
    final uid = signedInUid;
    final controller = healthBackupController();
    if (uid == null || controller == null) return;
    // A withdrawal she made offline is sent now; the cloud copy goes then.
    await controller.retryPendingWithdraw();
    await controller.reconcile(uid);
  }

  /// How long C07 waits for the cloud before choosing setup or Home (R9).
  static const Duration setupPullBound = Duration(seconds: 4);

  /// The pull C07 waits on. Replaced in tests.
  @visibleForTesting
  static Future<void> Function(String uid, Duration bound) cloudPull =
      CloudStore.instance.linkWithin;

  /// One bounded pull of her cloud copy before C07 chooses setup or Home.
  /// Returns within [setupPullBound] whatever the network does.
  static Future<void> pullBeforeSetupChoice() async {
    final uid = signedInUid ?? verificationBackend.currentUid;
    if (uid == null || intakeRepository.setupDone) return;
    try {
      await cloudPull(uid, setupPullBound).timeout(setupPullBound);
    } catch (_) {
      // Out of time: the phone's answer stands.
    }
  }

  // ------------------------------------------- Terms and Privacy (M1)

  /// The navigator of the running app, for the one sheet that can arrive
  /// from outside any screen: the legal update at launch. Set by the app's
  /// own state, one key per app, so a second app built in the same process
  /// (a test) gets a fresh navigator rather than the first one's.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Where acceptances are recorded. The callable when Firebase is up, an
  /// in-memory store otherwise. Replaced in tests.
  @visibleForTesting
  static LegalAcceptanceStore? legalStoreOverride;

  static LegalAcceptanceStore get legalStore =>
      legalStoreOverride ??
      (FirebaseBoot.isReady
          ? CallableLegalAcceptanceStore()
          : _localLegalStore);

  static final InMemoryLegalAcceptanceStore _localLegalStore =
      InMemoryLegalAcceptanceStore();

  /// True when the signed-in account has not accepted the Terms and Privacy
  /// Policy in force, so the legal update sheet must be answered.
  static bool legalUpdateDue = false;

  /// Sends a pending acceptance, or asks the server whether she has
  /// accepted the versions in force. Does nothing signed out or without a
  /// back end, and never fails: not knowing is asked again next time.
  static Future<void> reconcileLegal() async {
    final uid = signedInUid;
    if (uid == null || (!FirebaseBoot.isReady && legalStoreOverride == null)) {
      return;
    }
    final status = await reconcileLegalAcceptance(store: legalStore, uid: uid)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => LegalStatus.unknown,
        );
    legalUpdateDue = status == LegalStatus.needsAgreement;
  }

  /// The two documents in her language, or null while they have no address.
  static VoidCallback? openTermsFor(BuildContext context) =>
      LegalLinks.terms.isEmpty
      ? null
      : () => unawaited(
          openExternalLink(
            context,
            LegalLinks.localised(
              LegalLinks.terms,
              Localizations.localeOf(context).languageCode,
            ),
          ),
        );

  static VoidCallback? openPrivacyFor(BuildContext context) =>
      LegalLinks.privacyPolicy.isEmpty
      ? null
      : () => unawaited(
          openExternalLink(
            context,
            LegalLinks.localised(
              LegalLinks.privacyPolicy,
              Localizations.localeOf(context).languageCode,
            ),
          ),
        );

  /// The legal update sheet, when it is due. True when she may go on: it was
  /// not due, or she agreed. False when she chose to delete her account
  /// instead, in which case Your data is open.
  static Future<bool> answerLegalUpdate(BuildContext context) async {
    if (!legalUpdateDue) return true;
    final locale = Localizations.localeOf(context).languageCode;
    final agreed = await showLegalUpdateSheet(
      context,
      onOpenTerms: openTermsFor(context),
      onOpenPrivacy: openPrivacyFor(context),
      onAgree: () async {
        try {
          await legalStore.record(LegalAcceptance.now(locale));
          await PendingLegalAcceptance.erase();
          legalUpdateDue = false;
          return true;
        } catch (_) {
          return false;
        }
      },
    );
    if (!agreed && context.mounted) openYourData(context);
    return agreed;
  }

  /// At launch, for a signed-in woman: the pending acceptance is sent, and
  /// the sheet is shown over whatever opened if the versions in force are
  /// not accepted. Not awaited by the launch: the first frame never waits on
  /// the network.
  static Future<void> checkLegalAtLaunch() async {
    await reconcileLegal();
    if (!legalUpdateDue) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey?.currentState?.overlay?.context;
      if (context == null || !legalUpdateDue) return;
      unawaited(answerLegalUpdate(context));
    });
  }

  /// The app's own first screen, computed at the moment it is asked for.
  ///
  /// With an account required, the welcome screen (C01) is for a woman with
  /// no account and no verification on this phone. A verified woman opens on
  /// Home, and a signed-in one who is not verified yet also asks for Home,
  /// where the gate sends her to the check (C09) or to C14.
  ///
  /// A woman looking at the coach side (a coach only, or one who switched to
  /// it) opens on her own side once she is in: `K01` until her setup has been
  /// submitted, her desk (`K07`) after (R1-P17). Only while the coach app is
  /// on.
  static String get frontDoor => frontDoorFor(
    accountRequired: featureFlags.isOn(Feature.accountRequired),
    verified: isVerified,
    signedIn: signedInUid != null,
    coachSide:
        featureFlags.isOn(Feature.coachApp) &&
        RoleState.instance.roles?.active == AppRole.coach,
    coachSetupDone: CoachProfileState.instance.isSetupComplete,
  );

  /// [frontDoor] as a function of the facts it turns on.
  @visibleForTesting
  static String frontDoorFor({
    required bool accountRequired,
    required bool verified,
    required bool signedIn,
    bool coachSide = false,
    bool coachSetupDone = false,
  }) {
    if (accountRequired && !verified && !signedIn) {
      return appRoutes['C01']!.name;
    }
    // Signed in and not verified yet: Home, where the gate holds her at the
    // check whichever side she chose.
    if (coachSide && (verified || !accountRequired)) {
      return coachSetupDone ? appRoutes['K07']!.name : appRoutes['K01']!.name;
    }
    return appRoutes['T01']!.name;
  }

  // ------------------------------------------------ roles and invites

  /// Where her role choice is recorded and read back (R1-P17). The callable
  /// and her user document when Firebase is up, memory otherwise.
  @visibleForTesting
  static RoleRecordStore? roleRecordStoreOverride;

  static RoleRecordStore get roleRecordStore =>
      roleRecordStoreOverride ??
      (FirebaseBoot.isReady ? FirebaseRoleRecordStore() : _localRoleStore);

  static final InMemoryRoleRecordStore _localRoleStore =
      InMemoryRoleRecordStore();

  /// A verified woman whose phone has no roles: the server's copy, if it has
  /// one, becomes hers. Bounded inside the store; never throws.
  static Future<void> restoreRolesFromServer(BuildContext context) async {
    final uid = signedInUid;
    if (uid == null ||
        !featureFlags.isOn(Feature.coachApp) ||
        RoleState.instance.roles != null) {
      return;
    }
    final scope = RoleScope.maybeOf(context);
    final kept = await roleRecordStore.read(uid);
    if (kept == null) return;
    RoleState.instance.keep(kept);
    scope?.value = kept;
  }

  /// Invite codes: hers to share as a coach, or hers to redeem (R1-P18).
  @visibleForTesting
  static CoachInviteStore? coachInviteStoreOverride;

  static CoachInviteStore get coachInviteStore =>
      coachInviteStoreOverride ??
      (FirebaseBoot.isReady ? CallableCoachInviteStore() : _localInviteStore);

  static final InMemoryCoachInviteStore _localInviteStore =
      InMemoryCoachInviteStore();

  /// `C01`: the code her coach sent, kept on this phone until she is in.
  static Future<void> keepInviteCode(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = AppL10n.of(context).savedOnceYouAreInWeWill;
    final code = await showInviteCodeSheet(
      context,
      initial: CoachInviteState.instance.pendingCode,
    );
    if (code == null) return;
    CoachInviteState.instance.keepPending(code);
    showHonestNoticeOn(messenger, saved);
  }

  /// Once she has passed the check, the code she kept is redeemed once (see
  /// [CoachInviteState.redeem]) and she is told how it went.
  static Future<void> redeemPendingInvite() async {
    final outcome = await CoachInviteState.instance.redeem(
      coachInviteStore,
      allowed:
          featureFlags.isOn(Feature.coachApp) &&
          isVerified &&
          signedInUid != null,
    );
    if (outcome == null || outcome == InviteRedemption.unreachable) return;
    final context = navigatorKey?.currentState?.overlay?.context;
    if (context == null || !context.mounted) return;
    final l10n = AppL10n.of(context);
    showHonestNotice(
      context,
      outcome == InviteRedemption.linked
          ? l10n.yourCoachHasYourRequest
          : l10n.yourCoachsCodeDidNotWorkAsk,
    );
  }

  /// `K07`'s "Invite a client": her code, in a WhatsApp message she sends to
  /// whoever she chooses. Said plainly when it cannot be made or opened.
  static Future<void> shareCoachInvite(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final String code;
    try {
      code = await coachInviteStore.create();
    } catch (_) {
      showHonestNoticeOn(messenger, l10n.weCouldNotMakeYourCodeTry);
      return;
    }
    final shown = displayInviteCode(code);
    final opened = await openOutside(
      whatsAppShareUri(l10n.joinMeOnOwnHubTheTraining(shown)),
    );
    if (!opened) {
      showHonestNoticeOn(messenger, l10n.weCouldNotOpenWhatsappYourCode(shown));
    }
  }

  /// `K02`: the camera, then the upload, then a word if it did not go.
  static Future<void> addCertificatePhoto(
    BuildContext context,
    String credentialId,
  ) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final jpeg = await photographCertificate(context);
    if (jpeg == null) return;
    final result = await CoachProfileState.instance.submitCertificatePhoto(
      credentialId: credentialId,
      jpeg: jpeg,
      signedInUid: signedInUid,
    );
    switch (result) {
      case CertificateSubmission.sent:
        return;
      case CertificateSubmission.refused:
        showHonestNoticeOn(messenger, l10n.coachingIsNotOpenYetSoYour);
      case CertificateSubmission.unreachable:
      case CertificateSubmission.invalid:
        showHonestNoticeOn(messenger, l10n.weCouldNotSendYourCertificateCheck);
    }
  }

  /// The server said she is approved (C14 live update, or C15 hearing
  /// "already verified"). That opens the product by itself ([isVerified]);
  /// the token refresh is started and retried later if it fails.
  ///
  /// The approval is newer than any claim read before it, so it stands until
  /// the refresh it starts reads a claim: a fresh `false` then closes the
  /// gate again (N2), and a refresh the network refuses leaves her in (R10).
  static void markApprovedByServer() {
    _freshClaimRead = false;
    serverVerification = const ServerVerification(
      ServerVerificationState.approved,
    );
    unawaited(refreshVerificationClaim());
  }

  /// The server did not accept her sign-in (N4): a rejected ID token (a
  /// disabled, deleted or revoked account), or an account that did not sign
  /// in with a phone. Signs this phone out of it the way deletion does, so
  /// every source of "verified" goes too, and opens the phone number screen
  /// (`C06`) over the front door (`C01`). Her own week on this phone stays.
  static Future<void> signInAgain(BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      await const ThisPhoneWipe().signOut();
    } catch (_) {
      // Signed out or not, the way forward is the same screen.
    }
    if (!navigator.mounted) return;
    unawaited(
      navigator.pushNamedAndRemoveUntil(appRoutes['C01']!.name, (_) => false),
    );
    unawaited(navigator.pushNamed(appRoutes['C06']!.name));
  }

  /// A02's "Your data" sheet, also opened by "Delete my account instead" on
  /// the legal update sheet.
  static void openYourData(BuildContext context) {
    // All three captured before the sheet opens: after the pop below this
    // builder's context is gone, while the navigator and the messenger
    // both live above it and survive.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final gone = AppL10n.of(context).yourDataIsGoneTheAppIs;
    final unfinished = AppL10n.of(context).yourDeletionDidNotFinishOnOur;
    unawaited(
      showYourDataSheet(
        context,
        // The server deletion when there is an account, and this phone
        // always once the server has the request. See `deleteAccount`.
        onDelete: deleteAccount,
        hasAccount: FirebaseBoot.isReady && signedInUid != null,
        onOpenPrivacy: openPrivacyFor(context),
        onAskForCopy: askForACopyFor(context),
      ).then((result) {
        if (result == null || !navigator.mounted) return;
        // Day one, literally: everything she opened on the way here is
        // about data that no longer exists, so the stack goes with it.
        // The front door is computed now, after the wipe: Home while no
        // account is required, C01 when one is (R2). Popping to the first
        // route used to leave her on Home with the gate still open.
        legalUpdateDue = false;
        navigator.pushNamedAndRemoveUntil(frontDoor, (_) => false);
        showHonestNoticeOn(
          messenger,
          result == AccountDeletionResult.done ? gone : unfinished,
        );
      }),
    );
  }

  /// "Ask for a copy" (M8): an email to the privacy mailbox, in her
  /// language, asking only for the phone number on the account. Null when
  /// there is no mailbox.
  static VoidCallback? askForACopyFor(BuildContext context) {
    if (LegalLinks.privacyEmail.isEmpty) return null;
    final l10n = AppL10n.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: LegalLinks.privacyEmail,
      query: _mailQuery({
        'subject': l10n.copyOfMyOwnHubData,
        'body': '${l10n.thePhoneNumberOnMyAccount} ',
      }),
    );
    return () {
      unawaited(analytics.track(AnalyticsEvent.dataCopyRequested));
      unawaited(openExternalLink(context, uri.toString()));
    };
  }

  /// A mailto query with spaces as %20, which every mail app reads (a `+`
  /// is shown literally by some).
  static String _mailQuery(Map<String, String> fields) => fields.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');

  static String? get signedInUid => switch (authRepository.current) {
    AuthSignedIn(:final uid) => uid,
    _ => null,
  };

  // ------------------------------------------------- The identity check (G1)
  //
  // One object per sign-up, holding the capture service and the verification
  // repository over ONE `VerificationEvidence` and ONE liveness session. The
  // reason it is one object rather than two fields is written at the top of
  // `features/signup/data/identity_check.dart`, and it is worth repeating here
  // because this is the file that could get it wrong: `C10` and `C10b` fill an
  // evidence holder and `C12` submits one, and if those are two objects the
  // failure surfaces on a server, in another language, as "the card is
  // missing".

  static IdentityCheck? _identityCheck;

  /// The check she is in the middle of, made on first use.
  ///
  /// Lazy rather than eager because a deep link can land on `C12` without ever
  /// passing `C08`, and because construction reaches for Firebase — which is
  /// not up in a widget test and may not be up on a handset either.
  static IdentityCheck get identityCheck =>
      _identityCheck ??= _newIdentityCheck();

  /// Starts a fresh check and drops whatever the last one was holding.
  ///
  /// Called when she enters the flow at `C08`. A second attempt gets a second
  /// [IdentityCheck] with empty evidence and no challenge, which is what "she
  /// photographs the card again" has to mean: reusing the old one would submit
  /// frames from the attempt before against a session that is already spent.
  static void beginIdentityCheck() {
    _identityCheck?.abandon();
    _identityCheck = _newIdentityCheck();
    _livenessOffline = 0;
    consentRecorded = false;
    awaitingReviewer = false;
    // A new attempt can raise a new flag; she asks for that call afresh.
    reviewAsked = false;
    unawaited(VerificationMemory.forgetReviewAsked());
    _automaticSubmitted = false;

    // Her stored agreement, if she already gave one to this wording. Read now,
    // unawaited, while she is still reading `C09`: it means a woman who
    // consented yesterday and came back today is not stopped by the deep-link
    // guard below for a decision she has already made.
    final uid = signedInUid;
    if (uid != null) unawaited(_readStoredConsent(uid));
  }

  /// Lifts [consentRecorded] when she has already agreed to this wording.
  ///
  /// Never lowers it, and never throws. A failed read leaves the flag where it
  /// was, which costs her one screen and a second tap — the opposite mistake,
  /// opening a camera because a read failed, is the one this whole arrangement
  /// exists to prevent.
  static Future<void> _readStoredConsent(String uid) async {
    try {
      if (await identityCheck.mayOpenCamera(uid)) consentRecorded = true;
    } catch (_) {
      // Offline, or the consent document is not readable. Either way she is
      // asked again, and re-agreeing to the same version lands on the same
      // document rather than filling her consent history with duplicates.
    }
  }

  /// The pieces of the check, resolved against what this build actually has.
  ///
  /// `FirebaseBoot` is deliberately built so a failed `initializeApp` never
  /// stops the app opening, so this can run with no Firebase at all — in a
  /// widget test, on a handset with broken Play Services, or in the first
  /// release, which ships with verification switched off. Both real
  /// implementations touch `FirebaseFunctions` in their constructors and throw
  /// `[core/no-app]` there, so neither may be built unconditionally. The
  /// refusing pair is honest instead: no camera lies about taking a picture, no
  /// provider invents a decision, and a woman reaches a reviewer rather than a
  /// crash.
  static IdentityCheck _newIdentityCheck() => FirebaseBoot.isReady
      ? IdentityCheck(consent: CallableCaptureConsentStore())
      : IdentityCheck(
          consent: InMemoryCaptureConsentStore(),
          provider: const UnavailableVerificationProvider(),
          reviews: const UnavailableReviewRequester(),
        );

  /// The three screens that open a camera.
  ///
  /// `C10` and `C10b` photograph the card, `C11` runs the liveness challenge.
  /// Nothing else in the product opens a lens, and `C15`'s reviewer path never
  /// reaches any of them — which is what makes the niqab route camera-free
  /// structurally rather than by promise.
  static const Set<String> _opensALens = {'C10', 'C10b', 'C11'};

  /// Liveness starts in this attempt that failed for want of a network. The
  /// reviewer is offered beside "Try again" from the third.
  static int _livenessOffline = 0;

  /// Whether her agreement has been written down in this sign-up.
  ///
  /// The screen that writes it is `C09b`, and it only reports back once the
  /// write has returned. This exists because `onGenerateRoute` cannot await the
  /// store: without it, `/signup/c10` typed as a deep link would open a lens on
  /// a woman who has agreed to nothing.
  static bool consentRecorded = false;

  /// Whether she is held at `C14` rather than sent to the check.
  ///
  /// Derived from the server: any `users/{uid}.verification.state` (pending,
  /// retry, rejected, or approved but not yet in her token) means C14 is the
  /// screen that tells her the truth, and that survives a restart because it
  /// is read at start-up ([readVerificationStatus]). The session flag is the
  /// local echo set the moment `C12` or `C15` hears the server queue her,
  /// before the document read catches up.
  static bool get awaitingReviewer =>
      _awaitingInSession ||
      (serverVerification != null &&
          serverVerification!.state != ServerVerificationState.approved);
  static set awaitingReviewer(bool value) => _awaitingInSession = value;
  static bool _awaitingInSession = false;

  /// What the server last said about her check, or null when it has said
  /// nothing. See `features/signup/domain/server_verification.dart`.
  static ServerVerification? serverVerification;

  /// The route argument `C09` pushes `C09b` with, so `C09b` does not repeat
  /// the promise she has just read.
  static const String _fromWhyWeCheck = 'fromWhyWeCheck';

  /// Where `record_pledge` goes. Firebase's when it is up; with no back end
  /// the agreement stays on this phone. Replaceable in tests.
  static PledgeStore? _pledgeStore;
  static PledgeStore get pledgeStore => _pledgeStore ??= FirebaseBoot.isReady
      ? CallablePledgeStore()
      : const LocalOnlyPledgeStore();
  @visibleForTesting
  static set pledgeStore(PledgeStore? value) => _pledgeStore = value;

  /// She agreed to the community's rules: kept on this phone at once, and
  /// sent to the server when she is signed in. The phone's record is what
  /// opens the community; the server's is the dated consent record, and a
  /// call that fails is not retried.
  static void recordPledge(BuildContext context) {
    PledgeState.instance.agree();
    final locale = Localizations.localeOf(context).languageCode;
    if (signedInUid != null) {
      unawaited(pledgeStore.record(locale: locale).catchError((Object _) {}));
    }
  }

  /// Schedules her training reminders on this phone. The plugin on a phone,
  /// nothing in a test or on a desktop. Replaceable in tests.
  static ReminderScheduler? _reminderScheduler;
  static ReminderScheduler get reminderScheduler =>
      _reminderScheduler ??= ReminderScheduler.forPlatform();
  static set reminderScheduler(ReminderScheduler? value) =>
      _reminderScheduler = value;

  /// The words her notifications carry, in [l10n]'s language.
  static ReminderText reminderText(AppL10n l10n) => ReminderText(
    title: 'Own Hub',
    body: l10n.yourSessionIsReadyWhenYouAre,
    channelName: l10n.trainingReminders,
    channelDescription: l10n.aNoteOnTheDaysYouChose,
    logBody: l10n.trainedTodayAddItInATap,
    // As many as [kCheckInVariants]: the plan picks one by index.
    checkInBodies: [
      l10n.aShortOneStillCountsWheneverYoure,
      l10n.newMovesAreWaitingInTheLibrary,
      l10n.yourPlanIsWhereYouLeftIt,
      l10n.aLittleMovementTodayNoPressure,
    ],
    restBody: l10n.restIsOverYourNextSetIs,
    checkInChannelName: l10n.gentleCheckIns,
    checkInChannelDescription: l10n.aFriendlyNudgeIfYouveBeenAway,
    restChannelName: l10n.restTimer,
    restChannelDescription: l10n.tellsYouWhenYourRestBetweenSets,
  );

  /// The training reminders sheet, from `R10` or `A01`.
  ///
  /// Opening it answers `R10`'s offer, whatever she does next. Permission is
  /// asked when she taps "Remind me" and nowhere else; her days are kept only
  /// once the phone has agreed to show them, so the app never says reminders
  /// are on while the phone blocks every one.
  static Future<void> openTrainingReminders(BuildContext context) async {
    final state = ReminderState.instance;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppL10n.of(context);
    state.offered = true;
    AppChanges.bump();
    // A value moment, so the sentence before the phone's own prompt is
    // worth reading. Skipped once she has said yes, and "Not now" is final
    // for this visit: nothing was asked of the phone.
    if (!state.permitted) {
      final go = await showNotificationExplainer(context);
      if (go != true || !context.mounted) return;
    }
    await showReminderSheet(
      context,
      sessionsAWeek: todayRepository.day.week.sessionsTarget,
      current: state.schedule,
      onSave: (reminders) async {
        final permission = await reminderScheduler.requestPermission();
        if (permission != ReminderPermission.granted) {
          _trackReminders(remindersOutcomeToken(permission));
          return permission;
        }
        final previous = (state.schedule, state.permissionGranted);
        state.schedule = reminders;
        state.permissionGranted = true;
        try {
          await NotificationSync.reapply(
            reminderScheduler,
            reminderText(l10n),
            now: AppClock.now(),
            quiet: false,
          );
        } catch (_) {
          state.schedule = previous.$1;
          state.permissionGranted = previous.$2;
          _trackReminders('unavailable');
          return ReminderPermission.unavailable;
        }
        AppChanges.bump();
        _trackReminders('on');
        showHonestNoticeOn(messenger, l10n.remindersAreOn);
        return ReminderPermission.granted;
      },
      onTurnOff: () async {
        _trackReminders('off');
        // Saved before the flag existed, her days still prove she allowed it.
        state.permissionGranted = state.permitted;
        state.schedule = null;
        AppChanges.bump();
        // Her days and "Trained today?" go; the check-ins and the rest alert
        // are their own switches and stay as she left them.
        await NotificationSync.reapply(
          reminderScheduler,
          reminderText(l10n),
          now: AppClock.now(),
        );
        showHonestNoticeOn(messenger, l10n.remindersAreOff);
      },
      onOpenSettings: () => unawaited(openAppSettings()),
    );
  }

  /// Sets her notifications again, in the language the app is in. The phone
  /// keeps them by itself; this repairs a restored backup, a new time zone, a
  /// changed language or a day that has moved on. Asks for nothing.
  static Future<void> reapplyTrainingReminders(AppL10n l10n) =>
      NotificationSync.reapply(
        reminderScheduler,
        reminderText(l10n),
        now: AppClock.now(),
      );

  /// She opened the app: the gentle check-ins start counting from now.
  ///
  /// Not written to disk by itself: the next launch notes it again before
  /// anything reads it, so an open that changed nothing else costs no write.
  static Future<void> noteAppOpened(AppL10n l10n) {
    ReminderState.instance.noteActive(AppClock.now());
    return reapplyTrainingReminders(l10n);
  }

  /// She logged a session, trained or recalled: today's "Trained today?" is
  /// answered and the check-ins start counting from now.
  static Future<void> noteSessionLogged() {
    final now = AppClock.now();
    ReminderState.instance
      ..lastSessionAt = now
      ..lastActiveAt = now;
    // The session's own write carries these with it.
    return NotificationSync.reapplyLast(reminderScheduler, now: now);
  }

  /// One of the extra switches on `A01`.
  static Future<void> setNotificationPrefs(NotificationPrefs prefs) {
    ReminderState.instance.prefs = prefs;
    AppChanges.bump();
    return NotificationSync.reapplyLast(reminderScheduler, now: AppClock.now());
  }

  /// Registers this phone for the approval push (`C14`). Firebase's when it
  /// is up, else one that says push cannot reach this phone. Replaceable in
  /// tests.
  static PushRegistrar? _pushRegistrar;
  static PushRegistrar get pushRegistrar =>
      _pushRegistrar ??= FirebaseBoot.isReady
      ? FirebasePushRegistrar()
      : const UnavailablePushRegistrar();
  @visibleForTesting
  static set pushRegistrar(PushRegistrar? value) => _pushRegistrar = value;

  /// Keeps this phone's push token current and listens for the approval push
  /// while the app is open. Quiet for a phone that never opted in.
  static Future<void> startPushWatch(String locale) async {
    final uid = signedInUid;
    if (uid == null) return;
    await pushRegistrar.watch(
      uid: uid,
      locale: locale,
      // The system shows nothing while the app is open. A fresh token
      // carries the new claim, and the waiting screen moves on with it.
      onApproval: () => unawaited(refreshVerificationClaim()),
    );
  }

  /// Which way she reached `C15`, sent to `request_review`.
  ///
  /// Setting it clears [reviewAskedWhileChecking], so only the slow-check
  /// button on `C12`, which sets that flag after this, ever leaves it on.
  static ReviewPath get pendingReviewPath => _pendingReviewPath;
  static set pendingReviewPath(ReviewPath path) {
    _pendingReviewPath = path;
    reviewAskedWhileChecking = false;
  }

  static ReviewPath _pendingReviewPath = ReviewPath.niqab;

  /// True when she asked for a reviewer from a slow `C12`, while her check
  /// was still running. `C15` then does not say the check "could not start".
  static bool reviewAskedWhileChecking = false;

  /// Whether she has asked for a reviewer's call (C15, or "Ask for the call"
  /// on C14). A flag the automatic check raised by itself is not her asking:
  /// until she does, C14 says a reviewer can only call after she asks (R4).
  static bool reviewAsked = false;

  /// Records that she asked, for this session and on this phone.
  static void markReviewAsked() {
    reviewAsked = true;
    final uid = signedInUid;
    if (uid != null) unawaited(VerificationMemory.rememberReviewAsked(uid));
  }

  /// Reads `users/{uid}.verification` at start-up (S8), after
  /// [readVerificationClaim]. When the server says approved but the token
  /// does not carry the claim yet, the token is refreshed and the claim read
  /// again. `approved` itself already opens the product ([isVerified]).
  ///
  /// Never throws. Bounded as part of [readVerificationAtLaunch].
  static Future<void> readVerificationStatus() async {
    final backend = verificationBackend;
    if (!backend.isReady) return;
    final uid = backend.currentUid;
    if (uid == null) {
      serverVerification = null;
      return;
    }
    try {
      reviewAsked = await VerificationMemory.reviewAskedUid() == uid;
      final read = await backend.readStatus(uid);
      if (read != null) serverVerification = read;
      if (serverVerification?.state == ServerVerificationState.approved &&
          !_verifiedClaim) {
        await refreshVerificationClaim();
      }
    } catch (_) {
      // Nothing read: the claim alone decides, as before.
    }
  }

  /// Forces a fresh ID token and re-reads the `verified` claim.
  static Future<void> refreshVerificationClaim() async {
    final backend = verificationBackend;
    final uid = backend.currentUid;
    if (!backend.isReady || uid == null) return;
    final generation = _claimGeneration;
    try {
      final verified = await backend
          .verifiedClaim(forceRefresh: true)
          .timeout(const Duration(seconds: 10));
      _settleClaim(uid, verified, generation);
    } catch (_) {
      // Leaves the claim as it was. Fail closed.
    }
  }

  /// Live `users/{uid}.verification` for C14, or null with no back end.
  static Stream<ServerVerification?>? verificationStatusUpdates() {
    final backend = verificationBackend;
    final uid = backend.currentUid;
    if (!backend.isReady || uid == null) return null;
    return backend.watchStatus(uid)?.map((next) {
      if (next != null) serverVerification = next;
      return next;
    });
  }

  /// Whether the automatic path has been submitted for this attempt.
  static bool _automaticSubmitted = false;

  /// The repository `C12` listens to, with the submit done exactly once.
  ///
  /// The submit cannot go in the builder body: the builder is inside a
  /// `RedrawOnChange` and runs again on every change made while this screen is
  /// the one on top, so an unguarded call would start a new paid check on each
  /// rebuild. The guard is not weakened by that screen being the one on top —
  /// `C12` is where she waits, so it is on top for the whole of it. It cannot
  /// go in `CheckingView` either without that screen deciding when a check
  /// starts, which is the router's job — `C15` is the other caller and it
  /// submits a different method.
  static VerificationRepository _checkingRepository() {
    final check = identityCheck;
    if (!_automaticSubmitted) {
      _automaticSubmitted = true;
      unawaited(analytics.track(AnalyticsEvent.verificationSubmitted));
      // Not awaited: `submit` returns the state to show *while* the check runs
      // and `C12` is already listening for the outcome.
      unawaited(
        check.verification.submit(method: VerificationMethod.automatic),
      );
    }
    return check.verification;
  }

  static final InMemoryIntakeRepository intakeRepository =
      InMemoryIntakeRepository();
  static final InMemoryTodayRepository todayRepository =
      InMemoryTodayRepository(weekSource: weekFromStore);

  /// Her week as its week document has it, for the week containing [now], or
  /// null when she has no document for that week yet. What Today re-reads
  /// when the day or the week turns over, so Home and Progress agree.
  static WeekProgress? weekFromStore(DateTime now) {
    final doc = progressStore.weeks[WeekKey.of(now).id];
    if (doc == null) return null;
    return WeekProgress(
      sessionsLogged: doc.sessionsLogged,
      sessionsTarget: doc.sessionsTarget,
      repairedByRestWeek: doc.repairedByRestWeek,
    );
  }

  /// Runs when the app opens and every time it comes back: her day moves on
  /// if the date has, weeks that have ended are closed (empty ones included,
  /// D41), and Home's copy of the week is read again from the week document.
  ///
  /// Nothing did any of this, so a week never closed, a run never ended, the
  /// rest-week bank never filled and Home kept the day she last opened it on.
  static void startOfDay([DateTime? now]) {
    final on = now ?? AppClock.now();
    todayRepository.rollTo(on);
    RewardsState.instance.closeStaleWeeks(progress: progressStore, now: on);
    todayRepository.refresh();
    AppChanges.bump();
  }

  /// This week's challenge against her own last week (D38), with her progress
  /// on it, for the plan she is training. Null when it is switched off or there
  /// is no last week to compare with.
  static ChallengeProgress? challengeFor(WorkoutDay plan, {DateTime? now}) {
    if (!featureFlags.isOn(Feature.weeklyChallenge)) return null;
    final on = now ?? AppClock.now();
    final week = WeekKey.of(on);
    // Home, Train and the player all ask on every redraw, and each answer
    // walks her whole set history twice. The history only ever grows (a set is
    // flushed once), so the same week, plan, target and number of flushes give
    // the same answer.
    final target =
        progressStore.weeks[week.id]?.sessionsTarget ??
        progressStore.goal.sessionsTarget;
    final key = (
      week.id,
      plan.id,
      Object.hashAll(plan.moves.map((m) => m.exerciseId)),
      target,
      trainRepository.flushes.length,
    );
    final held = _challengeMemo;
    if (held != null && held.key == key) return held.value;
    final value = _challengeUncached(plan, week, on, target);
    _challengeMemo = (key: key, value: value);
    return value;
  }

  static ({Object key, ChallengeProgress? value})? _challengeMemo;

  /// Forgets the held challenge. Tests, and anything that swaps her history
  /// without changing its length.
  @visibleForTesting
  static void forgetChallengeMemo() => _challengeMemo = null;

  static ChallengeProgress? _challengeUncached(
    WorkoutDay plan,
    WeekKey week,
    DateTime on,
    int target,
  ) {
    final lastWeek = WeekKey.of(DateTime(on.year, on.month, on.day - 7));
    String? liveDay(String sessionId) {
      final session = trainRepository.sessionById(sessionId);
      return session != null && session.source == SessionSource.live
          ? session.dateKey
          : null;
    }

    const own = OwnBestChallenge();
    final challenge = own.choose(
      week: week,
      plan: plan.moves,
      sessionsTarget: target,
      lastWeek: own.totals(
        lastWeek,
        trainRepository.flushes,
        liveDayOf: liveDay,
      ),
    );
    if (challenge == null) return null;
    return own.progress(
      challenge,
      own.totals(week, trainRepository.flushes, liveDayOf: liveDay),
    );
  }

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
        alternativesFinder: swapOptionsFor,
        onFlushed: ({session, required exerciseId, required sets}) {
          final bests = sessionBests.record(
            session: session,
            exerciseId: exerciseId,
            sets: sets,
          );
          progressStore.rewards = progressStore.rewards.copyWith(
            bestsCount: personalBestLedger.bestsCount,
          );
          // A best that beat one she had pays (D41), and R10 states it with
          // the value it beat. A first mark on a new move counts toward her
          // tally as before, and pays nothing.
          if (session != null && bests.counted.isNotEmpty) {
            final paid = RewardsState.instance.creditPersonalBests(
              bests.counted,
              sessionId: session.id,
              progress: progressStore,
            );
            WorkoutSessionState.instance.noteBests(
              session.id,
              bests.counted,
              points: paid,
            );
          }
          // Her first logged set is her first-week step, as it lands — not
          // only once the whole session is over.
          if (session != null) {
            unawaited(todayRepository.completeStep(FirstWeekStep.logSet));
          }
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
  static final InMemoryDietaryProfileRepository dietaryRepository =
      InMemoryDietaryProfileRepository();

  static final InMemoryPrivacyRepository privacyRepository =
      InMemoryPrivacyRepository();
  static final PrivacySettingsService privacyService = PrivacySettingsService(
    privacyRepository,
  );

  /// Blocking, wrapped so that it actually hides her.
  ///
  /// The record alone changed nothing anyone could see: `hiddenAuthors` is what
  /// the feed, Explore, the groups and her profile filter on, and nothing wrote
  /// to it. [BlockingService] is the Function's half, done here because this
  /// build has no Functions. Every caller of `blockService` gets it.
  static final BlockingService blockService = BlockingService(
    InMemoryBlockService(selfUid: _selfUid),
    store: communityStore,
  );
  static final InMemoryReportService reportService = InMemoryReportService(
    reporterUid: _selfUid,
  );
  static final InMemoryNotificationsRepository notificationsRepository =
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
  /// Cached here and kept in Firestore: a save is written to the server first
  /// (`saveToLibrary`), and the cache is read from it once a run
  /// (`ensureAdminLibraryLoaded`). With no server reachable, a save stays on
  /// this phone and the console says so.
  static final RemoteContentRepository contentRepository =
      RemoteContentRepository(
        rows: seedContentLibrary(),
        documents: () =>
            contentDocumentsOverride ?? AdminBackends.contentDocuments(),
        seedRecipes: seedRecipesJson,
      );

  static Map<String, Object?>? _seedRecipesJson;

  /// The bundled recipe seed as JSON, read and parsed once a run. A console
  /// recipe save reads its version and sections from it.
  static Future<Map<String, Object?>> seedRecipesJson() async =>
      _seedRecipesJson ??= (jsonDecode(
        await rootBundle.loadString(kRahmaRecipesAsset),
      ) as Map).cast<String, Object?>();

  /// Tests point the library at an in-memory server here.
  static ContentDocuments? contentDocumentsOverride;

  static Future<void>? _adminLibraryLoad;

  /// The library as the server holds it, and the sections of her book, read
  /// once a run, the first time a console screen draws them. Until they land
  /// the screens show the cache. Callers in a build do not wait for it.
  static Future<void> ensureAdminLibraryLoaded() =>
      _adminLibraryLoad ??= _loadAdminLibrary();

  static Future<void> _loadAdminLibrary() async {
    try {
      final book = await SeededRecipeLibrary().load();
      adminRecipeSections = [
        for (final s in book.sections) (s.sectionId, s.titleEn),
      ];
    } catch (_) {
      // No sections means a recipe can be kept as a draft, not shown.
    }
    AppChanges.bump();
    if (await contentRepository.loadFromServer()) AppChanges.bump();
    await loadMediaRegister();
  }

  /// Z10's list: every file `tools/upload_media.py` put in the content
  /// library, from its register. What Z12, Z18 and Z03 offer to choose.
  static Future<void> loadMediaRegister() async {
    final docs = contentDocumentsOverride ?? AdminBackends.contentDocuments();
    if (docs == null) return;
    try {
      final register = await docs.readCollection('mediaLibrary');
      adminMediaBundle = MediaBundle([
        for (final entry in register.values)
          if (entry['name'] case final String name)
            MediaFile(
              name: name,
              bytes: (entry['bytes'] as num?)?.toInt() ?? 0,
              kind: entry['kind'] == 'video'
                  ? MediaKind.video
                  : MediaKind.picture,
            ),
      ]);
      AppChanges.bump();
    } catch (_) {
      // The list stays as it was; nothing is invented.
    }
  }

  /// Rows of one collection, for Z02, Z04, Z06 and Z07.
  static List<ImportRow> adminRowsNow(ContentCollection collection) {
    unawaited(ensureAdminLibraryLoaded());
    return contentRepository.rowsNow(collection);
  }

  /// Z01's counts, starting the server read on the first draw.
  static Map<ContentCollection, CollectionStatus>
  get adminLibraryStatusLoading {
    unawaited(ensureAdminLibraryLoaded());
    return adminLibraryStatus;
  }

  /// The sections of her book a console recipe can be placed in.
  static List<(String, String)> adminRecipeSections = const [];

  /// [adminRecipeSections], starting the read on the first draw of Z12.
  static List<(String, String)> get adminRecipeSectionsLoading {
    unawaited(ensureAdminLibraryLoaded());
    return adminRecipeSections;
  }

  /// Z03, Z05, Z12 and Z13's one way to store a row: the server first, then
  /// the cache, then close. A refusal keeps the form open and says why.
  static Future<void> saveToLibrary(
    BuildContext context, {
    required ContentCollection collection,
    required Map<String, String> values,
    List<AuthoredSession>? sessions,
    bool published = false,
  }) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      final outcome = await contentRepository.saveToLibrary(
        collection: collection,
        values: values,
        sessions: sessions,
        published: published,
      );
      adminEditingRow = const <String, String>{};
      showHonestNoticeOn(
        messenger,
        outcome == ContentSaveOutcome.saved
            ? l10n.savedToTheLibrary
            : l10n.savedOnThisPhoneOnlySignIn,
      );
      unawaited(navigator.maybePop());
      AppChanges.bump();
    } on RecipeNotReady {
      showHonestNoticeOn(messenger, l10n.thisRecipeCannotGoToMembersYet);
    } on WorkoutNotReady {
      showHonestNoticeOn(messenger, l10n.thisProgrammeCannotGoToMembersYet);
    } catch (_) {
      showHonestNoticeOn(messenger, l10n.couldNotSaveCheckTheConnectionAnd);
    }
  }

  /// Z09's commit. One batch; a refusal leaves the library as it was and
  /// says why.
  static Future<void> commitImport(
    BuildContext context,
    List<ImportRow> rows,
  ) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await contentRepository.saveAll(rows);
      AppChanges.bump();
    } on RecipeNotReady {
      showHonestNoticeOn(messenger, l10n.thisRecipeCannotGoToMembersYet);
    } catch (_) {
      showHonestNoticeOn(messenger, l10n.couldNotSaveCheckTheConnectionAnd);
    }
  }

  /// Advice for the move she is on, from her own history, or null.
  static LoadAdvice? _adviceFor(PlannedMove? move) => loadAdviceFor(
    trainRepository,
    move,
    exceptSessionId: WorkoutSessionState.instance.sessionId,
  );

  static String _kgLabel(AppL10n l10n, double kg) =>
      '${weightLabel(kg)} ${l10n.kg}';

  /// The one line R07 and R08 show about the weight of a loaded move: why it
  /// went up, why it did not, or how to record it. Null for a bodyweight move.
  static String? _lineFor(AppL10n l10n, PlannedMove move, LoadAdvice? advice) {
    if (!move.needsEquipment) return null;
    if (advice == null) {
      return move.sets.any((s) => s.weightKg != null)
          ? null
          : l10n.tapChangeToAddTheWeightYou;
    }
    final last = _kgLabel(l10n, advice.lastWeightKg);
    return switch (advice.decision.action) {
      'increase' => l10n.youFinishedEverySetAtWeightTry(
        last,
        _kgLabel(l10n, advice.startKg),
      ),
      'review' => l10n.itHasBeenAWhileSinceWeight(last),
      _ => l10n.lastTimeYouDidWeightStayThere(last),
    };
  }

  /// [move] carrying the weight to open on, and the line that explains it.
  static ({PlannedMove move, String? line}) loadFor(
    BuildContext context,
    PlannedMove move,
  ) {
    final l10n = AppL10n.of(context);
    final advice = _adviceFor(move);
    return (
      move: advice == null
          ? move
          : withSuggestedWeight(
              move,
              advice.startKg,
              _kgLabel(l10n, advice.startKg),
            ),
      line: _lineFor(l10n, move, advice),
    );
  }

  static String? _loadAdviceLine(BuildContext context) {
    final move = WorkoutSessionState.instance.currentMove;
    return move == null
        ? null
        : _lineFor(AppL10n.of(context), move, _adviceFor(move));
  }

  /// [set] with the weight R08 opens on, when her history has one.
  static PrescribedSet _setWithAdvice(BuildContext context, PrescribedSet set) {
    final advice = _adviceFor(WorkoutSessionState.instance.currentMove);
    if (advice == null || set.weightKg != null) return set;
    return PrescribedSet(
      exerciseId: set.exerciseId,
      order: set.order,
      weightKg: advice.startKg,
      reps: set.reps,
      holdSeconds: set.holdSeconds,
    );
  }

  static List<double> _weightOptionsFor(BuildContext context) {
    final move = WorkoutSessionState.instance.currentMove;
    final set = _setWithAdvice(
      context,
      WorkoutSessionState.instance.currentSet ??
          sampleWorkoutDay(AppL10n.of(context)).moves.first.sets.first,
    );
    final advice = _adviceFor(move);
    if (advice != null) return advice.optionsKg;
    if (set.weightKg == null && (move?.needsEquipment ?? false)) {
      return kStarterWeightsKg;
    }
    return weightOptionsAround(set);
  }

  /// The programme O05 chose for her and the content behind it, or null while
  /// none is loaded for her answers.
  static ({StartingProgram program, AuthoredProgramme content})?
  get herProgramme {
    final program = selectStartingProgram(intakeRepository.read());
    if (program == null) return null;
    final content = StartingProgrammes.programme(program.programId);
    return content == null ? null : (program: program, content: content);
  }

  /// The session of her programme for today, or the one she opened on R02, cut
  /// to her minutes. Null with no programme, which is the bundled session.
  static WorkoutDay? programmeWorkoutDay(BuildContext context) {
    final her = herProgramme;
    if (her == null) return null;
    final intake = intakeRepository.read();
    final sessions = programmeSessionsFor(her.content, intake.lifeStage);
    if (sessions.isEmpty) return null;
    final slot =
        WorkoutLibraryState.instance.openedSlot ??
        sessionsDoneThisWeek(trainRepository.sessions);
    return workoutDayFrom(
      AppL10n.of(context),
      Localizations.localeOf(context).languageCode,
      her.content,
      scaleSession(sessions[slot % sessions.length], intake.minutes),
      now: AppClock.now(),
    );
  }

  /// The library session she chose on R11, else today's session of her
  /// programme, as today's [WorkoutDay], or null for the bundled one. Null too
  /// when a library pick no longer suits her life stage.
  static WorkoutDay? chosenWorkoutDay(BuildContext context) {
    final entry = WorkoutLibraryState.instance.chosenFor(
      intakeRepository.read().lifeStage,
    );
    if (entry == null) return programmeWorkoutDay(context);
    return workoutDayFrom(
      AppL10n.of(context),
      Localizations.localeOf(context).languageCode,
      entry.programme,
      entry.session,
      now: AppClock.now(),
    );
  }

  /// Z15 and Z16's server. Tests set [consoleSourceOverride].
  static ConsoleSource? consoleSourceOverride;
  static ConsoleSource get consoleSource =>
      consoleSourceOverride ?? AdminBackends.console();

  /// Z17 and Z18's store. Tests set [eventAdminStoreOverride].
  static EventAdminStore? eventAdminStoreOverride;
  static EventAdminStore get eventAdminStore =>
      eventAdminStoreOverride ?? AdminBackends.events();

  /// The event Z18 opens on. Null adds a new one.
  static HubEvent? adminEditingEvent;

  /// Moves on every event saved, so Z17 reads its list again.
  static int adminEventsRevision = 0;

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
    currentWeek: progressStore.weeks[WeekKey.of(AppClock.now()).id],
    // The same catalogue P02 renders, so P01's tile and P02's list cannot
    // disagree about how many milestones exist — the failure that put "Level 7"
    // on Home while Progress showed no tier at all.
    milestoneCount: authoredMilestones.count,
  );

  /// Her week plan. It starts empty: E07 offers to fill it from Rahma's
  /// recipes and E08 is made from what she plans, so no fixed sample week is
  /// ever shown as hers.
  static final InMemoryMealRepository mealRepository = InMemoryMealRepository();

  /// The day `E05` was opened to choose a dinner for, carried as the route's
  /// argument so the ordinary library never inherits it.
  static eat_plan.PlanDay? _pickDayOf(BuildContext context) {
    final day = ModalRoute.of(context)?.settings.arguments;
    return day is eat_plan.PlanDay ? day : null;
  }

  /// One of Rahma's own recipes by id, or null: an assembly is not hers, and
  /// an id the book does not hold is not a recipe.
  static Recipe? rahmaRecipe(String recipeId) {
    final recipe = (EatAppState.instance..ensureRecipeBook()).recipeBook.byId(
      recipeId,
    );
    return recipe == null || recipe.source == RecipeSource.assembly
        ? null
        : recipe;
  }

  /// All of Rahma's recipes the allergy guard lets through, in her book's
  /// order. Nothing until she has answered the allergy question.
  static List<Recipe> rahmaRecipes() {
    if (!dietaryRepository.read().asked) return const <Recipe>[];
    final book = (EatAppState.instance..ensureRecipeBook()).recipeBook;
    return AllergyGuard(eatConstraints).screenRecipes([
      for (final section in book.sections) ...book.inSection(section.sectionId),
    ]);
  }

  /// Puts [recipeId] on the first empty weekday of this week's dinners and
  /// opens E07. A full week is left as she made it.
  static Future<void> _addToWeek(BuildContext context, String? recipeId) async {
    if (recipeId == null) return;
    final weekId = WeekKey.of(AppClock.now()).id;
    final plan = await mealRepository.mealPlan(weekId);
    final planned = plan?.dinners ?? const <eat_plan.PlanDay, String>{};
    if (!planned.containsValue(recipeId)) {
      final free = [
        eat_plan.PlanDay.mon,
        eat_plan.PlanDay.tue,
        eat_plan.PlanDay.wed,
        eat_plan.PlanDay.thu,
        eat_plan.PlanDay.fri,
      ].where((d) => !planned.containsKey(d));
      if (free.isEmpty) {
        if (context.mounted) {
          showHonestNotice(
            context,
            AppL10n.of(context).yourWeekIsFullSwapADinner,
          );
        }
      } else {
        await mealRepository.swapDinner(
          weekId: weekId,
          day: free.first,
          recipeId: recipeId,
        );
        AppChanges.bump();
      }
    }
    if (context.mounted) goTo(context, 'E07');
  }

  /// What "Fill my week" on `E07` may use: Rahma's dinners, then her lunches,
  /// that the allergy guard lets through. Nothing until she has answered the
  /// allergy question, because her book is not shown before that either.
  static List<String> rahmaDinners() {
    if (!dietaryRepository.read().asked) return const <String>[];
    final book = (EatAppState.instance..ensureRecipeBook()).recipeBook;
    final guard = AllergyGuard(eatConstraints);
    return <String>[
      for (final section in const ['comfy_dinner', 'lunchy_junky_yum'])
        for (final recipe in guard.screenRecipes(book.inSection(section)))
          recipe.recipeId,
    ];
  }

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

  /// The tour, as `C04` and `C05` build it. See the note on `C04` above.
  ///
  /// Her week, then her number: `O03`, or `O05` when her week is already
  /// built. A woman already signed up and waiting on her check is taken back
  /// to it instead, past Rahma's recipe if she is on it.
  ///
  /// When the tour is the first screen (a link opened it), there is nothing
  /// under it to go back to, so the exits open the front door in its place
  /// rather than doing nothing.
  static Widget _lookAround(
    BuildContext context, {
    required VoidCallback toSignUp,
    required VoidCallback toSignIn,
    bool openJoinPrompt = false,
  }) {
    final waiting = signedInUid != null || awaitingReviewer;
    void leave() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacementNamed(frontDoor);
      }
    }

    return LookAroundView(
      waiting: waiting,
      setupDone: intakeRepository.setupDone,
      openJoinPrompt: openJoinPrompt,
      onJoin: () {
        if (waiting) {
          // Past Rahma's recipe first, if the tour pushed it.
          final tour = ModalRoute.of(context);
          if (tour != null) {
            Navigator.of(context).popUntil((route) => route == tour);
          }
          leave();
          return;
        }
        OnboardingState.instance
          ..beforeSignup = true
          ..whileWaiting = false;
        unawaited(
          analytics.track(AnalyticsEvent.signUpStarted, {
            AnalyticsProp.source: const AnalyticsValue.token('tour'),
          }),
        );
        toSignUp();
      },
      onSignIn: toSignIn,
      // Skip, in the tour's bar: straight to sign-in. Not for a woman already
      // waiting on her check.
      onSkip: waiting ? null : toSignIn,
      onLeave: () {
        unawaited(
          analytics.track(AnalyticsEvent.tourLeft, {
            AnalyticsProp.tourStop: _tourStopToken(_lastTourStop),
          }),
        );
        leave();
      },
      // The tour's funnel: which stops she reached and where she joined. Two
      // tokens each, nothing about her. A woman waiting on her check is not
      // joining, so her "Back to my check" is not counted as a join. The end
      // card is also Firebase's recommended `tutorial_complete`.
      onStopViewed: (stop) {
        _lastTourStop = stop;
        unawaited(
          analytics.track(AnalyticsEvent.tourStopViewed, {
            AnalyticsProp.tourStop: _tourStopToken(stop),
          }),
        );
        if (stop >= DemoStop.values.length) {
          unawaited(analytics.track(AnalyticsEvent.tourCompleted));
        }
      },
      onJoinFrom: (source, stop) {
        if (waiting) return;
        unawaited(
          analytics.track(AnalyticsEvent.tourJoinTapped, {
            AnalyticsProp.source: AnalyticsValue.token(source.name),
            AnalyticsProp.tourStop: _tourStopToken(stop),
          }),
        );
      },
    );
  }

  /// A tour stop as analytics carries it: `1` to `7`, or `end`.
  static AnalyticsValue _tourStopToken(int stop) => AnalyticsValue.token(
    stop < DemoStop.values.length ? '${stop + 1}' : 'end',
  );

  /// One of Rahma's cards, or null when the id she tapped is not one of hers.
  ///
  /// Null is also what an un-loaded book gives back, and the caller falls
  /// through to the food-backed page rather than to a spinner. The seed is on
  /// her handset; the only reason it would not be ready is the frame before the
  /// bundle read lands, and a flash of a loader for that is worse than a page.
  static Widget? _rahmaRecipe(BuildContext context) {
    final id = EatAppState.instance.openRecipeId;
    if (id == null) return null;
    final book = (EatAppState.instance..ensureRecipeBook()).recipeBook;
    final recipe = book.byId(id);
    if (recipe == null) return null;
    return RahmaRecipeView(
      recipe: recipe,
      onBack: () => Navigator.of(context).maybePop(),
      // Nothing in this build can share, and saying so is the same discipline
      // the rest of the Eat tab keeps rather than leaving a dead button.
      onShare: () => showHonestNotice(
        context,
        AppL10n.of(context).sharingIsNotConnectedInThisBuild,
      ),
    );
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
      // A blocked woman is gone from the room too, not only from the feed.
      // The graph is the one exclusion list, read here exactly as `feedPosts`
      // and `exploreModel` read it.
      if (post.groupId != null &&
          post.groupId == communityOpenGroupId &&
          !communityStore.graph.hides(post.authorUid))
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
  ///
  /// Inside the tour (`C04`) it navigates nowhere. The tour draws the real
  /// screens, and a control on one of them that its caller left unwired falls
  /// through `openScreen` to here; under [DemoScope] that opens the join sheet
  /// instead, so no screen behind the check can be pushed from inside the
  /// tour, whatever a screen forgets to wire. The tour's own exits are built
  /// above the scope and are not caught.
  static void goTo(BuildContext context, String screenId) {
    if (DemoScope.maybeOf(context) case final demo?) {
      demo.requestJoin(context);
      return;
    }
    final route = appDestinations[screenId];
    if (route == null) return;
    Navigator.of(context).pushNamed(route.name);
  }

  /// A tap on the bottom bar. A tab is a place, not a step: it opens on the
  /// screen at the bottom of the stack (Home, once she is in), with whatever
  /// was stacked between them closed. Pushed like [goTo], tabs piled up, so a
  /// session of tab taps kept every screen she had passed alive, and the back
  /// button walked her back through her own tab history. Tapping Home itself
  /// opens a fresh Home alone.
  ///
  /// The bar never offers the tab she is on, and no screen of a workout in
  /// progress has a bar, so nothing she is in the middle of is closed.
  static void goToTab(BuildContext context, String screenId) {
    if (DemoScope.maybeOf(context) case final demo?) {
      demo.requestJoin(context);
      return;
    }
    final route = appDestinations[screenId];
    if (route == null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      route.name,
      (below) => below.isFirst && below.settings.name != route.name,
    );
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
      // No screen id and no route name. An unknown deep link is the one route a
      // woman can arrive on by accident, and "No screen serves /train/r99" is a
      // developer's sentence with a developer's noun in it. Empty strings make
      // [NotBuiltYet] fall back to copy she can read, in her language.
      builder: (_) => const NotBuiltYet(screenId: '', title: ''),
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
    // `Localizations.of` rather than `AppL10n.of`, which is a null check.
    //
    // This is the one screen in the product that a bare `MaterialApp` can show:
    // a harness that points straight at `onUnknownRoute` has no delegates, and
    // a crash there would replace an honest panel with a red screen. Null falls
    // back to the English, which is the same sentence.
    final l10n = Localizations.of<AppL10n>(context, AppL10n);

    // "Routing is wired; this screen is waiting on its feature group
    // implementation" is a sentence about our build system, shown to a woman
    // who followed a link. What she needs to know is that the thing is not
    // here, and that is all this says now.
    final heading = title.isNotEmpty
        ? title
        : (l10n?.weCannotFindThatPage ?? 'We cannot find that page.');
    final body =
        l10n?.notBuiltYetThisPartOfThe ??
        'Not built yet. This part of the app is not in this release.';

    return Scaffold(
      backgroundColor: AppColors.surfaceLow,
      appBar: AppBar(
        title: screenId.isEmpty ? null : Text(screenId, style: AppText.titleM),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(heading, style: AppText.titleL, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                body,
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
///
/// A member can land here: the server can switch a part off while a link to
/// it is on her screen. So it speaks to her, in her language, with no screen
/// id and no word about flags, and the bar's back arrow takes her out. [title]
/// is the route's English title, kept for the tests and never drawn.
class FeatureOff extends StatelessWidget {
  const FeatureOff({super.key, required this.screenId, required this.title});

  final String screenId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceLow,
      appBar: AppBar(backgroundColor: AppColors.surfaceLow),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.notOpenRightNow,
                style: AppText.titleL,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.thisPartOfOwnHubIsNot,
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
