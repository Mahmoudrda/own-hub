/// One client: how far into her package she is, what she told the coach, the
/// coach's own note about her (kept on this phone only), the plans shared and
/// the quick actions.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/coach_client_notes.dart';
import '../../../../app_state/app_changes.dart';
import '../../../../app_state/private_coaching_state.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_empty_state.dart';
import '../../../../ui/app_scaffold.dart';
import '../../domain/coach_plan.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/health_review.dart';
import '../../domain/subscription.dart';
import '../coach/coach_text.dart' show coachFailureText;
import '../end_coaching_sheet.dart';
import '../coaching_when.dart';
import 'desk_text.dart';
import 'desk_widgets.dart';

class ClientDetailView extends StatefulWidget {
  const ClientDetailView({
    super.key,
    required this.subId,
    this.state,
    this.now,
    this.notes,
    this.onBack,
    this.onOpenChat,
    this.onShareWorkout,
    this.onShareMeal,
    this.onScheduleSession,
  });

  /// The client's subscription id.
  final String subId;
  final PrivateCoachingState? state;

  /// The clock, for a test.
  final DateTime Function()? now;

  /// The coach's private notes; the phone's own by default.
  final CoachClientNotes? notes;
  final VoidCallback? onBack;

  /// Opens the chat by its relationship id.
  final ValueChanged<String>? onOpenChat;

  /// Each takes the subscription id.
  final ValueChanged<String>? onShareWorkout;
  final ValueChanged<String>? onShareMeal;
  final ValueChanged<String>? onScheduleSession;

  @override
  State<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends State<ClientDetailView> {
  late final TextEditingController _note;
  late final FocusNode _noteFocus;
  Stream<List<CoachPlan>>? _plans;
  Stream<List<LiveSession>>? _sessions;
  String _clientUid = '';
  String _error = '';
  bool _ending = false;
  bool _marking = false;
  final Set<String> _readSubIds = <String>{};

  bool _held(Subscription sub) =>
      sub.healthHeld && !_readSubIds.contains(sub.id);

  Future<void> _markRead(Subscription sub) async {
    setState(() => _marking = true);
    final ok = await HealthReviews.store.markRead(sub.id);
    if (!mounted) return;
    setState(() => _marking = false);
    if (ok) {
      _readSubIds.add(sub.id);
      setState(() {});
    }
  }

  PrivateCoachingState get _state =>
      widget.state ?? PrivateCoachingState.instance;

  CoachClientNotes get _notes => widget.notes ?? CoachClientNotes.instance;

  Subscription? _find() {
    for (final s in _state.coachSubscriptions) {
      if (s.id == widget.subId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final sub = _find();
    _clientUid = sub?.clientUid ?? '';
    _note = TextEditingController(text: _notes.forClient(_clientUid));
    _noteFocus = FocusNode()..addListener(_saveOnBlur);
    final repository = _state.repository;
    if (sub != null && repository != null) {
      _plans = repository.watchCoachPlansForClient(sub.clientUid);
      _sessions = repository.watchSessions(sub.id);
    }
  }

  void _saveOnBlur() {
    if (!_noteFocus.hasFocus) _saveNote(quiet: true);
  }

  void _saveNote({bool quiet = false}) {
    if (_clientUid.isEmpty) return;
    _notes.setFor(_clientUid, _note.text);
    if (quiet || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppL10n.of(context).noteSaved)));
  }

  Future<void> _end(Subscription sub) async {
    final l10n = AppL10n.of(context);
    final repository = _state.repository;
    if (repository == null) return;
    final yes = await confirmEndCoaching(
      context,
      body: l10n.theChatBecomesReadOnlyHerPlans,
    );
    if (!yes || !mounted) return;
    setState(() {
      _ending = true;
      _error = '';
    });
    try {
      await repository.endMyCoaching(sub.id);
      if (!mounted) return;
      setState(() => _ending = false);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.coachingEnded)));
      widget.onBack?.call();
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _ending = false;
        _error = coachFailureText(l10n, failure);
      });
    }
  }

  @override
  void dispose() {
    _noteFocus.removeListener(_saveOnBlur);
    if (_clientUid.isNotEmpty) _notes.setFor(_clientUid, _note.text);
    _noteFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return RedrawOnChange(
      builder: (context) {
        final sub = _find();
        final appBar = AppTopBar(
          title: l10n.clientDetails,
          onBack: widget.onBack,
        );
        if (sub == null) {
          return AppScaffold(
            appBar: appBar,
            children: [
              AppEmptyState(
                icon: Icons.person_off_outlined,
                title: l10n.clientDetails,
                body: l10n.weCouldNotFindThisClient,
              ),
            ],
          );
        }
        final now = (widget.now ?? DateTime.now)();
        return AppScaffold(
          appBar: appBar,
          children: [
            _header(l10n, sub, now),
            if (_held(sub))
              AppCard(
                gap: 8,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.readHerHealthAnswersFirst,
                      style: AppText.titleL,
                    ),
                  ),
                  Text(l10n.plansAreOnHoldUntilYouHave, style: AppText.bodyM),
                  AppButton(
                    l10n.iHaveReadThem,
                    variant: AppButtonVariant.outlined,
                    onPressed: _marking ? null : () => _markRead(sub),
                  ),
                ],
              ),
            _actions(l10n, sub),
            if (sub.intake != null) IntakeAnswersCard(sub.intake!),
            _noteCard(l10n),
            if (_sessions != null) _sessionsCard(l10n),
            if (_plans != null) _plansCard(l10n),
            _historyLine(l10n, sub),
          ],
        );
      },
    );
  }

  Widget _header(AppL10n l10n, Subscription sub, DateTime now) {
    final name = clientName(l10n, sub);
    final left = daysLeftText(l10n, sub.daysLeft(now));
    final facts = <(String, String)>[
      if (sub.package.title.isNotEmpty) (l10n.package, sub.package.title),
      if (sub.startsAt != null) (l10n.started, dateText(l10n, sub.startsAt)),
      if (left != null) (l10n.daysLeft, left),
      if (sub.sessionsIncluded > 0)
        (
          l10n.liveSessionsHeld,
          l10n.usedOfIncluded('${sub.sessionsUsed}', '${sub.sessionsIncluded}'),
        ),
    ];
    return AppCard(
      children: [
        Row(
          children: [
            DeskAvatar(name: name, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  name,
                  style: AppText.titleL.copyWith(color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
        for (final f in facts) _fact(f.$1, f.$2),
      ],
    );
  }

  Widget _fact(String label, String value) => DeskFact(label, value);

  Widget _actions(AppL10n l10n, Subscription sub) {
    VoidCallback? call(ValueChanged<String>? f) =>
        f == null ? null : () => f(sub.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          l10n.message,
          icon: Icons.chat_bubble_outline,
          onPressed: widget.onOpenChat == null
              ? null
              : () => widget.onOpenChat!(sub.relId),
        ),
        const SizedBox(height: 10),
        AppButton(
          l10n.shareAWorkout,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 16,
          onPressed: _held(sub) ? null : call(widget.onShareWorkout),
        ),
        const SizedBox(height: 10),
        AppButton(
          l10n.shareAMealPlan,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 16,
          onPressed: _held(sub) ? null : call(widget.onShareMeal),
        ),
        const SizedBox(height: 10),
        AppButton(
          l10n.scheduleALiveSession,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 16,
          onPressed: call(widget.onScheduleSession),
        ),
        if (sub.status == SubscriptionStatus.active) ...[
          const SizedBox(height: 28),
          OutlinedButton(
            key: const ValueKey('end-coaching'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _ending ? null : () => _end(sub),
            child: Text(
              l10n.endCoaching,
              style: AppText.label.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error,
                key: const ValueKey('end-coaching-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          ),
      ],
    );
  }

  Widget _title(String text) => Semantics(
    header: true,
    child: Text(text, style: AppText.titleM.copyWith(color: AppColors.ink)),
  );

  Widget _noteCard(AppL10n l10n) => AppCard(
    gap: 8,
    children: [
      _title(l10n.yourPrivateNote),
      Text(
        l10n.staysOnThisPhoneOnlySheNever,
        style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
      ),
      TextField(
        controller: _note,
        focusNode: _noteFocus,
        minLines: 3,
        maxLines: 8,
        maxLength: kCoachClientNoteMaxLength,
        textInputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
        style: AppText.body.copyWith(color: AppColors.ink),
        decoration: InputDecoration(
          hintText: l10n.writeWhatYouWantToRemember,
          filled: true,
          fillColor: AppColors.surfaceLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
        ),
      ),
      AppButton(
        l10n.saveNote,
        variant: AppButtonVariant.tonal,
        height: 48,
        fontSize: 16,
        onPressed: _clientUid.isEmpty ? null : _saveNote,
      ),
    ],
  );

  Widget _sessionsCard(AppL10n l10n) => StreamBuilder<List<LiveSession>>(
    stream: _sessions,
    builder: (context, snapshot) {
      final sessions = snapshot.data ?? const <LiveSession>[];
      if (sessions.isEmpty) return const SizedBox.shrink();
      return AppCard(
        gap: 8,
        children: [
          _title(l10n.liveSessions),
          for (final s in sessions)
            _fact(
              s.startsAt == null ? '' : coachWhen(l10n, s.startsAt!),
              switch (s.status) {
                SessionStatus.proposed => l10n.waitingForAnAnswer,
                SessionStatus.confirmed => l10n.confirmed,
                SessionStatus.done => l10n.done,
                _ => l10n.closed,
              },
            ),
        ],
      );
    },
  );

  Widget _plansCard(AppL10n l10n) => StreamBuilder<List<CoachPlan>>(
    stream: _plans,
    builder: (context, snapshot) {
      final plans = snapshot.data ?? const <CoachPlan>[];
      return AppCard(
        gap: 8,
        children: [
          _title(l10n.plansYouShared),
          if (plans.isEmpty)
            Text(
              l10n.nothingSharedYetShareAWorkoutOr,
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            )
          else
            for (final p in plans)
              _fact(
                p.name.isEmpty ? _kindText(l10n, p) : p.name,
                '${_kindText(l10n, p)} · ${dateText(l10n, p.publishedAt)}',
              ),
        ],
      );
    },
  );

  String _kindText(AppL10n l10n, CoachPlan p) =>
      p.kind == PlanKind.workout ? l10n.workoutPlan : l10n.mealPlan;

  Widget _historyLine(AppL10n l10n, Subscription sub) {
    final since = sub.acceptedAt ?? sub.startsAt ?? sub.createdAt;
    if (since == null) return const SizedBox.shrink();
    return Text(
      l10n.withYouSinceStartEndsEnd(
        dateText(l10n, since),
        dateText(l10n, sub.endsAt),
      ),
      style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
    );
  }
}
