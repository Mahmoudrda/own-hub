/// The coach's desk for today: what needs her first. New requests to answer,
/// clients to follow up, and chats with something unread.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/private_coaching_state.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_empty_state.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_sheet.dart';
import '../../../../ui/hand/skeleton.dart';
import '../../domain/check_in.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/subscription.dart';
import '../coach/coach_text.dart';
import 'desk_model.dart';
import 'desk_source.dart';
import 'desk_text.dart';
import 'desk_widgets.dart';

/// How many rows each section shows before "Show all".
const int kDeskSectionRows = 5;

class CoachDeskView extends StatefulWidget {
  const CoachDeskView({
    super.key,
    this.state,
    this.now,
    this.onBack,
    this.onOpenChat,
    this.onOpenClient,
    this.onOpenClients,
    this.onInviteClient,
  });

  /// Defaults to the app's own.
  final PrivateCoachingState? state;

  /// The clock, for a test.
  final DateTime Function()? now;
  final VoidCallback? onBack;

  /// Opens a client's chat by its relationship id.
  final ValueChanged<String>? onOpenChat;

  /// Opens a client's details by her subscription id.
  final ValueChanged<String>? onOpenClient;

  /// Opens the client list with a filter on.
  final ValueChanged<DeskFilter>? onOpenClients;

  /// "Invite a client" under the empty state.
  final VoidCallback? onInviteClient;

  @override
  State<CoachDeskView> createState() => _CoachDeskViewState();
}

class _CoachDeskViewState extends State<CoachDeskView> {
  final Set<String> _busy = <String>{};
  List<AttentionRow> _attention = const <AttentionRow>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadAttention());
  }

  Future<void> _loadAttention() async {
    final rows = await CheckIns.store.needsAttention();
    if (mounted) setState(() => _attention = rows);
  }

  PrivateCoachingState get _state =>
      widget.state ?? PrivateCoachingState.instance;

  DateTime get _now => (widget.now ?? DateTime.now)();

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _respond(
    Subscription request, {
    required bool accept,
    CoachDeclineReason? reason,
  }) async {
    final repository = _state.repository;
    if (repository == null || _busy.contains(request.id)) return;
    final l10n = AppL10n.of(context);
    setState(() => _busy.add(request.id));
    try {
      await repository.respondCoachingRequest(
        subId: request.id,
        accept: accept,
        declineReason: reason,
      );
      if (mounted) _say(accept ? l10n.requestAccepted : l10n.requestDeclined);
    } on CoachingFailure catch (failure) {
      if (mounted) _say(coachFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy.remove(request.id));
    }
  }

  Future<void> _decline(Subscription request) async {
    final l10n = AppL10n.of(context);
    final reason = await showAppSheet<CoachDeclineReason>(
      context: context,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.whyAreYouDeclining,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in CoachDeclineReason.values)
              AppChip(
                declineReasonLabel(l10n, r),
                onTap: () => Navigator.of(context).pop(r),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
    if (reason == null || !mounted) return;
    await _respond(request, accept: false, reason: reason);
  }

  /// Her answers in full, with the same two choices as the row.
  Future<void> _openRequest(Subscription request) async {
    final l10n = AppL10n.of(context);
    final intake = request.intake;
    final choice = await showAppSheet<bool>(
      context: context,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.nameAskedToJoin(clientName(l10n, request)),
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        if (request.package.title.isNotEmpty)
          Text(
            request.package.title,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
        if (intake != null) IntakeAnswersCard(intake),
        if (_state.agreementMissing)
          Text(
            l10n.youCannotAcceptNewRequestsYetAccept,
            key: const ValueKey('agreement-needed'),
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.accept,
                height: 48,
                fontSize: 16,
                onPressed: _state.agreementMissing
                    ? null
                    : () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                l10n.decline,
                height: 48,
                fontSize: 16,
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice) {
      await _respond(request, accept: true);
    } else {
      await _decline(request);
    }
  }

  /// Her name as the rest of the desk shows it ("Client #a1b2" when she gave
  /// none); the server's raw name only when the coaching is not loaded yet.
  String _attentionName(AppL10n l10n, DeskModel model, AttentionRow row) {
    for (final client in model.clients) {
      if (client.id == row.subId) return clientName(l10n, client.subscription);
    }
    return row.clientName;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return RedrawOnChange(
      builder: (context) {
        final state = _state;
        final now = _now;
        final model = state.deskModel(now);
        return AppScaffold(
          appBar: AppTopBar(title: l10n.coachDesk, onBack: widget.onBack),
          children: _body(context, l10n, state, model, now),
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    AppL10n l10n,
    PrivateCoachingState state,
    DeskModel model,
    DateTime now,
  ) {
    final waiting =
        state.loading && model.clients.isEmpty && model.requests.isEmpty;
    if (waiting) {
      return <Widget>[
        Semantics(
          label: l10n.coachDesk,
          child: const Column(
            children: [
              Skeleton(height: 72, radius: 12),
              SizedBox(height: 10),
              Skeleton(height: 72, radius: 12),
            ],
          ),
        ),
      ];
    }
    final failure = state.failure;
    if (failure != null && model.clients.isEmpty && model.requests.isEmpty) {
      return <Widget>[
        AppEmptyState(
          icon: Icons.cloud_off,
          title: l10n.coachDesk,
          body: coachFailureText(l10n, failure),
        ),
      ];
    }
    final myUid = state.repository?.uid;
    final nothingToDo =
        model.requests.isEmpty &&
        model.followUps.isEmpty &&
        model.unreadClients.isEmpty;
    return <Widget>[
      _counts(l10n, model),
      if (_attention.isNotEmpty) ...[
        _title(l10n.needsAttention),
        for (final row in _attention.take(kDeskSectionRows))
          AppListItem(
            variant: AppCardVariant.filled,
            title: _attentionName(l10n, model, row),
            subtitle: attentionSubtitle(l10n, row),
            onTap: () => widget.onOpenClient?.call(row.subId),
          ),
      ],
      if (model.requests.isNotEmpty) ...[
        _title(l10n.newRequests),
        for (final request in model.requests)
          _RequestCard(
            request: request,
            busy: _busy.contains(request.id),
            agreementMissing: _state.agreementMissing,
            onAccept: () => (request.intake?.anyFlag ?? false)
                ? _openRequest(request)
                : _respond(request, accept: true),
            onDecline: () => _decline(request),
            onOpen: () => _openRequest(request),
          ),
      ],
      if (model.followUps.isNotEmpty)
        ..._section(
          l10n,
          l10n.followUp_n22yh,
          model.followUps,
          DeskFilter.followUp,
          myUid,
          now,
          reasons: true,
        ),
      if (model.unreadClients.isNotEmpty)
        ..._section(
          l10n,
          l10n.unread,
          model.unreadClients,
          DeskFilter.unread,
          myUid,
          now,
        ),
      if (nothingToDo)
        model.clients.isEmpty
            ? AppEmptyState(
                icon: Icons.groups_outlined,
                title: l10n.noClientsYet,
                body: l10n.shareYourPortfolioLinkSoMembersCan,
              )
            : AppEmptyState(
                icon: Icons.check_circle_outline,
                title: l10n.youAreAllCaughtUp,
                body: l10n.nothingToAnswerOrFollowUpRight,
              ),
      if (nothingToDo && model.clients.isEmpty && widget.onInviteClient != null)
        AppButton(l10n.inviteAClient, onPressed: widget.onInviteClient),
      if (model.clients.isNotEmpty)
        AppButton(
          '${l10n.clients} · ${model.clients.length}',
          variant: AppButtonVariant.outlined,
          onPressed: () => widget.onOpenClients?.call(DeskFilter.all),
        ),
    ];
  }

  Widget _title(String text) => Semantics(
    header: true,
    child: Text(text, style: AppText.titleL.copyWith(color: AppColors.ink)),
  );

  Widget _counts(AppL10n l10n, DeskModel model) {
    void open(DeskFilter f) => widget.onOpenClients?.call(f);
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      ),
    );
    return Column(
      children: [
        pair(
          CountTile(
            count: model.requests.length,
            label: l10n.newRequests,
            highlight: model.requests.isNotEmpty,
          ),
          CountTile(
            count: model.unreadClients.length,
            label: l10n.unreadChats,
            highlight: model.unreadClients.isNotEmpty,
            onTap: () => open(DeskFilter.unread),
          ),
        ),
        const SizedBox(height: 10),
        pair(
          CountTile(
            count: model.followUps.length,
            label: l10n.toFollowUp,
            highlight: model.followUps.isNotEmpty,
            onTap: () => open(DeskFilter.followUp),
          ),
          CountTile(
            count: model.clients.length,
            label: l10n.activeClients,
            onTap: () => open(DeskFilter.all),
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    AppL10n l10n,
    String title,
    List<DeskClient> clients,
    DeskFilter filter,
    String? myUid,
    DateTime now, {
    bool reasons = false,
  }) => <Widget>[
    _title(title),
    for (final c in clients.take(kDeskSectionRows))
      reasons
          ? _FollowUpRow(
              client: c,
              onMessage: () => widget.onOpenChat?.call(c.relId),
              onOpen: () => widget.onOpenClient?.call(c.id),
            )
          : DeskClientRow(
              client: c,
              myUid: myUid,
              now: now,
              onOpenChat: () => widget.onOpenChat?.call(c.relId),
              onOpenClient: () => widget.onOpenClient?.call(c.id),
            ),
    if (clients.length > kDeskSectionRows) _more(l10n, clients.length, filter),
  ];

  Widget _more(AppL10n l10n, int count, DeskFilter? filter) => AppButton(
    l10n.showAllCount('$count'),
    variant: AppButtonVariant.text,
    onPressed: filter == null ? null : () => widget.onOpenClients?.call(filter),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.agreementMissing,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  final Subscription request;
  final bool busy;
  final bool agreementMissing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = clientName(l10n, request);
    final intake = request.intake;
    final summary = intake == null ? '' : intakeSummary(l10n, intake);
    final flagged = intake?.anyFlag ?? false;
    final package = request.package.title;
    return AppCard(
      gap: 8,
      children: [
        Semantics(
          container: true,
          button: true,
          label: <String>[
            l10n.nameAskedToJoin(name),
            if (package.isNotEmpty) package,
            if (summary.isNotEmpty) summary,
            if (flagged) l10n.healthAnswersToReadFirst,
          ].join('. '),
          excludeSemantics: true,
          child: InkWell(
            onTap: onOpen,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DeskAvatar(name: name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.nameAskedToJoin(name),
                        style: AppText.titleM.copyWith(color: AppColors.ink),
                      ),
                      if (package.isNotEmpty)
                        Text(
                          package,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (summary.isNotEmpty)
                        Text(
                          summary,
                          style: AppText.bodyM.copyWith(color: AppColors.ink),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (flagged)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.amberContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.healthAnswersToReadFirst,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (agreementMissing)
          Text(
            l10n.youCannotAcceptNewRequestsYetAccept,
            key: const ValueKey('agreement-needed'),
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.accept,
                height: 48,
                fontSize: 16,
                onPressed: busy || agreementMissing ? null : onAccept,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                l10n.decline,
                height: 48,
                fontSize: 16,
                variant: AppButtonVariant.outlined,
                onPressed: busy ? null : onDecline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({
    required this.client,
    required this.onMessage,
    required this.onOpen,
  });

  final DeskClient client;
  final VoidCallback onMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = clientName(l10n, client.subscription);
    final why = reasonsText(l10n, client);
    return AppCard(
      gap: 6,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      children: [
        Semantics(
          button: true,
          label: '${l10n.openTheDetailsOfName(name)}. $why',
          excludeSemantics: true,
          child: InkWell(
            onTap: onOpen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DeskAvatar(name: name, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppText.titleM.copyWith(color: AppColors.ink),
                        ),
                        Text(
                          why,
                          style: AppText.bodyM.copyWith(color: AppColors.amber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AppButton(
            l10n.message,
            height: 48,
            fontSize: 16,
            icon: Icons.chat_bubble_outline,
            variant: AppButtonVariant.tonal,
            onPressed: onMessage,
          ),
        ),
      ],
    );
  }
}
