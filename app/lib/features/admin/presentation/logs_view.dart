/// Z16 — Logs. What the system did, in codes, newest first.
///
/// Six logs, read through `admin_logs`: verification decisions, reviewer
/// actions, deletion runs, waitlist joins per day, function errors per day,
/// and reads of this console itself. Each is read only, a page at a time, and
/// each read is written to the console's own access log on the server, which
/// is the last of the six.
///
/// No row names anyone. A case is an eight-character reference that is the
/// same in the decisions and the reviews log and is not an id. Deletion runs
/// carry no reference at all; the waitlist is a count per day.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/console_report.dart';
import '../domain/console_source.dart';
import 'console_labels.dart';
import 'dashboard_view.dart' show ConsoleFailureNote;

class LogsView extends StatefulWidget {
  const LogsView({
    super.key,
    required this.source,
    this.initialKind = ConsoleLogKind.decisions,
    this.onBack,
  });

  final ConsoleSource source;
  final ConsoleLogKind initialKind;
  final VoidCallback? onBack;

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  late ConsoleLogKind _kind = widget.initialKind;

  /// Decisions only: one outcome code, or null for all of them.
  String? _outcome;

  final List<ConsoleLogRow> _rows = [];
  String? _next;
  ConsoleFailure? _failure;
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final kind = _kind;
    final outcome = _outcome;
    setState(() {
      _loading = true;
      _failure = null;
      if (reset) {
        _rows.clear();
        _next = null;
        _loaded = false;
      }
    });
    try {
      final page = await widget.source.logs(
        kind,
        before: reset ? null : _next,
        outcome: kind == ConsoleLogKind.decisions ? outcome : null,
      );
      if (!mounted || kind != _kind || outcome != _outcome) return;
      setState(() {
        _rows.addAll(page.rows);
        _next = page.next;
        _loading = false;
        _loaded = true;
      });
    } on ConsoleException catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.failure;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = ConsoleFailure.unavailable;
        _loading = false;
      });
    }
  }

  void _choose(ConsoleLogKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    _outcome = null;
    _load(reset: true);
  }

  void _chooseOutcome(String? code) {
    if (code == _outcome) return;
    _outcome = code;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final kinds = ConsoleLogKind.values;
    final outcomes = <String?>[null, ...kOutcomeCodes];
    return AppScaffold(
      appBar: AppTopBar(title: l10n.logs, onBack: widget.onBack),
      children: [
        AppSageNote(l10n.openingALogIsRecordedToo),
        AppChipRow(
          grow: false,
          items: [for (final k in kinds) logKindLabel(l10n, k)],
          selected: {kinds.indexOf(_kind)},
          onTap: (i) => _choose(kinds[i]),
        ),
        if (_kind == ConsoleLogKind.decisions)
          AppChipRow(
            grow: false,
            items: [
              for (final code in outcomes)
                code == null ? l10n.allOutcomes : outcomeLabel(l10n, code),
            ],
            selected: {outcomes.indexOf(_outcome)},
            onTap: (i) => _chooseOutcome(outcomes[i]),
          ),
        if (_failure case final failure?)
          ConsoleFailureNote(
            failure: failure,
            onRetry: () => _load(reset: true),
          )
        else if (!_loaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_rows.isEmpty)
          AppEmptyState(
            icon: Icons.receipt_long,
            title: l10n.nothingInTheLogYet,
            body: '',
          )
        else ...[
          for (final row in _rows) _LogRow(row: row),
          if (_next != null)
            AppButton(
              l10n.loadMore,
              variant: AppButtonVariant.outlined,
              onPressed: _loading ? null : () => _load(reset: false),
            ),
        ],
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.row});

  final ConsoleLogRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final time = consoleTime(row.at);
    String join(List<String> parts) =>
        parts.where((p) => p.isNotEmpty).join(' · ');

    final (title, subtitle) = switch (row.kind) {
      ConsoleLogKind.decisions => (
        outcomeLabel(l10n, row.outcome ?? ''),
        join([
          time,
          if (row.caseRef case final ref?) l10n.caseRef(ref),
          ...row.reasons,
        ]),
      ),
      ConsoleLogKind.reviews => (
        reviewActionLabel(l10n, row.action),
        join([
          time,
          if (row.caseRef case final ref?) l10n.caseRef(ref),
          if (row.reviewerRef case final ref?) l10n.reviewerRef(ref),
        ]),
      ),
      ConsoleLogKind.deletions => (
        deletionStateLabel(l10n, row.state),
        join([time, if (row.swept) l10n.secondSweepDone]),
      ),
      ConsoleLogKind.waitlist => (
        row.day ?? '',
        l10n.countJoined(countLabel(row.count ?? 0)),
      ),
      ConsoleLogKind.errors => (
        row.day ?? '',
        join([
          for (final e in row.counts.entries)
            '${e.key} · ${countLabel(e.value)}',
        ]),
      ),
      ConsoleLogKind.access => (
        accessActionLabel(l10n, row.action),
        join([time, if (row.adminRef case final ref?) l10n.adminRef(ref)]),
      ),
    };

    return AppListItem(
      variant: AppCardVariant.outlined,
      title: title,
      subtitle: subtitle,
      leading: Icon(
        switch (row.kind) {
          ConsoleLogKind.decisions => Icons.verified_user_outlined,
          ConsoleLogKind.reviews => Icons.support_agent,
          ConsoleLogKind.deletions => Icons.delete_sweep_outlined,
          ConsoleLogKind.waitlist => Icons.how_to_reg_outlined,
          ConsoleLogKind.errors => Icons.report_gmailerrorred_outlined,
          ConsoleLogKind.access => Icons.visibility_outlined,
        },
        size: 22,
        color: AppColors.primaryDim,
      ),
    );
  }
}
