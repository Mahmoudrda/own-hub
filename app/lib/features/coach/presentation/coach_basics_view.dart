/// `K01` — Your basics.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K01`.
///
/// # The one place this screen departs from the prototype, and why
///
/// The mockup writes *"Face visible. Clients pick a person, not a logo"* as a
/// caption under her photo — an instruction. §2 rule 6 says blur defaults on,
/// and G12 §9 **Q1** records the collision and its resolution: *"default
/// blurred, with an explicit 'show my face' action … Confirm the copy reflects
/// a choice, not an instruction."*
///
/// So the sentence stays, and it is attached to a control rather than to a
/// photo. Blur is on when she arrives (`P1-RULE-14`), the switch is named, and
/// the line under it changes to state what each position means: faces blurred
/// before it uploads, or her face visible to the women choosing a coach. She is
/// told what happens either way and nothing flips silently.
///
/// The blur itself is resolved by [CoachMediaUploader], which delegates to G7's
/// `MediaBlurPolicy` — there is no code path here that reads the flag directly.
///
/// # The three rules, agreed here
///
/// A woman who signs up to coach does not pass through `C16`, the community's
/// pledge: her way on from `C13` is this screen. So the same three rules are
/// printed under her basics with a checkbox, and Continue waits for it. The
/// router records the agreement exactly as `C16` does (`recordPledge`: the
/// version on the phone and `record_pledge` on the server), so a coach and a
/// trainee have agreed to the same words, under the same version number. A
/// woman who has already agreed sees the box ticked.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_profile.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachBasicsView extends StatefulWidget {
  const CoachBasicsView({
    super.key,
    required this.model,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
    this.onChangePhoto,
    this.rulesAgreed = false,
  });

  final CoachSetupViewModel model;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  /// There is no photo pipeline in this feature yet, so this is wired by the
  /// host and does nothing by default — the control is drawn because the blur
  /// decision belongs beside it, not because a camera exists.
  final VoidCallback? onChangePhoto;

  /// Whether she has already agreed to the three rules as they stand. The box
  /// starts ticked when she has.
  final bool rulesAgreed;

  @override
  State<CoachBasicsView> createState() => _CoachBasicsViewState();
}

class _CoachBasicsViewState extends State<CoachBasicsView> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _tagline;
  late bool _agreed = widget.rulesAgreed;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.model.displayName);
    _city = TextEditingController(text: widget.model.city);
    _tagline = TextEditingController(text: widget.model.tagline);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _tagline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return CoachSetupScaffold(
      step: CoachSetupStep.basics,
      title: l10n.tellClientsWhoYouAre,
      subtitle: l10n.thisIsTheTopOfYourPublic,
      onBack: widget.onBack,
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: model.canAdvanceFrom(CoachSetupStep.basics) && _agreed
          ? () => goToScreen(context, 'K02', widget.onContinue)
          : null,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PhotoWell(
              blurred: model.photoBlurred,
              onTap: widget.onChangePhoto,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.yourPhoto, style: AppText.titleM),
                  const SizedBox(height: 3),
                  // The consequence of the switch below, stated in the
                  // position she is currently in.
                  Text(
                    model.photoBlurred
                        ? l10n.facesBlurredBeforeItUploads
                        : l10n.faceVisibleClientsPickAPersonNot,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Rule 6, as a named action. On when she arrives; only this moves it.
        Row(
          children: [
            Expanded(
              child: Text(l10n.blurFacesInMyPhotos, style: AppText.titleS),
            ),
            const SizedBox(width: 12),
            AppToggle(
              value: model.photoBlurred,
              semanticLabel: l10n.blurFacesInMyPhotos,
              onChanged: (on) => setState(() => model.photoBlurred = on),
            ),
          ],
        ),
        AppField(
          controller: _name,
          label: l10n.name,
          textInputAction: TextInputAction.next,
          onChanged: (value) => setState(() => model.displayName = value),
        ),
        AppField(
          controller: _city,
          label: l10n.city,
          textInputAction: TextInputAction.next,
          onChanged: (value) => setState(() => model.city = value),
        ),
        AppField(
          controller: _tagline,
          label: l10n.oneLineAboutYou,
          onChanged: (value) => setState(() => model.tagline = value),
        ),
        // C16's rules, the same words under the same version.
        const HandRule(seed: 44, height: 8),
        Text(l10n.howWeTreatEachOther, style: AppText.titleM),
        Text(
          l10n.asACoachYouAgreeToThe,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        _Rule(
          title: l10n.n1WhatIsSaidHereStaysHere,
          body: l10n.noScreenshotsNoSharingAnyoneElseOutside,
        ),
        _Rule(
          title: l10n.n2NoCommentsOnAnyoneElsesBody,
          body: l10n.notEvenAComplimentTalkAboutThe,
        ),
        _Rule(
          title: l10n.n3NoSellingNoRecruiting,
          body: l10n.coachesHaveProfilesForThat,
        ),
        CheckboxListTile(
          value: _agreed,
          onChanged: (on) => setState(() => _agreed = on ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: Text(l10n.iAgreeToTheseThreeRules, style: AppText.titleS),
        ),
      ],
    );
  }
}

/// One of the three rules, set as `C16` sets it.
class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: AppText.titleS),
      const SizedBox(height: 2),
      Text(
        body,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ],
  );
}

/// Her photo, or the place one will go.
///
/// Draws the blur state rather than a picture, because there is no picture: the
/// upload pipeline is G8's and is not wired here. A well that looked like a
/// photo would be the stub the brief forbids.
class _PhotoWell extends StatelessWidget {
  const _PhotoWell({required this.blurred, this.onTap});

  final bool blurred;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            blurred ? Icons.blur_on : Icons.photo_camera,
            size: 30,
            color: AppColors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
