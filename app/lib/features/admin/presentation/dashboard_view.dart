/// Z15 — Dashboard. How the product is doing, in counts that name nobody.
///
/// Served by `admin_dashboard`, which answers only an account holding the
/// `admin` claim, signed in by phone, and records every read. The numbers are
/// Firestore aggregations; no member document is opened to draw this screen.
///
/// Review waiting time is shown against the 72-hour promise C14 makes to her,
/// in amber when the oldest is past it. Amber, not red: it is the team's
/// queue running late, not a failure on anybody's part that the screen should
/// shout about.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/console_report.dart';
import '../domain/console_source.dart';
import 'admin_widgets.dart';
import 'console_labels.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.source,
    this.onBack,
    this.onOpenLogs,
    this.onOpenEvents,
  });

  final ConsoleSource source;
  final VoidCallback? onBack;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenEvents;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  ConsoleDashboard? _data;
  ConsoleFailure? _failure;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final data = await widget.source.dashboard(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final data = _data;
    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.dashboard,
        onBack: widget.onBack,
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(refresh: true),
          ),
        ],
      ),
      children: [
        AppSageNote(l10n.countsOnlyNothingHereNamesAMember),
        if (_failure case final failure?)
          ConsoleFailureNote(failure: failure, onRetry: () => _load())
        else if (data == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ..._report(l10n, data),
        AppListItem(
          leading: const Icon(
            Icons.receipt_long,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.logs,
          trailing: const AppChevron(),
          onTap: widget.onOpenLogs,
        ),
        AppListItem(
          leading: const Icon(
            Icons.event_outlined,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.events,
          trailing: const AppChevron(),
          onTap: widget.onOpenEvents,
        ),
      ],
    );
  }

  List<Widget> _report(AppL10n l10n, ConsoleDashboard d) {
    String n(int v) => countLabel(v);
    final reviewLines = <String>[
      if (d.oldestReviewHours case final hours?)
        l10n.oldestHasWaitedHoursHours(n(hours)),
      if (d.reviewsOverSla > 0)
        l10n.countPastTheHoursHourPromise(n(d.reviewsOverSla), n(d.slaHours)),
    ];
    return [
      Text(
        '${l10n.updatedTime(consoleTime(d.generatedAt))} · ${l10n.cairoTime}',
        style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
      ),
      AdminTable(
        startHeader: l10n.accounts,
        endHeader: n(d.accounts),
        rows: [(l10n.verifiedMembers, n(d.verified))],
      ),
      AppListItem(
        key: const ValueKey('dashboard-reviews'),
        variant: d.oldestIsLate
            ? AppCardVariant.amber
            : AppCardVariant.outlined,
        leading: const Icon(
          Icons.support_agent,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: '${l10n.humanReviewsWaiting} · ${n(d.reviewsPending)}',
        subtitle: reviewLines.join(' · '),
      ),
      _outcomes(l10n, l10n.checkOutcomesLast7Days, d.outcomes7),
      _outcomes(l10n, l10n.checkOutcomesLast30Days, d.outcomes30),
      AdminTable(
        startHeader: l10n.waitlist,
        endHeader: n(d.waitlist),
        rows: const [],
      ),
      AdminTable(
        startHeader: l10n.deletionRequests,
        endHeader: '',
        rows: [
          (l10n.stillRunning, n(d.deletionsRunning)),
          (l10n.finished, n(d.deletionsDone)),
        ],
      ),
      AdminTable(
        startHeader: l10n.events,
        endHeader: '',
        rows: [
          (l10n.upcoming, n(d.eventsUpcoming)),
          (l10n.drafts, n(d.eventDrafts)),
        ],
      ),
      AdminTable(
        startHeader: l10n.contentLibrary,
        endHeader: '',
        rows: [
          (l10n.exercises, n(d.content['exercises'] ?? 0)),
          (l10n.foods, n(d.content['foods'] ?? 0)),
          (l10n.recipes, n(d.content['recipes'] ?? 0)),
          (l10n.programmes, n(d.content['programs'] ?? 0)),
        ],
      ),
    ];
  }

  Widget _outcomes(AppL10n l10n, String title, Map<String, int> counts) =>
      AdminTable(
        startHeader: title,
        endHeader: '',
        rows: [
          for (final code in kOutcomeCodes)
            if (counts.containsKey(code))
              (outcomeLabel(l10n, code), countLabel(counts[code]!)),
        ],
      );
}

/// Why the console could not answer, and the one thing to do about it.
class ConsoleFailureNote extends StatelessWidget {
  const ConsoleFailureNote({super.key, required this.failure, this.onRetry});

  final ConsoleFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final (icon, text) = switch (failure) {
      ConsoleFailure.notAdmin => (
        Icons.lock_outline,
        l10n.thisAccountDoesNotHaveAdminAccess,
      ),
      ConsoleFailure.signInRequired => (
        Icons.phone_iphone,
        l10n.signInWithYourPhoneNumberTo,
      ),
      ConsoleFailure.unavailable => (
        Icons.cloud_off,
        l10n.theConsoleNeedsAConnectionTryAgain,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppEmptyState(icon: icon, title: text, body: ''),
        if (failure == ConsoleFailure.unavailable && onRetry != null) ...[
          const SizedBox(height: 12),
          AppButton(
            l10n.tryAgain,
            variant: AppButtonVariant.tonal,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
