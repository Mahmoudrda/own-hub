/// H01: find a coach. Three questions give up to five matches, then every
/// coach A to Z. Browsing only; nobody is ranked by clients or ratings.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/private_coaching_state.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_empty_state.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/hand/skeleton.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_match.dart';
import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import 'coach_card.dart';
import 'coach_directory_controller.dart';
import 'coach_labels.dart';

class FindCoachView extends StatefulWidget {
  const FindCoachView({
    super.key,
    this.repository,
    this.controller,
    this.onOpenCoach,
    this.onBack,
    this.initialGoal,
    this.initialPlace,
  });

  /// Her answers from setup, when she gave them: the quiz starts on them and
  /// she can change either. Null leaves the question open.
  final String? initialGoal;
  final String? initialPlace;

  /// Defaults to the repository the app started coaching with.
  final CoachingRepository? repository;

  /// For a test that wants to hold the streams itself.
  final CoachDirectoryController? controller;

  /// Opens one coach's portfolio by her uid.
  final ValueChanged<String>? onOpenCoach;
  final VoidCallback? onBack;

  @override
  State<FindCoachView> createState() => _FindCoachViewState();
}

class _FindCoachViewState extends State<FindCoachView> {
  late final CoachDirectoryController _directory;
  late final bool _ownsDirectory;
  late String? _goal = widget.initialGoal;
  late String? _place = widget.initialPlace;
  String? _budget;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _ownsDirectory = given == null;
    _directory =
        given ??
        CoachDirectoryController(
          widget.repository ?? PrivateCoachingState.instance.repository!,
        );
    if (_ownsDirectory) _directory.start();
  }

  @override
  void dispose() {
    if (_ownsDirectory) _directory.dispose();
    super.dispose();
  }

  void _open(String uid) => widget.onOpenCoach?.call(uid);

  Widget _question(
    String title,
    List<String> keys,
    String Function(String) label,
    String? chosen,
    ValueChanged<String> pick,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: AppText.titleS.copyWith(color: AppColors.ink),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final key in keys)
            AppChip(
              label(key),
              selected: chosen == key,
              onTap: () => pick(key),
            ),
        ],
      ),
    ],
  );

  Widget _cardFor(CoachProfile coach) => CoachCard(
    coach: coach,
    fromPriceEgp: coach.fromMonthlyEgp,
    onOpen: () => _open(coach.uid),
  );

  List<Widget> _spaced(Iterable<Widget> cards) => <Widget>[
    for (final c in cards) ...[c, const SizedBox(height: 10)],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return ListenableBuilder(
      listenable: _directory,
      builder: (context, _) => AppScaffold(
        appBar: AppTopBar(title: l10n.findACoach, onBack: widget.onBack),
        children: _body(context, l10n),
      ),
    );
  }

  List<Widget> _body(BuildContext context, AppL10n l10n) {
    switch (_directory.status) {
      case DirectoryStatus.loading:
        return <Widget>[
          Semantics(
            label: l10n.loadingCoaches,
            child: const Column(
              children: [
                Skeleton(height: 110, radius: 16),
                SizedBox(height: 10),
                Skeleton(height: 110, radius: 16),
              ],
            ),
          ),
        ];
      case DirectoryStatus.offline:
        return <Widget>[
          AppEmptyState(
            icon: Icons.cloud_off,
            title: l10n.findACoach,
            body: l10n.weCouldNotLoadTheCoachesCheck,
          ),
          AppButton(l10n.tryAgain, onPressed: _directory.start),
        ];
      case DirectoryStatus.ready:
        break;
    }
    final all = CoachMatch.allCoachesAtoZ(_directory.coaches);
    if (all.isEmpty) {
      return <Widget>[
        AppEmptyState(
          icon: Icons.groups_outlined,
          title: l10n.findACoach,
          body: l10n.coachesAreJoiningCheckBackSoon,
        ),
      ];
    }
    // A budget is asked only once money can move; until then the quiz is two
    // questions and the coaches are matched on those.
    final asksBudget = coachingPaymentsOn;
    final answered =
        _goal != null && _place != null && (!asksBudget || _budget != null);
    final matches = answered
        ? CoachMatch.rank(
            MatchAnswers(
              goal: _goal!,
              place: _place!,
              budgetBand: asksBudget ? _budget : null,
            ),
            _directory.coaches,
          )
        : const <CoachMatchResult>[];
    return <Widget>[
      Text(
        asksBudget
            ? l10n.threeQuickQuestionsThenTheCoachesWho
            : l10n.twoQuickQuestionsThenTheCoachesWho,
        style: AppText.body.copyWith(color: AppColors.textSecondary),
      ),
      _question(
        l10n.whatDoYouWantMost,
        CoachingEnums.goals,
        (k) => goalLabel(l10n, k),
        _goal,
        (k) => setState(() => _goal = k),
      ),
      _question(
        l10n.whereDoYouTrain,
        CoachingEnums.places,
        (k) => placeLabel(l10n, k),
        _place,
        (k) => setState(() => _place = k),
      ),
      if (asksBudget)
        _question(
          l10n.yourBudgetForAMonth,
          CoachingEnums.budgetBands,
          (k) => budgetLabel(l10n, k),
          _budget,
          (k) => setState(() => _budget = k),
        ),
      if (answered) ...[
        Semantics(
          header: true,
          child: Text(
            l10n.yourBestMatches,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        Text(
          matches.isEmpty
              ? l10n.noCloseMatchYetBrowseAllThe
              : asksBudget
              ? l10n.matchedOnYourThreeAnswersOnlyThen
              : l10n.matchedOnYourTwoAnswersOnlyThen,
          style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
        ),
        ..._spaced(matches.map((m) => _cardFor(m.coach))),
      ],
      Semantics(
        header: true,
        child: Text(
          l10n.allCoachesAToZ,
          style: AppText.titleL.copyWith(color: AppColors.ink),
        ),
      ),
      ..._spaced(all.map(_cardFor)),
    ];
  }
}
