/// Every client in one list, like a chat list: search by name, filter by what
/// needs her, newest activity first. Built lazily so hundreds of clients stay
/// smooth, and from the lists already streamed, so a row costs no read.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/private_coaching_state.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_empty_state.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/hand/hand.dart';
import '../coach/coach_text.dart';
import 'desk_model.dart';
import 'desk_source.dart';
import 'desk_widgets.dart';

class ClientsView extends StatefulWidget {
  const ClientsView({
    super.key,
    this.state,
    this.now,
    this.initialFilter = DeskFilter.all,
    this.onBack,
    this.onOpenChat,
    this.onOpenClient,
  });

  final PrivateCoachingState? state;

  /// The clock, for a test.
  final DateTime Function()? now;
  final DeskFilter initialFilter;
  final VoidCallback? onBack;

  /// Opens a client's chat by its relationship id.
  final ValueChanged<String>? onOpenChat;

  /// Opens a client's details by her subscription id.
  final ValueChanged<String>? onOpenClient;

  @override
  State<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<ClientsView> {
  late DeskFilter _filter = widget.initialFilter;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  PrivateCoachingState get _state =>
      widget.state ?? PrivateCoachingState.instance;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _filterLabel(AppL10n l10n, DeskFilter f) => switch (f) {
    DeskFilter.all => l10n.all,
    DeskFilter.unread => l10n.unread,
    DeskFilter.followUp => l10n.followUp_n22yh,
    DeskFilter.endingSoon => l10n.endingSoon,
  };

  String _emptyText(AppL10n l10n) {
    if (_query.trim().isNotEmpty) return l10n.nobodyMatchesThatSearch;
    return switch (_filter) {
      DeskFilter.all => l10n.shareYourPortfolioLinkSoMembersCan,
      DeskFilter.unread => l10n.noUnreadChatsRightNow,
      DeskFilter.followUp => l10n.nobodyNeedsAFollowUpRightNow,
      DeskFilter.endingSoon => l10n.nobodyIsEndingSoon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return RedrawOnChange(
      builder: (context) {
        final state = _state;
        final now = (widget.now ?? DateTime.now)();
        final model = state.deskModel(now);
        final rows = model.filtered(_filter, _query);
        final myUid = state.repository?.uid;
        final waiting = state.loading && model.clients.isEmpty;
        final failure = state.failure;
        return PaperPage(
          color: AppColors.surface,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppTopBar(title: l10n.clients, onBack: widget.onBack),
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(l10n, model)),
                  if (waiting)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Semantics(
                          label: l10n.clients,
                          child: const Column(
                            children: [
                              Skeleton(height: 64, radius: 12),
                              SizedBox(height: 10),
                              Skeleton(height: 64, radius: 12),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (rows.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AppEmptyState(
                          icon: failure != null
                              ? Icons.cloud_off
                              : Icons.groups_outlined,
                          title: failure != null
                              ? l10n.clients
                              : (model.clients.isEmpty
                                    ? l10n.noClientsYet
                                    : l10n.clients),
                          body: failure != null
                              ? coachFailureText(l10n, failure)
                              : _emptyText(l10n),
                        ),
                      ),
                    )
                  else
                    SliverList.separated(
                      itemCount: rows.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DeskClientRow(
                          key: ValueKey<String>(rows[i].id),
                          client: rows[i],
                          myUid: myUid,
                          now: now,
                          onOpenChat: () =>
                              widget.onOpenChat?.call(rows[i].relId),
                          onOpenClient: () =>
                              widget.onOpenClient?.call(rows[i].id),
                        ),
                      ),
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 88,
                        endIndent: 16,
                        color: AppColors.borderWarm,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(AppL10n l10n, DeskModel model) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            style: AppText.body.copyWith(color: AppColors.ink),
            decoration: InputDecoration(
              hintText: l10n.searchClients,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surfaceLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in DeskFilter.values)
              AppChip(
                f == DeskFilter.all
                    ? _filterLabel(l10n, f)
                    : '${_filterLabel(l10n, f)} · ${model.countOf(f)}',
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
          ],
        ),
      ],
    ),
  );
}
