/// One package: start from a template or blank, set what is in it and her own
/// price, and see it the way a member will before it is saved.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../app_state/honest_notice.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/pricing.dart';
import 'coach_data.dart';
import 'coach_templates.dart';
import 'coach_text.dart';
import 'coach_validation.dart';
import 'coach_widgets.dart';
import 'package_preview_card.dart';

class PackageEditView extends StatefulWidget {
  const PackageEditView({super.key, required this.data, this.package});

  final CoachSpaceData data;

  /// Null for a new package.
  final CoachPackage? package;

  @override
  State<PackageEditView> createState() => _PackageEditViewState();
}

class _PackageEditViewState extends State<PackageEditView> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final List<TextEditingController> _includes = <TextEditingController>[];
  int _duration = 28;
  int _sessions = CoachingLimits.liveSessionsPerMonthMin;
  int _minutes = 30;
  int _reviews = 0;
  bool _active = true;
  int _position = 1;
  String? _packageId;

  bool _busy = false;
  bool _priceTyped = false;
  bool _tried = false;
  String _error = '';
  int? _receivesEgp;

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    if (p != null) {
      _packageId = p.id;
      _apply(
        PackageDraft(
          packageId: p.id,
          title: p.title,
          description: p.description,
          durationDays: p.durationDays,
          includes: p.includes,
          liveSessionsPerMonth: p.liveSessionsPerMonth,
          sessionMinutes: p.sessionMinutes,
          checkInsPerWeek: p.checkInsPerWeek,
          coachPriceEgp:
              widget.data.prices[p.id] ??
              coachPriceFromFinal(p.priceFinalEgp) ??
              0,
          active: p.active,
          order: p.order,
        ),
      );
    } else {
      final next = widget.data.packages.length;
      _position = (next + 1).clamp(1, CoachingLimits.maxPackages);
    }
    widget.data.addListener(_syncPrice);
  }

  /// Her own price can arrive after the form opens; show it unless she has
  /// already typed one.
  void _syncPrice() {
    final id = _packageId;
    final real = id == null ? null : widget.data.prices[id];
    if (real == null || _priceTyped || _price.text == '$real') return;
    setState(() => _price.text = '$real');
  }

  @override
  void dispose() {
    widget.data.removeListener(_syncPrice);
    _title.dispose();
    _description.dispose();
    _price.dispose();
    for (final c in _includes) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(PackageDraft d) {
    _title.text = d.title;
    _description.text = d.description;
    _price.text = d.coachPriceEgp > 0 ? '${d.coachPriceEgp}' : '';
    for (final c in _includes) {
      c.dispose();
    }
    _includes
      ..clear()
      ..addAll(d.includes.map((l) => TextEditingController(text: l)));
    _duration = d.durationDays;
    _sessions = d.liveSessionsPerMonth;
    _minutes = d.sessionMinutes;
    _reviews = d.checkInsPerWeek;
    _active = d.active;
    _position = d.order + 1;
  }

  int get _priceValue => int.tryParse(_price.text.trim()) ?? 0;

  PackageDraft _draft() => PackageDraft(
    packageId: _packageId,
    title: westernDigits(_title.text),
    description: westernDigits(_description.text),
    durationDays: _duration,
    includes: <String>[
      for (final c in _includes)
        if (c.text.trim().isNotEmpty) westernDigits(c.text.trim()),
    ],
    liveSessionsPerMonth: _sessions,
    sessionMinutes: _minutes,
    checkInsPerWeek: _reviews,
    coachPriceEgp: _priceValue,
    active: _active,
    order: _position - 1,
  );

  void _template(PackageTemplate template) {
    final l10n = AppL10n.of(context);
    setState(() {
      _apply(
        templateDraft(
          l10n,
          template,
          order: (_position - 1).clamp(0, CoachingLimits.maxPackages - 1),
        ),
      );
      _tried = false;
    });
  }

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _tried = true;
      _error = '';
      _receivesEgp = null;
    });
    final draft = _draft();
    if (packageProblems(draft).isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.data.repository.saveCoachPackage(draft);
      if (!mounted) return;
      setState(() {
        _packageId = saved.packageId;
        _receivesEgp = saved.youReceiveEgp;
        _tried = false;
      });
      showHonestNotice(context, l10n.saved);
    } on CoachingFailure catch (failure) {
      if (mounted) setState(() => _error = coachFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _range(AppL10n l10n, int low, int high) =>
      l10n.useLowToHighCharacters(countLabel(low), countLabel(high));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final draft = _draft();
    final problems = _tried ? packageProblems(draft) : const <String>[];
    final priceOk = coachPriceInRange(_priceValue);
    final preview = CoachPackage(
      id: _packageId ?? 'preview',
      title: draft.title.trim(),
      description: draft.description.trim(),
      durationDays: draft.durationDays,
      includes: draft.includes,
      liveSessionsPerMonth: draft.liveSessionsPerMonth,
      sessionMinutes: draft.sessionMinutes,
      checkInsPerWeek: draft.checkInsPerWeek,
      priceFinalEgp: priceOk ? finalPrice(_priceValue) : 0,
      active: draft.active,
      order: draft.order,
    );
    final priceHint = l10n.wholePoundsFromLowToHigh(
      countLabel(CoachingLimits.coachPriceMinEgp),
      countLabel(CoachingLimits.coachPriceMaxEgp),
    );
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: widget.package == null ? l10n.newPackage : l10n.editPackage,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [AppButton(l10n.savePackage, onPressed: _busy ? null : _save)],
      children: [
        if (widget.package == null) ...[
          CoachHeading(l10n.startFromATemplate),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in PackageTemplate.values)
                AppChip(templateLabel(l10n, t), onTap: () => _template(t)),
            ],
          ),
        ],
        AppField(
          controller: _title,
          label: l10n.packageName,
          errorText: problems.contains('title')
              ? _range(l10n, kTitleMin, CoachingLimits.packageTitleMax)
              : '',
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _description,
          label: l10n.description,
          maxLines: 4,
          errorText: problems.contains('description')
              ? _range(
                  l10n,
                  kDescriptionMin,
                  CoachingLimits.packageDescriptionMax,
                )
              : '',
          onChanged: (_) => setState(() {}),
        ),
        CoachHeading(l10n.length),
        AppChipRow(
          items: [
            for (final d in CoachingLimits.durationDays)
              l10n.daysPluralOne1DayOtherDays(d),
          ],
          selected: {CoachingLimits.durationDays.indexOf(_duration)},
          onTap: (i) =>
              setState(() => _duration = CoachingLimits.durationDays[i]),
        ),
        CoachHeading(l10n.whatIsIncluded),
        for (var i = 0; i < _includes.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppField(
                  controller: _includes[i],
                  label: '',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: l10n.removeThisLine,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _includes.removeAt(i).dispose();
                }),
              ),
            ],
          ),
        if (_includes.length < CoachingLimits.includesMax)
          AppButton(
            l10n.addALine,
            variant: AppButtonVariant.text,
            icon: Icons.add,
            onPressed: () =>
                setState(() => _includes.add(TextEditingController())),
          ),
        if (problems.contains('includes'))
          CoachFieldError(
            l10n.add1ToMaxLinesEachLow(
              countLabel(CoachingLimits.includesMax),
              countLabel(kIncludeMin),
              countLabel(CoachingLimits.includeTextMax),
            ),
          ),
        AppCard(
          variant: AppCardVariant.filled,
          gap: 4,
          children: [
            CoachStepper(
              label: l10n.liveSessionsAMonth,
              value: _sessions,
              min: CoachingLimits.liveSessionsPerMonthMin,
              max: CoachingLimits.liveSessionsPerMonthMax,
              display: countLabel(_sessions),
              onChanged: (v) => setState(() => _sessions = v),
            ),
            CoachStepper(
              label: l10n.progressReviewsAWeek,
              value: _reviews,
              min: 0,
              max: CoachingLimits.checkInsPerWeekMax,
              display: countLabel(_reviews),
              onChanged: (v) => setState(() => _reviews = v),
            ),
            CoachStepper(
              label: l10n.positionInYourList,
              value: _position,
              min: 1,
              max: CoachingLimits.maxPackages,
              display: countLabel(_position),
              onChanged: (v) => setState(() => _position = v),
            ),
          ],
        ),
        CoachHeading(l10n.sessionLength),
        AppChipRow(
          items: [
            for (final m in CoachingLimits.sessionMinutes)
              l10n.countMin(countLabel(m)),
          ],
          selected: {CoachingLimits.sessionMinutes.indexOf(_minutes)},
          onTap: (i) =>
              setState(() => _minutes = CoachingLimits.sessionMinutes[i]),
        ),
        AppField(
          controller: _price,
          label: l10n.yourPriceEgp,
          helper: priceHint,
          errorText: problems.contains('coachPriceEgp') ? priceHint : '',
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() => _priceTyped = true),
        ),
        if (priceOk)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.membersSeeEgpPrice(countLabel(finalPrice(_priceValue))),
              style: AppText.titleM,
            ),
          ),
        CoachSwitchRow(
          title: l10n.showThisPackageToMembers,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        CoachHeading(l10n.howMembersSeeIt),
        PackagePreviewCard(preview),
        if (_error.isNotEmpty) CoachFieldError(_error),
        if (_receivesEgp != null)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.savedYouReceiveEgpAmount(countLabel(_receivesEgp!)),
              style: AppText.titleS.copyWith(color: AppColors.tertiary),
            ),
          ),
      ],
    );
  }
}
