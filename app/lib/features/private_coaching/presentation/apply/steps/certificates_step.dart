import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../../../ui/app_button.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// A certificate id: lower case letters, digits and dashes, unique.
String newCertificateId() {
  final r = Random.secure();
  return 'c-${List<String>.generate(10, (_) => '0123456789abcdef'[r.nextInt(16)]).join()}';
}

/// Step 3: certificates, 1 to 10, each with a photo.
class CertificatesStep extends StatefulWidget {
  const CertificatesStep({
    super.key,
    required this.app,
    required this.problems,
    required this.tools,
    required this.onChanged,
  });

  final CoachApplication app;
  final ApplyProblems problems;
  final ApplyTools tools;
  final ValueChanged<CoachApplication> onChanged;

  @override
  State<CertificatesStep> createState() => _CertificatesStepState();
}

class _CertificatesStepState extends State<CertificatesStep> {
  late final List<Key> _keys = [
    for (final _ in widget.app.certificates) UniqueKey(),
  ];

  List<CoachCertificate> get _rows => widget.app.certificates;

  void _emit(List<CoachCertificate> rows) =>
      widget.onChanged(widget.app.copyWith(certificates: rows));

  CoachCertificate _with(
    CoachCertificate c, {
    String? title,
    String? issuer,
    int? year,
    bool clearYear = false,
    String? path,
    String? mime,
  }) => CoachCertificate(
    id: c.id,
    title: title ?? c.title,
    issuer: issuer ?? c.issuer,
    year: clearYear ? null : (year ?? c.year),
    path: path ?? c.path,
    mime: mime ?? c.mime,
  );

  void _edit(int i, CoachCertificate row) =>
      _emit(List<CoachCertificate>.of(_rows)..[i] = row);

  void _add() {
    _keys.add(UniqueKey());
    _emit([..._rows, CoachCertificate(id: newCertificateId())]);
  }

  void _remove(int i) {
    _keys.removeAt(i);
    _emit(List<CoachCertificate>.of(_rows)..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final problems = widget.problems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        for (var i = 0; i < _rows.length; i++)
          ApplyRowCard(
            key: _keys[i],
            title: l10n.certificateN('${i + 1}'),
            onRemove: _rows.length > CoachingLimits.certificatesMin
                ? () => _remove(i)
                : null,
            children: [
              ApplyTextField(
                initial: _rows[i].title,
                label: l10n.certificateTitle,
                problem: problems['certificates.$i.title'],
                maxLength: 80,
                onChanged: (v) => _edit(i, _with(_rows[i], title: v)),
              ),
              ApplyTextField(
                initial: _rows[i].issuer,
                label: l10n.issuedBy,
                problem: problems['certificates.$i.issuer'],
                maxLength: 80,
                onChanged: (v) => _edit(i, _with(_rows[i], issuer: v)),
              ),
              ApplyTextField(
                initial: _rows[i].year?.toString() ?? '',
                label: l10n.year,
                numeric: true,
                maxLength: 4,
                problem: problems['certificates.$i.year'],
                onChanged: (v) {
                  final y = parseApplyInt(v);
                  _edit(i, _with(_rows[i], year: y, clearYear: y == null));
                },
              ),
              ApplyPhotoSlot(
                label: l10n.certificatePhoto,
                value: _rows[i].path,
                tools: widget.tools,
                problem: problems['certificates.$i.photo'],
                onChanged: (marker, type) =>
                    _edit(i, _with(_rows[i], path: marker, mime: type)),
              ),
            ],
          ),
        ApplyErrorLine(problems['certificates']),
        if (_rows.length < CoachingLimits.certificatesMax)
          AppButton(
            l10n.addACertificate,
            variant: AppButtonVariant.outlined,
            height: 52,
            fontSize: 15,
            icon: Icons.add,
            onPressed: _add,
          ),
      ],
    );
  }
}
