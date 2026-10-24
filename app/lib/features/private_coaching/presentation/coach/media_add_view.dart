/// One form to add a transformation, a client's feedback or a photo of her
/// work. Pictures are uploaded first, then the item is sent for Own Hub's
/// check.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/profile_photo_state.dart'
    show ProfilePhotoPermissionDenied;
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/portfolio_media.dart';
import 'coach_data.dart';
import 'coach_photo.dart';
import 'coach_text.dart';
import 'coach_widgets.dart';

class MediaAddView extends StatefulWidget {
  const MediaAddView({
    super.key,
    required this.data,
    required this.kind,
    this.imageChooser = chooseCoachImage,
  });

  final CoachSpaceData data;
  final MediaKind kind;
  final CoachImageChooser imageChooser;

  @override
  State<MediaAddView> createState() => _MediaAddViewState();
}

class _MediaAddViewState extends State<MediaAddView> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _text = TextEditingController();
  final TextEditingController _from = TextEditingController();
  final TextEditingController _caption = TextEditingController();
  CoachImage? _before;
  CoachImage? _after;
  CoachImage? _release;
  CoachImage? _single;
  int _weeks = 8;
  bool _consent = false;
  bool _busy = false;
  bool _tried = false;
  String _error = '';
  String _done = '';

  @override
  void dispose() {
    _note.dispose();
    _text.dispose();
    _from.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(void Function(CoachImage) assign) async {
    final l10n = AppL10n.of(context);
    setState(() => _error = '');
    try {
      final image = await widget.imageChooser(context);
      if (image != null && mounted) setState(() => assign(image));
    } on ProfilePhotoPermissionDenied {
      if (mounted) {
        setState(() => _error = l10n.theCameraIsTurnedOffForOwn);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.thatPictureCouldNotBeUsedTry);
      }
    }
  }

  CoachingRepository get _repository => widget.data.repository;

  Future<String> _upload(CoachDocFolder folder, CoachImage image) =>
      _repository.uploadCoachDoc(folder, image.bytes, image.contentType);

  /// The draft with the pictures not uploaded yet: only used to check.
  MediaDraft _check() => switch (widget.kind) {
    MediaKind.transformation => MediaDraft.transformation(
      beforePath: _before == null ? '' : 'x',
      afterPath: _after == null ? '' : 'x',
      consentPath: _release == null ? '' : 'x',
      weeks: _weeks,
      note: westernDigits(_note.text),
      clientConsentPublic: _consent,
    ),
    MediaKind.feedback => MediaDraft.feedback(
      text: westernDigits(_text.text),
      from: westernDigits(_from.text),
    ),
    MediaKind.photo => MediaDraft.photo(
      path: _single == null ? '' : 'x',
      caption: westernDigits(_caption.text),
    ),
  };

  Future<void> _send() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _tried = true;
      _error = '';
    });
    if (_check().problems().isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final MediaDraft draft;
      switch (widget.kind) {
        case MediaKind.transformation:
          draft = MediaDraft.transformation(
            beforePath: await _upload(CoachDocFolder.transformations, _before!),
            afterPath: await _upload(CoachDocFolder.transformations, _after!),
            consentPath: await _upload(
              CoachDocFolder.transformations,
              _release!,
            ),
            weeks: _weeks,
            note: westernDigits(_note.text),
            clientConsentPublic: _consent,
          );
        case MediaKind.feedback:
          draft = MediaDraft.feedback(
            text: westernDigits(_text.text),
            from: westernDigits(_from.text),
            imagePath: _single == null
                ? null
                : await _upload(CoachDocFolder.testimonials, _single!),
          );
        case MediaKind.photo:
          draft = MediaDraft.photo(
            path: await _upload(CoachDocFolder.gallery, _single!),
            caption: westernDigits(_caption.text),
          );
      }
      await _repository.addPortfolioMedia(draft);
      if (mounted) {
        setState(() => _done = l10n.sentOwnHubChecksEveryPhotoBefore);
      }
    } on CoachingFailure catch (failure) {
      if (mounted) setState(() => _error = coachFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _picker(
    AppL10n l10n,
    String label,
    CoachImage? image,
    void Function(CoachImage) assign, {
    String error = '',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: AppText.titleS),
      const SizedBox(height: 6),
      if (image != null)
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.memory(
              image.bytes,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(height: 160),
            ),
          ),
        ),
      const SizedBox(height: 6),
      AppButton(
        image == null ? l10n.chooseAPhoto : l10n.replacePhoto,
        variant: AppButtonVariant.tonal,
        icon: Icons.photo_camera_outlined,
        onPressed: _busy ? null : () => _pick(assign),
      ),
      if (error.isNotEmpty) CoachFieldError(error),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final problems = _tried ? _check().problems() : const <String>[];
    final title = switch (widget.kind) {
      MediaKind.transformation => l10n.addATransformation,
      MediaKind.feedback => l10n.addFeedback,
      MediaKind.photo => l10n.addAPhotoOfYouOrYour,
    };
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: title,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [
        if (_done.isEmpty)
          AppButton(
            l10n.sendForOwnHubsCheck,
            onPressed:
                _busy ||
                    (widget.kind == MediaKind.transformation &&
                        (!_consent || _release == null))
                ? null
                : _send,
          ),
      ],
      children: [
        if (_done.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              _done,
              style: AppText.titleS.copyWith(color: AppColors.tertiary),
            ),
          )
        else ...[
          if (widget.kind == MediaKind.transformation) ...[
            _picker(
              l10n,
              l10n.beforePhoto,
              _before,
              (i) => _before = i,
              error: problems.contains('beforePath') ? l10n.addBothPhotos : '',
            ),
            _picker(
              l10n,
              l10n.afterPhoto,
              _after,
              (i) => _after = i,
              error: problems.contains('afterPath') ? l10n.addBothPhotos : '',
            ),
            CoachStepper(
              label: l10n.weeks,
              value: _weeks,
              min: kMediaWeeksMin,
              max: kMediaWeeksMax,
              display: countLabel(_weeks),
              onChanged: (v) => setState(() => _weeks = v),
            ),
            AppField(
              controller: _note,
              label: l10n.noteOptional_1l0x9,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            _picker(
              l10n,
              l10n.aPictureOfYourClientsWrittenAgreement,
              _release,
              (i) => _release = i,
              error: problems.contains('consentPath')
                  ? l10n.addAPictureOfYourClientsWritten
                  : '',
            ),
            CoachSwitchRow(
              title: l10n.myClientAgreedInWritingThatOwn_c2wgd,
              value: _consent,
              onChanged: _busy ? null : (v) => setState(() => _consent = v),
            ),
            if (problems.contains('clientConsentPublic'))
              CoachFieldError(l10n.tickTheBoxToSayYourClient),
          ],
          if (widget.kind == MediaKind.feedback) ...[
            AppField(
              controller: _text,
              label: l10n.whatYourClientSaid,
              maxLines: 5,
              errorText: problems.contains('text')
                  ? l10n.writeLowToHighCharacters(
                      countLabel(kMediaFeedbackMin),
                      countLabel(CoachingLimits.testimonialTextMax),
                    )
                  : '',
              onChanged: (_) => setState(() {}),
            ),
            AppField(
              controller: _from,
              label: l10n.from,
              errorText: problems.contains('from') ? l10n.writeWhoItIsFrom : '',
              onChanged: (_) => setState(() {}),
            ),
            _picker(
              l10n,
              l10n.screenshotOptional_x0klp,
              _single,
              (i) => _single = i,
            ),
          ],
          if (widget.kind == MediaKind.photo) ...[
            _picker(
              l10n,
              l10n.photo,
              _single,
              (i) => _single = i,
              error: problems.contains('path') ? l10n.addThePhotoFirst : '',
            ),
            AppField(
              controller: _caption,
              label: l10n.captionOptional,
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_error.isNotEmpty) CoachFieldError(_error),
        ],
      ],
    );
  }
}
