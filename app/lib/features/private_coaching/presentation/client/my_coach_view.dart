/// H05: My coach. The coach's photo and name, the package, the days left,
/// sessions used, a way to message her, the plans she shared, the next live
/// session with Confirm and Join, and Report and Block in the menu.
///
/// Once the coaching has ended the screen is read only: the plans can still be
/// read, and nothing can be sent or confirmed.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app_state/open_link.dart';
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_sheet.dart';
import '../coaching_when.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_plan.dart';
import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/session_link.dart';
import '../../domain/subscription.dart';
import '../coach/coach_text.dart';
import '../end_coaching_sheet.dart';
import '../member/coach_card.dart' show CoachPhoto;
import '../member/report_coach_sheet.dart';

/// Whether the coaching is over and the screen is read only.
bool coachingEnded(Subscription s) =>
    s.status == SubscriptionStatus.ended ||
    s.status == SubscriptionStatus.endedEarly;

/// A request the coach declined or let run out.
bool requestClosed(Subscription s) =>
    s.status == SubscriptionStatus.declined ||
    s.status == SubscriptionStatus.expired;

/// The sessions to show: the ones proposed or confirmed, soonest first.
List<LiveSession> upcomingSessions(Iterable<LiveSession> all) {
  final out = [
    for (final s in all)
      if (s.status == SessionStatus.proposed ||
          s.status == SessionStatus.confirmed)
        s,
  ];
  out.sort((a, b) {
    final x = a.startsAt;
    final y = b.startsAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
  return out;
}

class MyCoachView extends StatefulWidget {
  const MyCoachView({
    super.key,
    required this.repository,
    required this.subscription,
    this.plans = const <CoachPlan>[],
    this.hasUnread = false,
    this.now,
    this.onMessage,
    this.onOpenPlan,
    this.onBlock,
    this.onJoin,
    this.onFind,
    this.onBack,
  });

  final CoachingRepository repository;
  final Subscription subscription;

  /// Every plan her coaches shared; the ones from this coach are listed.
  final List<CoachPlan> plans;
  final bool hasUnread;
  final DateTime Function()? now;

  /// Opens the chat. Null hides the button.
  final VoidCallback? onMessage;
  final ValueChanged<CoachPlan>? onOpenPlan;

  /// Blocks the coach once she confirms. Null hides Block.
  final VoidCallback? onBlock;

  /// Opens a session link. Defaults to her browser.
  final ValueChanged<String>? onJoin;

  /// Opens the coach directory, from a request that did not go through.
  final VoidCallback? onFind;
  final VoidCallback? onBack;

  @override
  State<MyCoachView> createState() => _MyCoachViewState();
}

class _MyCoachViewState extends State<MyCoachView> {
  String _error = '';
  bool _busy = false;
  late Stream<CoachProfile?> _coach;
  late Stream<List<LiveSession>> _sessions;

  DateTime get _now => (widget.now ?? DateTime.now)();
  bool get _ended => coachingEnded(widget.subscription);
  bool get _active => widget.subscription.status == SubscriptionStatus.active;
  bool get _requested =>
      widget.subscription.status == SubscriptionStatus.requested;
  bool get _closed => requestClosed(widget.subscription);

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(MyCoachView old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository ||
        old.subscription.id != widget.subscription.id ||
        old.subscription.coachUid != widget.subscription.coachUid) {
      _open();
    }
  }

  void _open() {
    _coach = widget.repository.watchCoach(widget.subscription.coachUid);
    _sessions = widget.repository.watchSessions(widget.subscription.id);
  }

  void _back() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _run(Future<void> Function() call) async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await call();
      if (mounted) setState(() => _busy = false);
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coachFailureText(l10n, failure);
      });
    }
  }

  Future<void> _confirmBlock() async {
    final l10n = AppL10n.of(context);
    final yes = await showAppSheet<bool>(
      context: context,
      children: [
        Text(l10n.blockThisCoach, style: AppText.titleL),
        Text(l10n.sheWillNotBeAbleToMessage, style: AppText.bodyM),
        AppButton(
          l10n.block,
          key: const ValueKey('block-yes'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        AppButton(
          l10n.cancel,
          key: const ValueKey('block-no'),
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: 12),
      ],
    );
    if (yes == true && mounted) widget.onBlock?.call();
  }

  Future<void> _confirmEnd(String name) async {
    final l10n = AppL10n.of(context);
    final yes = await confirmEndCoaching(
      context,
      body: l10n.theChatBecomesReadOnlyYourPlans(name),
    );
    if (!yes || !mounted) return;
    await _run(() => widget.repository.endMyCoaching(widget.subscription.id));
  }

  void _join(String link) {
    if (!sessionLinkAllowed(link)) return;
    final join = widget.onJoin;
    if (join != null) {
      join(link);
    } else {
      unawaited(openExternalLink(context, link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sub = widget.subscription;
    return StreamBuilder<CoachProfile?>(
      stream: _coach,
      builder: (context, coachSnap) {
        final coach = coachSnap.data;
        final name = coach?.displayName.isNotEmpty == true
            ? coach!.displayName
            : l10n.coach;
        return StreamBuilder<List<LiveSession>>(
          stream: _sessions,
          builder: (context, sessionSnap) {
            final sessions = upcomingSessions(
              sessionSnap.data ?? const <LiveSession>[],
            );
            return AppScaffold(
              appBar: AppTopBar(
                title: l10n.myCoach,
                onBack: _back,
                actions: [
                  PopupMenuButton<String>(
                    key: const ValueKey('coach-menu'),
                    tooltip: l10n.myCoach,
                    constraints: const BoxConstraints(minWidth: 48),
                    onSelected: (v) {
                      if (v == 'report') {
                        unawaited(
                          showReportCoachSheet(
                            context: context,
                            repository: widget.repository,
                            coachUid: sub.coachUid,
                          ),
                        );
                      } else if (v == 'block') {
                        unawaited(_confirmBlock());
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'report',
                        height: 48,
                        child: Text(l10n.report),
                      ),
                      if (widget.onBlock != null)
                        PopupMenuItem<String>(
                          value: 'block',
                          height: 48,
                          child: Text(l10n.block),
                        ),
                    ],
                  ),
                ],
              ),
              children: [
                _header(l10n, coach, name),
                if (_ended)
                  AppCard(
                    variant: AppCardVariant.filled,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.coachingEnded,
                          key: const ValueKey('coaching-ended'),
                          style: AppText.titleM,
                        ),
                      ),
                      Text(
                        l10n.yourCoachingWithCoachHasEndedYour(name),
                        style: AppText.bodyM,
                      ),
                    ],
                  )
                else if (_requested)
                  ..._waiting(l10n, name)
                else if (_closed)
                  ..._closedNote(l10n, name)
                else if (_active) ...[
                  if (widget.onMessage != null)
                    AppButton(
                      l10n.message,
                      key: const ValueKey('coach-message'),
                      icon: widget.hasUnread
                          ? Icons.mark_chat_unread_outlined
                          : Icons.chat_bubble_outline,
                      onPressed: widget.onMessage,
                    ),
                  if (widget.hasUnread)
                    Text(
                      l10n.newMessagesFromYourCoach,
                      key: const ValueKey('coach-unread'),
                      style: AppText.bodyM.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  if (sessions.isNotEmpty) ...[
                    Semantics(
                      header: true,
                      child: Text(l10n.upcomingSession, style: AppText.titleL),
                    ),
                    for (final s in sessions) _sessionCard(l10n, s),
                  ],
                  AppButton(
                    l10n.endCoaching,
                    key: const ValueKey('end-coaching'),
                    variant: AppButtonVariant.text,
                    height: 48,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_confirmEnd(name)),
                  ),
                ],
                if (_error.isNotEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error,
                      key: const ValueKey('coach-error'),
                      style: AppText.bodyM.copyWith(color: AppColors.error),
                    ),
                  ),
                if (_active || _ended) ...[
                  Semantics(
                    header: true,
                    child: Text(l10n.plansFromYourCoach, style: AppText.titleL),
                  ),
                  ..._plans(l10n),
                ],
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _waiting(AppL10n l10n, String name) => [
    Text(
      l10n.waitingForCoachSAnswer(name),
      key: const ValueKey('coach-waiting'),
      style: AppText.titleM,
    ),
    AppButton(
      l10n.cancelRequest,
      key: const ValueKey('cancel-request'),
      variant: AppButtonVariant.outlined,
      height: 48,
      onPressed: _busy
          ? null
          : () => unawaited(
              _run(
                () => widget.repository.cancelCoachingRequest(
                  widget.subscription.id,
                ),
              ),
            ),
    ),
  ];

  List<Widget> _closedNote(AppL10n l10n, String name) => [
    Text(
      widget.subscription.status == SubscriptionStatus.declined
          ? l10n.coachCouldNotTakeYouThisTime(name)
          : l10n.noAnswerInTime,
      key: const ValueKey('coach-closed'),
      style: AppText.bodyM,
    ),
    if (widget.onFind != null)
      AppButton(
        l10n.findAnotherCoach,
        key: const ValueKey('find-another-coach'),
        onPressed: widget.onFind,
      ),
  ];

  Widget _header(AppL10n l10n, CoachProfile? coach, String name) {
    final sub = widget.subscription;
    final days = sub.daysLeft(_now);
    return AppCard(
      variant: AppCardVariant.tonal,
      children: [
        Row(
          children: [
            CoachPhoto(name: name, photoUrl: coach?.photoUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(name, style: AppText.titleL),
                  ),
                  if (sub.package.title.isNotEmpty)
                    Text(sub.package.title, style: AppText.bodyM),
                ],
              ),
            ),
          ],
        ),
        if (!_ended && days != null)
          Text(
            days <= 1 ? l10n.lastDay : l10n.daysLeftN(countLabel(days)),
            key: const ValueKey('coach-days-left'),
            style: AppText.titleS,
          ),
        if (sub.sessionsIncluded > 0)
          Text(
            l10n.sessionsUsedUsedOfIncluded(
              countLabel(sub.sessionsUsed),
              countLabel(sub.sessionsIncluded),
            ),
            key: const ValueKey('coach-sessions-used'),
            style: AppText.bodyM,
          ),
      ],
    );
  }

  Widget _sessionCard(AppL10n l10n, LiveSession s) {
    final me = widget.repository.uid ?? '';
    final at = s.startsAt;
    final confirmed = s.status == SessionStatus.confirmed;
    final mine = s.doneByMe(me);
    final canDone = s.canMarkDone(_now) && !mine;
    return AppCard(
      key: ValueKey('session-${s.id}'),
      variant: AppCardVariant.outlined,
      borderRadius: AppRadius.md,
      children: [
        if (at != null)
          Text(
            '${coachWhen(l10n, at, cairo: true)} · ${l10n.cairoTime}',
            style: AppText.titleS,
            textDirection: TextDirection.ltr,
          ),
        Text(
          l10n.minutesMinSession(countLabel(s.minutes)),
          style: AppText.bodyM,
        ),
        if (!_ended && !confirmed)
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.confirm,
                  key: ValueKey('session-confirm-${s.id}'),
                  height: 48,
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _run(
                            () => widget.repository.respondLiveSession(
                              subId: widget.subscription.id,
                              sessionId: s.id,
                              confirm: true,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  l10n.decline,
                  key: ValueKey('session-decline-${s.id}'),
                  height: 48,
                  variant: AppButtonVariant.outlined,
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _run(
                            () => widget.repository.respondLiveSession(
                              subId: widget.subscription.id,
                              sessionId: s.id,
                              confirm: false,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        if (!_ended && confirmed && s.link.isNotEmpty)
          AppButton(
            l10n.join,
            key: ValueKey('session-join-${s.id}'),
            height: 48,
            variant: AppButtonVariant.tonal,
            icon: Icons.videocam_outlined,
            onPressed: () => _join(s.link),
          ),
        if (!_ended && canDone)
          AppButton(
            l10n.markDone,
            key: ValueKey('session-done-${s.id}'),
            height: 48,
            variant: AppButtonVariant.outlined,
            onPressed: _busy
                ? null
                : () => unawaited(
                    _run(
                      () => widget.repository.markSessionDone(
                        subId: widget.subscription.id,
                        sessionId: s.id,
                      ),
                    ),
                  ),
          ),
        if (mine)
          Text(
            l10n.waitingForTheOtherSideToMark,
            key: ValueKey('session-waiting-${s.id}'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }

  List<Widget> _plans(AppL10n l10n) {
    final mine = [
      for (final p in widget.plans)
        if (p.coachUid.isEmpty || p.coachUid == widget.subscription.coachUid) p,
    ];
    if (mine.isEmpty) {
      return [
        Text(
          l10n.yourCoachHasNotSharedAPlan,
          key: const ValueKey('coach-no-plans'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ];
    }
    return [
      for (final p in mine)
        AppListItem(
          key: ValueKey('coach-plan-${p.id}'),
          title: p.name.isEmpty ? l10n.fromYourCoach : p.name,
          subtitle:
              '${p.kind == PlanKind.workout ? l10n.workoutPlan : l10n.mealPlan}'
              ' · ${l10n.versionN(countLabel(p.revision))}',
          trailing: const Icon(Icons.chevron_right, size: 24),
          onTap: widget.onOpenPlan == null ? null : () => widget.onOpenPlan!(p),
        ),
    ];
  }
}

/// The screen for a woman with no coaching running or finished.
class NoCoachView extends StatelessWidget {
  const NoCoachView({super.key, this.onFind, this.onBack});

  final VoidCallback? onFind;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      appBar: AppTopBar(title: l10n.myCoach, onBack: onBack),
      children: [
        Text(
          l10n.youHaveNoCoachRightNow,
          key: const ValueKey('no-coach'),
          style: AppText.titleM,
        ),
        if (onFind != null)
          AppButton(
            l10n.findACoach,
            key: const ValueKey('find-coach'),
            onPressed: onFind,
          ),
      ],
    );
  }
}
