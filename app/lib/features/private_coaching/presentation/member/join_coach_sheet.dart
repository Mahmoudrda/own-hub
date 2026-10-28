/// "Ask to join": the intake a member sends with a request, and the state
/// after it is sent. No price is sent; the server does the final checks.
library;

import 'package:flutter/material.dart';

import '../../../../domain/flags/feature_flags.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../routing/app_router.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_sheet.dart';
import '../../../account/presentation/allergen_labels.dart';
import '../../../signup/domain/legal_acceptance.dart' show kAppVersion;
import '../../data/coaching_repository.dart';
import '../../data/inbody_ocr.dart';
import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/inbody_scan.dart';
import '../../domain/requests.dart';
import '../../domain/setup_prefill.dart';
import '../../domain/subscription.dart';
import '../client/inbody_scan_sheet.dart';
import 'coach_labels.dart';

Future<void> showJoinCoachSheet({
  required BuildContext context,
  required CoachingRepository repository,
  required CoachProfile coach,
  required CoachPackage package,
  List<String> declaredAllergies = const <String>[],
  String firstName = '',
  SetupAnswers? setupAnswers,
}) => showAppSheet<void>(
  context: context,
  children: [
    JoinCoachForm(
      repository: repository,
      coach: coach,
      package: package,
      declaredAllergies: declaredAllergies,
      firstName: firstName,
      setupAnswers: setupAnswers ?? AppRouter.setupAnswersForCoaching(),
    ),
    const SizedBox(height: 12),
  ],
);

String levelLabel(AppL10n l10n, String level) => switch (level) {
  'beginner' => l10n.beginner,
  'intermediate' => l10n.intermediate,
  'advanced' => l10n.advanced,
  _ => level,
};

String healthQuestionLabel(AppL10n l10n, String id) => switch (id) {
  'heart' => l10n.hasADoctorEverSaidYouHave,
  'chestPain' => l10n.doYouFeelPainInYourChest,
  'dizziness' => l10n.doYouFeelDizzyOrFaintWhen,
  'chronicCondition' => l10n.doYouHaveALongTermCondition,
  'medication' => l10n.doYouTakeMedicationEveryDay,
  'boneJoint' => l10n.doYouHaveABoneOrJoint,
  'supervisedOnly' => l10n.hasADoctorToldYouToExercise,
  _ => id,
};

/// What a refused request says, in her words.
String joinFailureText(AppL10n l10n, Object error) {
  if (error is CoachingFailure) {
    switch (error.refusal) {
      case CoachingRefusal.alreadyRequested:
        return l10n.youAlreadyAskedToJoinThisCoach;
      case CoachingRefusal.coachUnavailable:
      case CoachingRefusal.coachSuspended:
        return l10n.thisCoachIsNotTakingNewClients;
      default:
        break;
    }
  }
  return l10n.weCouldNotSendYourRequestTry;
}

class JoinCoachForm extends StatefulWidget {
  const JoinCoachForm({
    super.key,
    required this.repository,
    required this.coach,
    required this.package,
    this.declaredAllergies = const <String>[],
    this.firstName = '',
    this.inbodyOcr,
    this.setupAnswers = noSetupAnswers,
  });

  final CoachingRepository repository;
  final CoachProfile coach;
  final CoachPackage package;

  /// Wire names of the allergies on her profile; each can be taken off.
  final List<String> declaredAllergies;

  /// Her first name on this phone, offered in the name field. She can change
  /// it or empty it.
  final String firstName;

  /// Null reads an InBody sheet with the phone's own text recognition.
  final InBodyOcr? inbodyOcr;

  /// Her goal, level, days and place from setup, each one still a choice she
  /// can change. Never her health, life stage or eating answers.
  final SetupAnswers setupAnswers;

  @override
  State<JoinCoachForm> createState() => _JoinCoachFormState();
}

class _JoinCoachFormState extends State<JoinCoachForm> {
  final TextEditingController _note = TextEditingController();
  late final TextEditingController _name = TextEditingController(
    text: widget.firstName,
  );
  late final Set<String> _allergies = <String>{...widget.declaredAllergies};
  late String? _goal = widget.setupAnswers.goal;
  late String? _level = widget.setupAnswers.level;
  late int? _days = widget.setupAnswers.days;
  late String? _place = widget.setupAnswers.place;
  final Map<String, bool> _health = <String, bool>{};
  bool _doctorAck = false;
  String? _stage; // null = not answered, 'none' | 'pregnant' | 'postpartum'
  bool? _eating;
  bool _shares = false;
  bool _stored = false;
  InBodyScan? _inbody;
  bool _inbodyShared = false;
  bool _sending = false;
  bool _sent = false;
  String? _failure;

  @override
  void dispose() {
    _note.dispose();
    _name.dispose();
    super.dispose();
  }

  Intake _intake() => Intake(
    goal: _goal ?? '',
    level: _level ?? '',
    daysPerWeek: _days ?? 0,
    place: _place ?? '',
    allergies: <String>[
      for (final a in widget.declaredAllergies)
        if (_allergies.contains(a)) a,
    ],
    health: Map<String, bool>.of(_health),
    doctorAck: _doctorAck,
    lifeStage: (_stage == 'pregnant' || _stage == 'postpartum') ? _stage : null,
    eatingHistory: _eating == true,
    note: _note.text.trim(),
    inbodyScan: _inbody,
  );

  bool get _anyYes => _health.values.any((yes) => yes);

  bool get _flagged =>
      _anyYes ||
      _stage == 'pregnant' ||
      _stage == 'postpartum' ||
      _eating == true;

  bool get _ready =>
      _intake().isValid &&
      _stage != null &&
      _eating != null &&
      _shares &&
      _stored &&
      (_inbody == null || _inbodyShared);

  Future<void> _send() async {
    if (_sending || !_ready) return;
    final l10n = AppL10n.of(context);
    final locale = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      await widget.repository.requestCoaching(
        coachUid: widget.coach.uid,
        packageId: widget.package.id,
        intake: _intake(),
        consent: CoachingRequests.requestConsent(
          shareText: l10n.iShareTheseAnswersWithNameMy(
            widget.coach.displayName,
          ),
          transferText: l10n.iAgreeThatMyAnswersAreSent,
          inbodyText: _inbody == null
              ? null
              : l10n.iShareMyInbodyNumbersWithName(widget.coach.displayName),
          appVersion: kAppVersion,
        ),
        locale: locale,
        clientName: _name.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failure = joinFailureText(l10n, error);
        });
      }
    }
  }

  Future<void> _addInbody() async {
    final scan = await showInBodyScanSheet(
      context: context,
      mode: InBodyMode.forCoach,
      ocr: widget.inbodyOcr,
    );
    if (scan != null && scan.isNotEmpty && mounted) {
      setState(() => _inbody = scan);
    }
  }

  Widget _title(String text) => Semantics(
    header: true,
    child: Text(text, style: AppText.titleS.copyWith(color: AppColors.ink)),
  );

  Widget _chips(
    List<String> keys,
    String Function(String) label,
    String? chosen,
    ValueChanged<String> pick,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final key in keys)
        AppChip(label(key), selected: chosen == key, onTap: () => pick(key)),
    ],
  );

  Widget _tick(bool value, String text, ValueChanged<bool> set) => Material(
    type: MaterialType.transparency,
    child: CheckboxListTile(
      value: value,
      onChanged: (v) => set(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(text, style: AppText.bodyM),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = widget.coach.displayName;
    if (_sent) {
      final hours = widget.coach.replyHours;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.requestSent,
              style: AppText.titleL.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hours == null
                ? l10n.nameWillGetBackToYouSoon(name)
                : l10n.nameUsuallyRepliesWithinHoursHours(name, hours),
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.youCanSeeItUnderMyCoach,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppButton(
            l10n.done_54ca1,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
    final allergyKeys = widget.declaredAllergies;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.tellNameAboutYou(name),
              style: AppText.titleL.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            maxLength: CoachingLimits.displayNameMax,
            textInputAction: TextInputAction.next,
            style: AppText.body.copyWith(color: AppColors.ink),
            decoration: InputDecoration(
              labelText: l10n.nameYourCoachSees,
              helperText: l10n.yourFirstNameIsOptionalYourCoach,
              helperMaxLines: 3,
              filled: true,
              fillColor: AppColors.surfaceLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _title(l10n.whatDoYouWantMost),
          const SizedBox(height: 8),
          _chips(
            CoachingEnums.goals,
            (k) => goalLabel(l10n, k),
            _goal,
            (k) => setState(() => _goal = k),
          ),
          const SizedBox(height: 14),
          _title(l10n.yourLevel),
          const SizedBox(height: 8),
          _chips(
            CoachingEnums.levels,
            (k) => levelLabel(l10n, k),
            _level,
            (k) => setState(() => _level = k),
          ),
          const SizedBox(height: 14),
          _title(l10n.daysAWeekYouCanTrain),
          const SizedBox(height: 8),
          _chips(
            <String>['1', '2', '3', '4', '5', '6', '7'],
            (k) => k,
            _days?.toString(),
            (k) => setState(() => _days = int.parse(k)),
          ),
          const SizedBox(height: 14),
          _title(l10n.whereDoYouTrain),
          const SizedBox(height: 8),
          _chips(
            CoachingEnums.places,
            (k) => placeLabel(l10n, k),
            _place,
            (k) => setState(() => _place = k),
          ),
          if (allergyKeys.isNotEmpty) ...[
            const SizedBox(height: 14),
            _title(l10n.allergiesFromYourProfile),
            Text(
              l10n.tapOneToTakeItOffThe,
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in allergyKeys)
                  AppChip(
                    allergenLabelForWire(l10n, a) ?? a,
                    selected: _allergies.contains(a),
                    onTap: () => setState(() {
                      if (!_allergies.remove(a)) _allergies.add(a);
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _title(l10n.aFewQuestionsAboutYourHealth),
          Text(
            l10n.answerEachOneWithYesOrNo,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          for (final q in CoachingEnums.healthQuestions) ...[
            const SizedBox(height: 10),
            Text(healthQuestionLabel(l10n, q), style: AppText.body),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                AppChip(
                  l10n.yes_6deo,
                  selected: _health[q] == true,
                  onTap: () => setState(() => _health[q] = true),
                ),
                AppChip(
                  l10n.no,
                  selected: _health[q] == false,
                  onTap: () => setState(() => _health[q] = false),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(l10n.areYouPregnantOrDidYouHave, style: AppText.body),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              AppChip(
                l10n.no,
                selected: _stage == 'none',
                onTap: () => setState(() => _stage = 'none'),
              ),
              AppChip(
                l10n.pregnant,
                selected: _stage == 'pregnant',
                onTap: () => setState(() => _stage = 'pregnant'),
              ),
              AppChip(
                l10n.hadABaby,
                selected: _stage == 'postpartum',
                onTap: () => setState(() => _stage = 'postpartum'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(l10n.hasFoodOrWeightEverFeltOut, style: AppText.body),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              AppChip(
                l10n.yes_6deo,
                selected: _eating == true,
                onTap: () => setState(() => _eating = true),
              ),
              AppChip(
                l10n.no,
                selected: _eating == false,
                onTap: () => setState(() => _eating = false),
              ),
            ],
          ),
          Text(
            l10n.yourCoachReadsThisFirstYouDo,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
          if (_flagged) ...[
            const SizedBox(height: 10),
            _tick(
              _doctorAck,
              l10n.iWillCheckWithMyDoctorBefore,
              (v) => setState(() => _doctorAck = v),
            ),
            Text(
              l10n.yourCoachWillReadYourAnswersBefore,
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (AppRouter.featureFlags.isOn(Feature.inbodyScan)) ...[
            const SizedBox(height: 14),
            _title(
              _inbody == null
                  ? l10n.addYourInbodyNumbers
                  : l10n.inbodyNumbersAdded,
            ),
            if (_inbody == null) ...[
              Text(
                l10n.optionalYourCoachSeesTheNumbersNever,
                style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              AppButton(
                l10n.readMyInbodySheet,
                key: const ValueKey('join-inbody-add'),
                variant: AppButtonVariant.outlined,
                onPressed: _addInbody,
              ),
            ] else
              Wrap(
                spacing: 8,
                children: [
                  AppButton(
                    l10n.change,
                    key: const ValueKey('join-inbody-change'),
                    variant: AppButtonVariant.text,
                    onPressed: _addInbody,
                  ),
                  AppButton(
                    l10n.remove,
                    key: const ValueKey('join-inbody-remove'),
                    variant: AppButtonVariant.text,
                    onPressed: () => setState(() {
                      _inbody = null;
                      _inbodyShared = false;
                    }),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            maxLength: CoachingLimits.noteMax,
            style: AppText.body.copyWith(color: AppColors.ink),
            decoration: InputDecoration(
              labelText: l10n.aNoteForTheCoachOptional,
              filled: true,
              fillColor: AppColors.surfaceLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
            ),
          ),
          _tick(
            _shares,
            l10n.iShareTheseAnswersWithNameMy(name),
            (v) => setState(() => _shares = v),
          ),
          if (_inbody != null)
            _tick(
              _inbodyShared,
              l10n.iShareMyInbodyNumbersWithName(name),
              (v) => setState(() => _inbodyShared = v),
            ),
          _tick(
            _stored,
            l10n.iAgreeThatMyAnswersAreSent,
            (v) => setState(() => _stored = v),
          ),
          if (!_ready)
            Text(
              l10n.answerEveryQuestionAndTickTheBoxes,
              style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
            ),
          if (_failure != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _failure!,
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 12),
          AppButton(
            l10n.sendRequest,
            onPressed: _sending || !_ready ? null : _send,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.freeWhileOwnHubOpensCoaching,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
