/// A sheet where a client can upload or type an InBody scan result,
/// run OCR parsing on it, adjust any field, and confirm it for her coach.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_field.dart';
import '../../domain/inbody_scan.dart';

class InBodyScanSheet extends StatefulWidget {
  const InBodyScanSheet({super.key, this.initial, this.onSaved});

  final InBodyScan? initial;
  final ValueChanged<InBodyScan>? onSaved;

  @override
  State<InBodyScanSheet> createState() => _InBodyScanSheetState();
}

class _InBodyScanSheetState extends State<InBodyScanSheet> {
  late final TextEditingController _weight = TextEditingController(
    text: widget.initial?.weightKg != null ? '${widget.initial!.weightKg}' : '',
  );
  late final TextEditingController _smm = TextEditingController(
    text: widget.initial?.skeletalMuscleMassKg != null
        ? '${widget.initial!.skeletalMuscleMassKg}'
        : '',
  );
  late final TextEditingController _fat = TextEditingController(
    text: widget.initial?.bodyFatPercent != null
        ? '${widget.initial!.bodyFatPercent}'
        : '',
  );
  late final TextEditingController _bmr = TextEditingController(
    text: widget.initial?.bmrKcal != null ? '${widget.initial!.bmrKcal}' : '',
  );
  late final TextEditingController _height = TextEditingController(
    text: widget.initial?.heightCm != null ? '${widget.initial!.heightCm}' : '',
  );
  final TextEditingController _rawText = TextEditingController();

  bool _showOcrInput = false;

  @override
  void dispose() {
    _weight.dispose();
    _smm.dispose();
    _fat.dispose();
    _bmr.dispose();
    _height.dispose();
    _rawText.dispose();
    super.dispose();
  }

  void _runOcr() {
    final parsed = InBodyOcrParser.parse(_rawText.text);
    setState(() {
      if (parsed.weightKg != null) _weight.text = '${parsed.weightKg}';
      if (parsed.skeletalMuscleMassKg != null) {
        _smm.text = '${parsed.skeletalMuscleMassKg}';
      }
      if (parsed.bodyFatPercent != null) _fat.text = '${parsed.bodyFatPercent}';
      if (parsed.bmrKcal != null) _bmr.text = '${parsed.bmrKcal}';
      if (parsed.heightCm != null) _height.text = '${parsed.heightCm}';
      _showOcrInput = false;
    });
  }

  void _save() {
    final scan = InBodyScan(
      weightKg: double.tryParse(_weight.text.trim()),
      skeletalMuscleMassKg: double.tryParse(_smm.text.trim()),
      bodyFatPercent: double.tryParse(_fat.text.trim()),
      bmrKcal: int.tryParse(_bmr.text.trim()),
      heightCm: double.tryParse(_height.text.trim()),
      scanDate: DateTime.now(),
      rawText: _rawText.text.trim(),
    );
    widget.onSaved?.call(scan);
    Navigator.of(context).maybePop(scan);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.inbodyScanData,
                    style: AppText.titleL.copyWith(color: AppColors.ink),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('inbody-toggle-ocr'),
                icon: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.primary,
                ),
                tooltip: l10n.pasteScanTextOcr,
                onPressed: () => setState(() => _showOcrInput = !_showOcrInput),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.theseNumbersHelpYourCoachCustomizeYour,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_showOcrInput) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.pasteInbodyScanTextOcr, style: AppText.titleS),
                  const SizedBox(height: 6),
                  TextField(
                    key: const ValueKey('inbody-raw-text-field'),
                    controller: _rawText,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.pasteOcrTextHereToAutoExtract,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    l10n.extractMetrics,
                    key: const ValueKey('inbody-extract-btn'),
                    variant: AppButtonVariant.outlined,
                    onPressed: _runOcr,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: AppField(
                  key: const ValueKey('inbody-weight-field'),
                  controller: _weight,
                  label: l10n.weightKg_4v662,
                  hint: '65.0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppField(
                  key: const ValueKey('inbody-height-field'),
                  controller: _height,
                  label: l10n.heightCm,
                  hint: '165',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppField(
                  key: const ValueKey('inbody-smm-field'),
                  controller: _smm,
                  label: l10n.muscleSmmKg,
                  hint: '24.5',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppField(
                  key: const ValueKey('inbody-fat-field'),
                  controller: _fat,
                  label: l10n.bodyFat,
                  hint: '22.0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppField(
            key: const ValueKey('inbody-bmr-field'),
            controller: _bmr,
            label: l10n.bmrKcal,
            hint: '1400',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppButton(
            l10n.saveScan,
            key: const ValueKey('inbody-save-btn'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
