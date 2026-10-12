/// The switch every screen answers to.
///
/// Every screen in `appRoutes` is listed here or in
/// `AppRouter.ungatedScreens`, with no default, so a new screen cannot ship
/// without somebody choosing its switch. A screen is reachable when its own
/// switch is on **and** its flow's switch is on (`AppRouter.featureForFlow`),
/// which is what lets `K26` belong to the planner and to the assistant at
/// once.
///
/// A new part of a feature gets a new [Feature] (see `feature_flags.dart`) and
/// its screens move here from their parent's line. Held by
/// `test/domain/flags/every_feature_has_a_switch_test.dart`.
library;

import '../domain/flags/feature_flags.dart';

const Map<String, Feature> kScreenFeatures = {
  // Sign-up. `C02` is ungated (the language is a setting), `C16` is the
  // community's pledge and opens only with the community.
  'C01': Feature.signUp,
  'C03': Feature.appTour,
  'C04': Feature.appTour,
  'C05': Feature.signUp,
  'C06': Feature.signUp,
  'C07': Feature.signUp,
  'C08': Feature.signUp,
  'C09': Feature.signUp,
  'C09b': Feature.signUp,
  'C10': Feature.signUp,
  'C10b': Feature.signUp,
  'C11': Feature.signUp,
  'C12': Feature.signUp,
  'C13': Feature.signUp,
  'C14': Feature.signUp,
  'C15': Feature.signUp,
  'C16': Feature.community,

  // Home.
  'T01': Feature.today,
  'T02': Feature.recordFromMemory,
  'T03': Feature.lockScreenNudge,
  'T04': Feature.quietWeek,
  'T05': Feature.tiers,
  'T06': Feature.today,
  'T07': Feature.firstWeek,
  'T08': Feature.firstWeek,
  'T09': Feature.events,

  // Train.
  'R01': Feature.train,
  'R02': Feature.train,
  'R03': Feature.train,
  'R04': Feature.exerciseVideo,
  'R05': Feature.exerciseSwap,
  'R06': Feature.followAlong,
  'R07': Feature.train,
  'R08': Feature.train,
  'R09': Feature.train,
  'R10': Feature.train,
  'R11': Feature.workoutLibrary,
  'R12': Feature.recordFromMemory,
  'R13': Feature.train,

  // Eat. `E10` stays on Eat itself: what she cannot eat is a safety
  // setting, and it is never switched off apart from the meals it guards.
  'E01': Feature.eat,
  'E02': Feature.eat,
  'E03': Feature.voiceLogging,
  'E04': Feature.eat,
  'E05': Feature.recipes,
  'E06': Feature.recipes,
  'E07': Feature.weekPlan,
  'E08': Feature.groceryList,
  'E09': Feature.eat,
  'E10': Feature.eat,
  'E11': Feature.recipes,

  // Progress.
  'P01': Feature.progress,
  'P02': Feature.milestones,
  'P03': Feature.personalBests,
  'P04': Feature.bodyPrivately,
  'P05': Feature.shareCard,

  // My cycle. Settings (`Y12`) and logging a period (`Y09`) stay on the
  // cycle itself, so switching a part off never takes her settings away.
  'Y01': Feature.cycle,
  'Y02': Feature.cycle,
  'Y03': Feature.cycle,
  'Y04': Feature.cycle,
  'Y05': Feature.cycle,
  'Y06': Feature.cycle,
  'Y07': Feature.cycleMeals,
  'Y08': Feature.cycleCalendar,
  'Y09': Feature.cycle,
  'Y10': Feature.cyclePatterns,
  'Y11': Feature.cycle,
  'Y12': Feature.cycle,
  'Y13': Feature.cycle,
  'Y14': Feature.cycle,

  // Life as a coached client.
  'G01': Feature.coachedLife,
  'G02': Feature.coachedLife,
  'G03': Feature.coachedLife,
  'G04': Feature.coachedLife,
  'G05': Feature.coachedLife,
  'G06': Feature.coachedLife,
  'G07': Feature.coachedLife,
  'G08': Feature.coachedLife,
  'G09': Feature.coachedLife,
  'G10': Feature.coachedLife,
  'G11': Feature.coachedLife,
  'G12': Feature.coachedLife,
  'G13': Feature.coachedLife,
  'G14': Feature.coachedLife,
  'G15': Feature.coachedLife,
  'G16': Feature.coachedLife,
  'G17': Feature.coachedLife,

  // Community.
  'M01': Feature.community,
  'M02': Feature.community,
  'M03': Feature.community,
  'M04': Feature.communityGroups,
  'M05': Feature.communityGroups,
  'M06': Feature.communityGroups,
  'M07': Feature.community,
  'M08': Feature.community,
  'M09': Feature.communityVideo,
  'M10': Feature.community,
  'M11': Feature.community,
  'M12': Feature.community,
  'M13': Feature.communityStories,
  'M14': Feature.community,
  'M15': Feature.community,
  'M16': Feature.communityVideo,
  'M17': Feature.community,

  // Finding a coach. Paying is its own switch.
  'H01': Feature.marketplace,
  'H02': Feature.marketplace,
  'H03': Feature.marketplace,
  'H04': Feature.payments,
  'H05': Feature.marketplace,
  'H06': Feature.marketplace,

  // The assistant.
  'X01': Feature.assistant,
  'X02': Feature.assistant,
  'X03': Feature.assistant,

  // The coach's own setup and desk. Earnings need money to move.
  'K01': Feature.coachApp,
  'K02': Feature.coachApp,
  'K03': Feature.coachApp,
  'K04': Feature.coachApp,
  'K05': Feature.coachApp,
  'K06': Feature.coachApp,
  'K08': Feature.coachApp,
  'K10': Feature.coachApp,
  // Results and what clients say live on her page, so they open with it.
  'K11': Feature.coachResults,
  'K12': Feature.coachReviews,
  'K13': Feature.coachApp,
  'K07': Feature.coachApp,
  'K09': Feature.coachApp,
  'K16': Feature.coachApp,
  'K17': Feature.payments,
  'K18': Feature.coachApp,
  'K24': Feature.coachApp,
  'K25': Feature.coachApp,

  // Her page.
  'B01': Feature.coachPortfolio,
  'B02': Feature.coachPortfolio,
  'B03': Feature.coachPortfolio,
  'B04': Feature.coachPortfolio,
  'B05': Feature.coachPortfolio,
  'B06': Feature.coachPortfolio,
  'B07': Feature.coachPortfolio,
  'B08': Feature.coachResults,
  'B09': Feature.coachAds,
  'B10': Feature.coachPortfolio,
  'B11': Feature.coachPortfolio,
  'B12': Feature.coachPortfolio,
  'B13': Feature.coachPortfolio,
  'B14': Feature.coachPortfolio,

  // Planning. The two drafts are written by the assistant, so they open only
  // when the planner and the assistant are both on.
  'W01': Feature.coachPlanning,
  'W02': Feature.coachPlanning,
  'W03': Feature.coachPlanning,
  'W04': Feature.coachPlanning,
  'W05': Feature.coachPlanning,
  'W06': Feature.coachPlanning,
  'W07': Feature.coachPlanning,
  'W08': Feature.coachPlanning,
  'W09': Feature.coachPlanning,
  'W10': Feature.coachPlanning,
  'W11': Feature.coachPlanning,
  'K19': Feature.coachPlanning,
  'K20': Feature.coachPlanning,
  'K21': Feature.coachPlanning,
  'K22': Feature.coachPlanning,
  'K23': Feature.coachPlanning,
  'K26': Feature.assistant,
  'K27': Feature.assistant,

  // The owner's console. Compiled out of store builds as well.
  'Z01': Feature.adminConsole,
  'Z02': Feature.adminConsole,
  'Z03': Feature.adminConsole,
  'Z04': Feature.adminConsole,
  'Z05': Feature.adminConsole,
  'Z06': Feature.adminConsole,
  'Z07': Feature.adminConsole,
  'Z08': Feature.adminConsole,
  'Z09': Feature.adminConsole,
  'Z10': Feature.adminConsole,
  'Z11': Feature.adminConsole,
  'Z12': Feature.adminConsole,
  'Z13': Feature.adminConsole,
  'Z14': Feature.adminConsole,
  'Z15': Feature.adminConsole,
  'Z16': Feature.adminConsole,
  'Z17': Feature.adminConsole,
  'Z18': Feature.adminConsole,
};
