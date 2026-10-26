/// A sheet where a client can upload or type an InBody scan result,
/// run OCR parsing on it, adjust any field, and confirm it for her coach.
library;

import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_field.dart';
import '../../domain/inbody_scan.dart';

class InBodyScanSheet extends StatefulWidget {
  const InBodyScanSheet({
    super.key,
    this.initial,
    this.onSaved,
  });

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
      if (parsed.skeletalMuscleMassKg != null) _smm.text = '${parsed.skeletalMuscleMassKg}';
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
                    isArabic ? 'بيانات فحص InBody' : 'InBody Scan Data',
                    style: AppText.titleL.copyWith(color: AppColors.ink),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('inbody-toggle-ocr'),
                icon: const Icon(Icons.document_scanner_outlined, color: AppColors.primary),
                tooltip: isArabic ? 'مسح التقرير' : 'Paste scan text / OCR',
                onPressed: () => setState(() => _showOcrInput = !_showOcrInput),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'تساعد هذه الأرقام مدربتك في تصميم خطتك الغذائية والتدريبية المناسبة لجسمك.'
                : 'These numbers help your coach customize your nutrition and training plan.',
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
                  Text(
                    isArabic ? 'نص تقرير InBody (OCR)' : 'Paste InBody Scan Text (OCR)',
                    style: AppText.titleS,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const ValueKey('inbody-raw-text-field'),
                    controller: _rawText,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'الصق النص هنا للاستخراج التلقائي...'
                          : 'Paste OCR text here to auto-extract...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    isArabic ? 'استخراج البيانات' : 'Extract Metrics',
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
                  label: isArabic ? 'الوزن (كجم)' : 'Weight (kg)',
                  hint: '65.0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppField(
                  key: const ValueKey('inbody-height-field'),
                  controller: _height,
                  label: isArabic ? 'الطول (سم)' : 'Height (cm)',
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
                  label: isArabic ? 'كتلة العضل (كجم)' : 'Muscle SMM (kg)',
                  hint: '24.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppField(
                  key: const ValueKey('inbody-fat-field'),
                  controller: _fat,
                  label: isArabic ? 'نسبة الدهون (%)' : 'Body Fat %',
                  hint: '22.0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppField(
            key: const ValueKey('inbody-bmr-field'),
            controller: _bmr,
            label: isArabic ? 'معدل الحرق BMR (سعر)' : 'BMR (kcal)',
            hint: '1400',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppButton(
            isArabic ? 'حفظ البيانات' : 'Save Scan',
            key: const ValueKey('inbody-save-btn'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
