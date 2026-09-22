/// What B01 draws — and the branch that makes B14 a state rather than a route.
///
/// `ARCHITECTURE.md` §1: *"A view model may not restate a rule, and a widget
/// may never contain one."* So nothing here decides anything. The lifecycle
/// comes from [PortfolioLifecycleRules], the change count from
/// [PortfolioDiffer], the insights availability from the flag. This file only
/// arranges those answers, which is why the whole of B01's behaviour is
/// testable without pumping a frame.
///
/// ## B14 is `isDayOne`
///
/// HANDOFF rule 16, and `P0-PORT-01`: *"B14 renders inside the B01 route …
/// No `/coachbrand/b14` destination is registered and nothing navigates to
/// one."* [PortfolioHomeState.isDayOne] is that branch. It is a getter on a
/// state object, not a route, not a navigation target, and not a separate
/// widget the router could reach.
///
/// It is true when there is no draft **or** the draft holds no blocks — a
/// document that exists and is empty is the same situation for the coach as no
/// document at all, and she should meet the same screen.
library;

import 'package:meta/meta.dart';

import '../domain/portfolio.dart';
import '../domain/portfolio_insights.dart';
import '../domain/portfolio_publisher.dart';

/// Everything B01 renders.
@immutable
class PortfolioHomeState {
  const PortfolioHomeState({
    required this.lifecycle,
    required this.unpublishedChanges,
    this.draft,
    this.live,
    this.insights = PortfolioInsights.deferred,
    this.queuedPublish,
  });

  /// Builds the screen from her two documents.
  ///
  /// Pure: the same inputs always produce the same view. There is no clock and
  /// no day list among the parameters, so a consecutive-day tally is not
  /// computable at the one place B01's content is decided.
  factory PortfolioHomeState.from({
    Portfolio? draft,
    Portfolio? live,
    PublishIntent? queuedPublish,
    PortfolioInsights insights = PortfolioInsights.deferred,
  }) {
    final queued = queuedPublish != null && !queuedPublish.cancelled;

    final lifecycle = PortfolioLifecycleRules.resolve(
      draft: draft,
      live: live,
      publishQueued: queued,
    );

    // Derived, never stored — and only computed when there is something to
    // compare, so "3 unpublished changes" is never a guess.
    final changes = (draft != null && live != null)
        ? PortfolioDiffer.between(live: live, draft: draft).count
        : 0;

    return PortfolioHomeState(
      lifecycle: lifecycle,
      unpublishedChanges: changes,
      draft: draft,
      live: live,
      insights: insights,
      queuedPublish: queued ? queuedPublish : null,
    );
  }

  final PortfolioLifecycle lifecycle;
  final Portfolio? draft;
  final Portfolio? live;
  final PortfolioInsights insights;
  final PublishIntent? queuedPublish;

  /// How many changes the draft holds over what is live. Zero unless
  /// [PortfolioLifecycle.liveDirty].
  final int unpublishedChanges;

  /// **The B14 branch.** Not a route; a getter.
  bool get isDayOne => lifecycle == PortfolioLifecycle.empty;

  /// Sections on the draft — the "6 sections" pill, denormalised so B01 never
  /// parses the array.
  int get blockCount => draft?.blockCount ?? live?.blockCount ?? 0;

  /// The version a client currently sees, or null before she has published.
  int? get liveVersion => live?.version;

  /// The version the next publish would produce.
  int get nextVersion => (live?.version ?? 0) + 1;

  DateTime? get publishedAt => live?.publishedAt;

  /// True while a publish is waiting for signal. B01 shows a banner, and its
  /// copy does not claim the page is live.
  bool get isPublishQueued => lifecycle == PortfolioLifecycle.queued;

  /// True when a client opening her profile would find a page.
  bool get isVisibleToClients =>
      lifecycle == PortfolioLifecycle.live ||
      lifecycle == PortfolioLifecycle.liveDirty;

  /// True when she took the page down herself.
  bool get isHidden => lifecycle == PortfolioLifecycle.hidden;

  /// True when moderation removed it. Editable, not publishable.
  bool get isSuspended => lifecycle == PortfolioLifecycle.suspended;

  /// Whether B01 may draw any figure at all.
  ///
  /// False today, and the screen states why rather than drawing zeros. See
  /// `portfolio_insights.dart`: there is no ratified storage and no beacon, so
  /// "0 views · 0 enquiries" would be a claim about her work made out of our
  /// own missing telemetry.
  bool get hasInsightFigures =>
      kPortfolioInsightsEnabled && insights.hasFigures;

  /// The three sections B14 offers. Named here so the screen holds no list of
  /// its own, and so the order is a decision in one place.
  ///
  /// HANDOFF rule 17: the empty state **is** the onboarding. It names three
  /// starters and states that nothing is decided for her — no tour, no
  /// overlay, no coach marks.
  static const List<DayOneStarter> dayOneStarters = <DayOneStarter>[
    DayOneStarter.cover,
    DayOneStarter.offer,
    DayOneStarter.method,
  ];

  @override
  String toString() =>
      'PortfolioHomeState(${lifecycle.name}, $blockCount blocks'
      '${unpublishedChanges > 0 ? ', $unpublishedChanges unpublished' : ''})';
}

/// One of B14's three starting points.
enum DayOneStarter {
  /// → B04.
  cover,

  /// → B06.
  offer,

  /// → B07.
  method;

  /// The screen that starts it.
  String get screenId => switch (this) {
    DayOneStarter.cover => 'B04',
    DayOneStarter.offer => 'B06',
    DayOneStarter.method => 'B07',
  };
}
