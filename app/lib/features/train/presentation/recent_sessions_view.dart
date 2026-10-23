/// Her last 20 finished sessions, newest first. Tapping one opens it set by
/// set so a wrong figure can be fixed.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../domain/training/prescribed_set.dart';
import '../domain/set_history.dart';
import '../domain/train_repository.dart';
import 'exercise_labels.dart' show isolateLtr;
import 'move_history_sheet.dart';
import 'session_edit_view.dart';

const int kRecentSessionCount = 20;

class RecentSessionsView extends StatefulWidget {
  const RecentSessionsView({
    super.key,
    required this.repository,
    required this.nameFor,
    required this.onSessionEdited,
    this.onBack,
  });

  final InMemoryTrainRepository repository;
  final String Function(String exerciseId) nameFor;
  final void Function(String sessionId) onSessionEdited;

  final VoidCallback? onBack;

  @override
  State<RecentSessionsView> createState() => _RecentSessionsViewState();
}

class _RecentSessionsViewState extends State<RecentSessionsView> {
  Future<void> _open(TrainSession s, String title) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SessionEditView(
          sessionId: s.id,
          repository: widget.repository,
          nameFor: widget.nameFor,
          onSessionEdited: widget.onSessionEdited,
          title: title,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// A session has no title of its own, so it is named by what she did: its
  /// first two moves, and how many more. "Workout" when it names none.
  String _titleOf(List<({String exerciseId, List<LoggedSet> sets})> moves) {
    final l10n = AppL10n.of(context);
    if (moves.isEmpty) return l10n.workout;
    final names = [
      for (final m in moves.take(2))
        isolateLtr(l10n, widget.nameFor(m.exerciseId)),
    ];
    final more = moves.length - names.length;
    return more > 0
        ? '${names.join(' · ')} +${countLabel(more)}'
        : names.join(' · ');
  }

  /// The newest sessions that logged something, at most [kRecentSessionCount].
  /// A finished session with nothing logged is skipped, so the window widens
  /// until there are enough rows or no sessions left.
  List<({TrainSession session, int moves, int sets, String title})> _rows() {
    var window = kRecentSessionCount;
    while (true) {
      final sessions = widget.repository.completedSessions(limit: window);
      final rows =
          <({TrainSession session, int moves, int sets, String title})>[];
      for (final s in sessions) {
        final moves = loggedMovesOf(widget.repository, s);
        if (moves.isEmpty) continue;
        rows.add((
          session: s,
          title: _titleOf(moves),
          moves: moves.length,
          sets: moves.fold<int>(0, (a, m) => a + m.sets.length),
        ));
        if (rows.length == kRecentSessionCount) return rows;
      }
      if (sessions.length < window) return rows;
      window *= 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final rows = _rows();
    return AppScaffold(
      appBar: AppTopBar(title: l10n.recentSessions, onBack: widget.onBack),
      children: [
        if (rows.isEmpty)
          AppEmptyState(
            icon: Icons.history,
            title: l10n.noFinishedSessionsYet,
            body: l10n.sessionsYouFinishShowUpHereAnd,
          )
        else
          for (final r in rows)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: AppListItem(
                key: ValueKey('recent-${r.session.id}'),
                title: r.title,
                subtitle:
                    '${sessionDateLabel(l10n, r.session.dateKey)} · '
                    '${l10n.movesMovesSetsSets(countLabel(r.moves), countLabel(r.sets))}',
                leading: const Icon(
                  Icons.history,
                  color: AppColors.onSurfaceVariant,
                ),
                onTap: () => _open(r.session, r.title),
              ),
            ),
      ],
    );
  }
}
