/// Small parts the eight steps share: the page chrome, a text field that owns
/// its controller, a chip choice, a photo slot and a repeated row's frame.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../../app_state/coach_application_draft.dart';
import '../../../../app_state/profile_photo_state.dart'
    show PhotoSource, ProfilePhotoPermissionDenied;
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_sheet.dart';
import '../../../../ui/app_step_bar.dart';
import '../coach/coach_text.dart' show westernDigits;
import 'apply_photo.dart';
import 'apply_rules.dart';

/// What the photo slots need: where to pick from and where to keep the copy.
class ApplyTools {
  const ApplyTools({
    this.picker = const SystemApplyPhotoPicker(),
    required this.store,
  });

  final ApplyPhotoPicker picker;
  final CoachPhotoStore store;
}

/// One step's page: the count, the bar, the headline and the footer.
class ApplyScaffold extends StatelessWidget {
  const ApplyScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.children,
    this.subtitle = '',
    this.onContinue,
    this.continueLabel,
    this.onBack,
    this.onClose,
    this.busy = false,
  });

  final int step;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onContinue;
  final String? continueLabel;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.countOfTotal('$step', '$kApplyStepCount'),
        onBack: onBack,
        actions: [
          if (onClose != null)
            IconButton(
              tooltip: l10n.close,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              color: AppColors.onSurfaceVariant,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
        ],
      ),
      footer: [
        if (onContinue != null)
          AppButton(
            continueLabel ?? l10n.saveAndContinue,
            height: 56,
            onPressed: busy ? null : onContinue,
          ),
        Text(
          l10n.yourAnswersAreSavedOnThisPhone,
          textAlign: TextAlign.center,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
      children: [
        AppStepBar(step: step, total: kApplyStepCount),
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppText.headline.copyWith(
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ...children,
      ],
    );
  }
}

/// A muted label above a group of chips or a field.
class ApplyLabel extends StatelessWidget {
  const ApplyLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
  );
}

/// The line under a field or a group that failed.
class ApplyErrorLine extends StatelessWidget {
  const ApplyErrorLine(this.problem, {super.key});

  final ApplyProblem? problem;

  @override
  Widget build(BuildContext context) {
    final p = problem;
    if (p == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Text(
        applyProblemText(AppL10n.of(context), p),
        style: AppText.bodyM.copyWith(color: AppColors.error),
      ),
    );
  }
}

/// A text field that keeps its own controller, starting from [initial].
class ApplyTextField extends StatefulWidget {
  const ApplyTextField({
    super.key,
    required this.initial,
    required this.label,
    required this.onChanged,
    this.helper = '',
    this.problem,
    this.maxLines = 1,
    this.numeric = false,
    this.maxLength,
  });

  final String initial;
  final String label;
  final String helper;
  final ApplyProblem? problem;
  final int? maxLines;
  final bool numeric;
  final int? maxLength;
  final ValueChanged<String> onChanged;

  @override
  State<ApplyTextField> createState() => _ApplyTextFieldState();
}

class _ApplyTextFieldState extends State<ApplyTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  /// Follows what she typed, so English in an Arabic screen keeps its
  /// punctuation on the right side.
  TextDirection? get _direction => _controller.text.trim().isEmpty
      ? null
      : (Bidi.detectRtlDirectionality(_controller.text)
            ? TextDirection.rtl
            : TextDirection.ltr);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final p = widget.problem;
    return AppField(
      controller: _controller,
      label: widget.label,
      helper: widget.helper,
      errorText: p == null ? '' : applyProblemText(l10n, p),
      maxLines: widget.maxLines,
      keyboardType: widget.numeric
          ? TextInputType.number
          : (widget.maxLines == 1
                ? TextInputType.text
                : TextInputType.multiline),
      textInputAction: widget.maxLines == 1 ? TextInputAction.next : null,
      inputFormatters: <TextInputFormatter>[
        if (widget.numeric)
          FilteringTextInputFormatter.allow(
            RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]'),
          ),
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      textDirection: widget.numeric ? TextDirection.ltr : _direction,
      onChanged: (value) {
        setState(() {});
        widget.onChanged(westernDigits(value));
      },
    );
  }
}

/// A row of chips for one or several answers. [onTap] gets the item index.
class ApplyChoice extends StatelessWidget {
  const ApplyChoice({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  final List<String> items;
  final Set<int> selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => AppChipRow(
    items: items,
    selected: selected,
    onTap: onTap,
    grow: false,
    height: 48,
  );
}

/// A framed block for one repeated row (an education, a certificate...).
class ApplyRowCard extends StatelessWidget {
  const ApplyRowCard({
    super.key,
    required this.title,
    required this.children,
    this.onRemove,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppText.titleM.copyWith(color: AppColors.onSurface),
                ),
              ),
            ),
            if (onRemove != null)
              AppButton(
                l10n.remove,
                variant: AppButtonVariant.text,
                height: 48,
                fontSize: 15,
                onPressed: onRemove,
              ),
          ],
        ),
        ...children,
      ],
    );
  }
}

/// A photo slot: shows what is there, and picks a new one from the camera or
/// her photos. [value] is the application's path or a `local:` copy.
class ApplyPhotoSlot extends StatefulWidget {
  const ApplyPhotoSlot({
    super.key,
    required this.label,
    required this.value,
    required this.tools,
    required this.onChanged,
    this.problem,
    this.optional = false,
  });

  final String label;
  final String value;
  final ApplyTools tools;
  final ApplyProblem? problem;
  final bool optional;

  /// Gets the new marker and its content type, or ('', '') when removed.
  final void Function(String marker, String contentType) onChanged;

  @override
  State<ApplyPhotoSlot> createState() => _ApplyPhotoSlotState();
}

class _ApplyPhotoSlotState extends State<ApplyPhotoSlot> {
  String? _error;
  bool _busy = false;

  Future<void> _choose() async {
    final l10n = AppL10n.of(context);
    final source = await showAppSheet<PhotoSource>(
      context: context,
      children: [
        Builder(
          builder: (sheet) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                l10n.takePhoto,
                variant: AppButtonVariant.tonal,
                onPressed: () => Navigator.of(sheet).pop(PhotoSource.camera),
              ),
              const SizedBox(height: 10),
              AppButton(
                l10n.chooseFromYourPhotos,
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(sheet).pop(PhotoSource.gallery),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
    if (source == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await widget.tools.picker.pick(source);
      if (picked == null) return;
      final marker = await widget.tools.store.save(
        picked.bytes,
        picked.contentType,
      );
      if (!mounted) return;
      widget.onChanged(marker, picked.contentType);
    } on ProfilePhotoPermissionDenied {
      if (mounted) setState(() => _error = l10n.theCameraIsBlockedAllowItIn);
    } on ApplyPhotoInvalid {
      if (mounted) {
        setState(
          () => _error = l10n.thatPhotoCouldNotBeUsedChoose(kUploadMaxMb),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = l10n.thatPhotoCouldNotBeUsedChoose(kUploadMaxMb),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final has = widget.value.isNotEmpty;
    final p = widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApplyLabel(widget.label),
        const SizedBox(height: 6),
        Row(
          children: [
            if (has) ...[
              _Thumb(value: widget.value, store: widget.tools.store),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: AppButton(
                has ? l10n.changePhoto : l10n.addAPhoto,
                variant: AppButtonVariant.outlined,
                height: 52,
                fontSize: 15,
                icon: Icons.photo_camera_outlined,
                onPressed: _busy ? null : _choose,
              ),
            ),
          ],
        ),
        if (has && widget.optional)
          AppButton(
            l10n.remove,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: () => widget.onChanged('', ''),
          ),
        if (has)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.photoAdded,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        if (p != null && !has) ApplyErrorLine(p),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.value, required this.store});

  final String value;
  final CoachPhotoStore store;

  @override
  Widget build(BuildContext context) {
    const side = 56.0;
    final frame = BoxDecoration(
      color: AppColors.surfaceHighest,
      borderRadius: BorderRadius.circular(8),
    );
    if (!isLocalCoachPhoto(value)) {
      return Container(
        width: side,
        height: side,
        decoration: frame,
        child: const Icon(Icons.check, color: AppColors.primary),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: store.read(value),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Container(
          width: side,
          height: side,
          clipBehavior: Clip.antiAlias,
          decoration: frame,
          child: bytes == null
              ? const Icon(Icons.image_outlined)
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                ),
        );
      },
    );
  }
}

/// A tick row: a switch beside a sentence, 48 high at least.
class ApplyTick extends StatelessWidget {
  const ApplyTick({
    super.key,
    required this.text,
    required this.value,
    required this.onChanged,
    this.problem,
  });

  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ApplyProblem? problem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: text,
          toggled: value,
          onTap: () => onChanged(!value),
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Box(checked: value),
                ],
              ),
            ),
          ),
        ),
        ApplyErrorLine(problem),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: checked ? AppColors.primary : Colors.transparent,
      border: Border.all(
        color: checked ? AppColors.primary : AppColors.outline,
        width: 1.6,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: checked
        ? const Icon(Icons.check, size: 20, color: AppColors.onPrimary)
        : null,
  );
}
