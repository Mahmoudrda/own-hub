/// The eight steps, one screen each. The draft is saved on every step.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/coach_application_draft.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/coach_application.dart';
import 'apply_labels.dart';
import 'apply_rules.dart';
import 'apply_widgets.dart';
import 'steps/approach_step.dart';
import 'steps/certificates_step.dart';
import 'steps/education_step.dart';
import 'steps/feedback_step.dart';
import 'steps/personal_step.dart';
import 'steps/specialties_step.dart';
import 'steps/terms_step.dart';
import 'steps/transformations_step.dart';
import '../../domain/coaching_contract.dart';

class ApplyFlowView extends StatefulWidget {
  const ApplyFlowView({
    super.key,
    required this.draft,
    required this.tools,
    this.initialStep,
    this.returnToReview = false,
    this.onReview,
    this.onExit,
    this.onOpenTerms,
    this.now,
  });

  final CoachApplicationDraft draft;
  final ApplyTools tools;

  /// The step to open; defaults to the one she was on.
  final int? initialStep;

  /// Opened from the review page: saving goes straight back to it.
  final bool returnToReview;

  /// After the last step, or after a step opened from the review.
  final VoidCallback? onReview;

  /// Back from the first step, or the close button.
  final VoidCallback? onExit;
  final VoidCallback? onOpenTerms;

  /// For tests.
  final DateTime? now;

  @override
  State<ApplyFlowView> createState() => _ApplyFlowViewState();
}

class _ApplyFlowViewState extends State<ApplyFlowView> {
  late int _step = (widget.initialStep ?? widget.draft.step).clamp(
    1,
    kApplyStepCount,
  );
  late CoachApplication _app = widget.draft.application;
  bool _showProblems = false;

  ApplyProblems get _problems => _showProblems
      ? applyProblems(_step, _app, now: widget.now)
      : const <String, ApplyProblem>{};

  void _change(CoachApplication next) => setState(() => _app = next);

  void _saveHere() => widget.draft.update(_app, step: _step);

  void _back() {
    _saveHere();
    if (_step > 1 && !widget.returnToReview) {
      setState(() {
        _step--;
        _showProblems = false;
      });
    } else {
      widget.onExit?.call();
    }
  }

  void _close() {
    _saveHere();
    widget.onExit?.call();
  }

  void _continue() {
    if (applyProblems(_step, _app, now: widget.now).isNotEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    if (_step == 8 && _app.termsVersion != kCoachTermsVersion) {
      _app = _app.copyWith(termsVersion: kCoachTermsVersion);
    }
    final last = _step == kApplyStepCount;
    widget.draft.update(_app, step: last ? _step : _step + 1);
    if (last || widget.returnToReview) {
      widget.onReview?.call();
      return;
    }
    setState(() {
      _step++;
      _showProblems = false;
    });
  }

  String _subtitle(AppL10n l10n) => switch (_step) {
    1 => l10n.membersSeeYourDisplayNameHeadlineAnd,
    2 => l10n.addMinToMaxAPhotoOf(
      '${CoachingLimits.educationMin}',
      '${CoachingLimits.educationMax}',
    ),
    3 => l10n.addMinToMaxEachOneNeeds(
      '${CoachingLimits.certificatesMin}',
      '${CoachingLimits.certificatesMax}',
    ),
    4 => l10n.chooseMinToMaxThenTellUs(
      '${CoachingLimits.specialtiesMin}',
      '${CoachingLimits.specialtiesMax}',
    ),
    5 => l10n.addMinToMaxMessagesFromWomen(
      '${CoachingLimits.testimonialsMin}',
      '${CoachingLimits.testimonialsMax}',
    ),
    6 => l10n.addMinToMaxThePhotosAre(
      '${CoachingLimits.transformationsMin}',
      '${CoachingLimits.transformationsMax}',
    ),
    7 => '',
    _ => l10n.readThesePointsThenTickTheThree,
  };

  Widget _body() {
    final problems = _problems;
    return switch (_step) {
      1 => PersonalStep(
        app: _app,
        problems: problems,
        tools: widget.tools,
        onChanged: _change,
      ),
      2 => EducationStep(
        app: _app,
        problems: problems,
        tools: widget.tools,
        onChanged: _change,
      ),
      3 => CertificatesStep(
        app: _app,
        problems: problems,
        tools: widget.tools,
        onChanged: _change,
      ),
      4 => SpecialtiesStep(app: _app, problems: problems, onChanged: _change),
      5 => FeedbackStep(
        app: _app,
        problems: problems,
        tools: widget.tools,
        onChanged: _change,
      ),
      6 => TransformationsStep(
        app: _app,
        problems: problems,
        tools: widget.tools,
        onChanged: _change,
      ),
      7 => ApproachStep(app: _app, problems: problems, onChanged: _change),
      _ => TermsStep(
        app: _app,
        problems: problems,
        onChanged: _change,
        onOpenTerms: widget.onOpenTerms,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ApplyScaffold(
        step: _step,
        title: applyStepTitle(l10n, _step),
        subtitle: _subtitle(l10n),
        onBack: _back,
        onClose: _close,
        onContinue: _continue,
        children: [
          if (_showProblems && _problems.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.somethingIsStillMissingLookAtThe,
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          // A new key per step so the fields start from the right values.
          KeyedSubtree(key: ValueKey<int>(_step), child: _body()),
        ],
      ),
    );
  }
}
