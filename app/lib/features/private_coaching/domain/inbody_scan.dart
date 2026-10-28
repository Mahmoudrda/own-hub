/// The numbers on an InBody result sheet, and the reader that finds them in
/// the text a phone's text recognition returns.
///
/// Nothing here is used until she has checked each number on the confirm
/// screen. The reader anchors every number to its label, converts pounds,
/// checks the sheet against itself (BMI, fat mass, fat-free mass) and says
/// what it is unsure of. It never keeps the text it read, and the model has
/// no field for it.
library;

import 'parse.dart';

/// The fields of the form, in the order she sees them.
enum InBodyField { weight, height, bodyFat, muscle, bmr }

/// What the reader noticed about a sheet. None of them changes a number
/// without saying so; each one is shown to her.
enum InBodyCheck {
  /// The weight was printed in pounds and has been converted.
  weightFromPounds,

  /// Weight, height and the printed BMI do not agree.
  bmiDisagrees,

  /// Weight, fat mass, body fat and fat-free mass do not agree.
  compositionDisagrees,
}

/// The accepted range of each number. The server holds the same ones
/// (`documents.subscription.inbody` in the coaching contract, which a test
/// reads), so a number the form lets through is one the server accepts.
abstract final class InBodyRanges {
  static const Map<InBodyField, ({double low, double high})> of = {
    InBodyField.weight: (low: 30, high: 250),
    InBodyField.height: (low: 120, high: 230),
    InBodyField.bodyFat: (low: 5, high: 65),
    InBodyField.muscle: (low: 10, high: 80),
    InBodyField.bmr: (low: 800, high: 3500),
  };

  static bool contains(InBodyField field, double value) {
    final range = of[field]!;
    return value.isFinite && value >= range.low && value <= range.high;
  }
}

/// What she confirmed. Any field may be missing.
class InBodyScan {
  const InBodyScan({
    this.weightKg,
    this.heightCm,
    this.bodyFatPercent,
    this.skeletalMuscleMassKg,
    this.bmrKcal,
  });

  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPercent;
  final double? skeletalMuscleMassKg;
  final int? bmrKcal;

  bool get isEmpty =>
      weightKg == null &&
      heightCm == null &&
      bodyFatPercent == null &&
      skeletalMuscleMassKg == null &&
      bmrKcal == null;

  bool get isNotEmpty => !isEmpty;

  Map<String, Object> toJson() => <String, Object>{
    'weightKg': ?weightKg,
    'heightCm': ?heightCm,
    'bodyFatPercent': ?bodyFatPercent,
    'skeletalMuscleMassKg': ?skeletalMuscleMassKg,
    'bmrKcal': ?bmrKcal,
  };

  /// A stored scan. A wrong type or a number outside its range reads as
  /// missing, so a hand-edited document never reaches a target.
  factory InBodyScan.fromJson(Json map) {
    double? number(String key, InBodyField field) {
      final raw = map[key];
      if (raw is! num) return null;
      final value = raw.toDouble();
      return InBodyRanges.contains(field, value) ? value : null;
    }

    return InBodyScan(
      weightKg: number('weightKg', InBodyField.weight),
      heightCm: number('heightCm', InBodyField.height),
      bodyFatPercent: number('bodyFatPercent', InBodyField.bodyFat),
      skeletalMuscleMassKg: number('skeletalMuscleMassKg', InBodyField.muscle),
      bmrKcal: number('bmrKcal', InBodyField.bmr)?.round(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InBodyScan &&
      other.weightKg == weightKg &&
      other.heightCm == heightCm &&
      other.bodyFatPercent == bodyFatPercent &&
      other.skeletalMuscleMassKg == skeletalMuscleMassKg &&
      other.bmrKcal == bmrKcal;

  @override
  int get hashCode => Object.hash(
    weightKg,
    heightCm,
    bodyFatPercent,
    skeletalMuscleMassKg,
    bmrKcal,
  );
}

/// What the reader found: the numbers, and what to look at twice.
class InBodyReading {
  const InBodyReading(this.scan, [this.checks = const <InBodyCheck>{}]);

  static const InBodyReading none = InBodyReading(InBodyScan());

  final InBodyScan scan;
  final Set<InBodyCheck> checks;

  /// The form fields the checks point at.
  Set<InBodyField> get fieldsToCheck => {
    if (checks.contains(InBodyCheck.bmiDisagrees)) ...{
      InBodyField.weight,
      InBodyField.height,
    },
    if (checks.contains(InBodyCheck.compositionDisagrees)) ...{
      InBodyField.weight,
      InBodyField.bodyFat,
    },
  };
}

enum _Kind {
  weight,
  height,
  bodyFat,
  muscle,
  bmr,
  bmi,
  fatMass,
  leanMass,
  skip,
}

class _Label {
  const _Label(this.kind, this.pattern);

  final _Kind kind;
  final String pattern;
}

class _Span {
  const _Span(this.kind, this.start, this.end);

  final _Kind kind;
  final int start;
  final int end;
}

class _Number {
  const _Number(this.value, this.unit);

  final double value;
  final String unit;
}

/// One line of text from text recognition, with its box in the picture.
class InBodyLine {
  const InBodyLine(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get _middle => (top + bottom) / 2;
}

/// Reads the text of a result sheet.
///
/// The Arabic labels are matching data for input a printout may carry; the
/// words shown to her all come from `AppL10n`.
abstract final class InBodyReader {
  static const List<_Label> _labels = [
    _Label(_Kind.fatMass, r'body fat mass|fat mass|كتلة الدهون'),
    _Label(
      _Kind.bodyFat,
      r'percent body fat|percentage body fat|body fat percentage|body fat %|'
      r'fat percent|fat %|pbf|body fat|نسبة الدهون',
    ),
    _Label(
      _Kind.leanMass,
      r'fat[ -]?free mass|lean body mass|ffm|lbm|الكتلة الخالية من الدهون',
    ),
    _Label(
      _Kind.muscle,
      r'skeletal muscle mass|skeletal muscle|smm|كتلة العضلات الهيكلية|كتلة العضل',
    ),
    _Label(
      _Kind.bmr,
      r'basal metabolic rate|bmr|معدل الأيض الأساسي|معدل الحرق|الأيض الأساسي',
    ),
    _Label(_Kind.bmi, r'body mass index|bmi|مؤشر كتلة الجسم'),
    _Label(_Kind.height, r'height|الطول'),
    _Label(_Kind.weight, r'weight|الوزن'),
    _Label(
      _Kind.skip,
      r'ideal|target|control|goal|normal|range|المثالي|المستهدف|الهدف|الطبيعي',
    ),
  ];

  static final RegExp _all = RegExp(
    _labels.map((l) => '(${l.pattern})').join('|'),
    caseSensitive: false,
  );

  static final RegExp _number = RegExp(
    r'(?<![\d.,])(\d{1,4}(?:[.,]\d{1,3})?)(?!\d)\s*'
    r'(kgs?|lbs?|cm|kcal|cal|%|كجم|كيلو|رطل|سم|سعرة|سعر)?',
    caseSensitive: false,
  );

  static const int _axisTicks = 4;

  /// The digits of [text] folded onto `0`-`9`, with the Arabic decimal and
  /// thousands marks folded onto `.` and `,`.
  static String fold(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x066B) {
        out.write('.');
      } else if (rune == 0x066C) {
        out.write(',');
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// The labels on [line], left to right. A label touching "ideal", "target",
  /// "control" or "normal range" names another row ("Target Weight", "Weight
  /// Control"), so it is marked to be skipped.
  /// [lines] as the rows a person reads: boxes at the same height join into
  /// one row, left to right, so a label and the value printed beside it
  /// arrive together.
  static String rows(List<InBodyLine> lines) {
    final sorted = [...lines]..sort((a, b) => a._middle.compareTo(b._middle));
    final grouped = <List<InBodyLine>>[];
    for (final line in sorted) {
      if (grouped.isNotEmpty && _sameRow(grouped.last.first, line)) {
        grouped.last.add(line);
      } else {
        grouped.add([line]);
      }
    }
    return grouped
        .map((row) {
          row.sort((a, b) => a.left.compareTo(b.left));
          return row.map((l) => l.text.trim()).join('  ');
        })
        .join('\n');
  }

  static bool _sameRow(InBodyLine first, InBodyLine line) {
    final overlap =
        (first.bottom < line.bottom ? first.bottom : line.bottom) -
        (first.top > line.top ? first.top : line.top);
    final smaller = (first.bottom - first.top) < (line.bottom - line.top)
        ? first.bottom - first.top
        : line.bottom - line.top;
    return smaller > 0 && overlap >= smaller * 0.5;
  }

  static List<_Span> _spans(String line) {
    final raw = <_Span>[];
    for (final m in _all.allMatches(line.toLowerCase())) {
      var kind = _Kind.skip;
      for (var i = 0; i < _labels.length; i++) {
        if (m.group(i + 1) != null) kind = _labels[i].kind;
      }
      raw.add(_Span(kind, m.start, m.end));
    }
    bool touching(int a, int b) => raw[b].start - raw[a].end <= 2;
    return [
      for (var i = 0; i < raw.length; i++)
        raw[i].kind != _Kind.skip &&
                ((i > 0 &&
                        raw[i - 1].kind == _Kind.skip &&
                        touching(i - 1, i)) ||
                    (i + 1 < raw.length &&
                        raw[i + 1].kind == _Kind.skip &&
                        touching(i, i + 1)))
            ? _Span(_Kind.skip, raw[i].start, raw[i].end)
            : raw[i],
    ];
  }

  static List<_Number> _numbers(String region) => [
    for (final m in _number.allMatches(region))
      ?_parse(m.group(1)!, (m.group(2) ?? '').toLowerCase()),
  ];

  static _Number? _parse(String raw, String unit) {
    final decimal = double.tryParse(raw.replaceAll(',', '.'));
    final thousands = RegExp(r'^\d{1,2},\d{3}$').hasMatch(raw)
        ? double.tryParse(raw.replaceAll(',', ''))
        : null;
    final value = decimal ?? thousands;
    if (value == null) return null;
    return _Number(
      // 1,340 is a metabolic rate, 64,5 is a weight.
      thousands != null && InBodyRanges.contains(InBodyField.bmr, thousands)
          ? thousands
          : value,
      unit,
    );
  }

  /// The first number in [numbers] that [kind] accepts, converted. Sets
  /// [pounds] when a weight was converted.
  static double? _pick(
    _Kind kind,
    List<_Number> numbers,
    void Function() pounds,
  ) {
    for (final n in numbers) {
      final unit = switch (n.unit) {
        'kgs' || 'كجم' || 'كيلو' => 'kg',
        'lbs' || 'رطل' => 'lb',
        'سم' => 'cm',
        'cal' || 'سعر' || 'سعرة' => 'kcal',
        final u => u,
      };
      double? value;
      switch (kind) {
        case _Kind.weight:
          if (unit == 'lb') {
            value = double.parse((n.value / 2.20462).toStringAsFixed(1));
            if (InBodyRanges.contains(InBodyField.weight, value)) pounds();
          } else if (unit.isEmpty || unit == 'kg') {
            value = n.value;
          }
          if (value != null &&
              !InBodyRanges.contains(InBodyField.weight, value)) {
            value = null;
          }
        case _Kind.height:
          if (unit.isEmpty || unit == 'cm') value = n.value;
          if (value != null &&
              !InBodyRanges.contains(InBodyField.height, value)) {
            value = null;
          }
        case _Kind.bodyFat:
          if (unit.isEmpty || unit == '%') value = n.value;
          if (value != null &&
              !InBodyRanges.contains(InBodyField.bodyFat, value)) {
            value = null;
          }
        case _Kind.muscle:
          if (unit.isEmpty || unit == 'kg') value = n.value;
          if (value != null &&
              !InBodyRanges.contains(InBodyField.muscle, value)) {
            value = null;
          }
        case _Kind.bmr:
          if (unit.isEmpty || unit == 'kcal') value = n.value;
          if (value != null && !InBodyRanges.contains(InBodyField.bmr, value)) {
            value = null;
          }
        case _Kind.bmi:
          if (n.value >= 10 && n.value <= 60) value = n.value;
        case _Kind.fatMass:
          if ((unit.isEmpty || unit == 'kg') &&
              n.value >= 2 &&
              n.value <= 120) {
            value = n.value;
          }
        case _Kind.leanMass:
          if ((unit.isEmpty || unit == 'kg') &&
              n.value >= 20 &&
              n.value <= 150) {
            value = n.value;
          }
        case _Kind.skip:
          break;
      }
      if (value != null) return value;
    }
    return null;
  }

  static InBodyReading read(String text) {
    final rows = <String>[
      for (final line in fold(text).split(RegExp(r'[\r\n]+')))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final spans = [for (final row in rows) _spans(row)];
    final found = <_Kind, double>{};
    var fromPounds = false;
    void pounds() => fromPounds = true;

    bool isValueRow(int i) =>
        i >= 0 &&
        i < rows.length &&
        spans[i].isEmpty &&
        _numbers(rows[i]).isNotEmpty &&
        _numbers(rows[i]).length < _axisTicks;

    // A label with a number after it on its own line.
    final lonely = <(int, _Span)>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final here = spans[i];
      for (var j = 0; j < here.length; j++) {
        final span = here[j];
        if (span.kind == _Kind.skip) continue;
        final end = j + 1 < here.length ? here[j + 1].start : row.length;
        final numbers = _numbers(row.substring(span.end, end));
        if (found.containsKey(span.kind)) continue;
        if (numbers.isEmpty || numbers.length >= _axisTicks) {
          if (here.where((s) => s.kind != _Kind.skip).length == 1) {
            lonely.add((i, span));
          }
          continue;
        }
        final value = _pick(span.kind, numbers, pounds);
        if (value != null) found[span.kind] = value;
      }
    }

    // A label with its number on the row below, or above. The direction that
    // fits more labels is the sheet's; a row feeds one label only.
    if (lonely.isNotEmpty) {
      final below = lonely.where((l) => isValueRow(l.$1 + 1)).length;
      final above = lonely.where((l) => isValueRow(l.$1 - 1)).length;
      final step = below >= above ? 1 : -1;
      final used = <int>{};
      for (final (i, span) in lonely) {
        final at = i + step;
        if (found.containsKey(span.kind) ||
            used.contains(at) ||
            !isValueRow(at)) {
          continue;
        }
        final value = _pick(span.kind, _numbers(rows[at]), pounds);
        if (value != null) {
          found[span.kind] = value;
          used.add(at);
        }
      }
    }

    // A sheet with none of the InBody-only figures is some other page.
    const anchors = {
      _Kind.bodyFat,
      _Kind.muscle,
      _Kind.bmr,
      _Kind.fatMass,
      _Kind.leanMass,
    };
    if (!found.keys.any(anchors.contains)) return InBodyReading.none;

    final weight = found[_Kind.weight];
    final height = found[_Kind.height];
    final bodyFat = found[_Kind.bodyFat];
    final fatMass = found[_Kind.fatMass];
    final leanMass = found[_Kind.leanMass];
    final bmi = found[_Kind.bmi];
    final checks = <InBodyCheck>{
      if (fromPounds) InBodyCheck.weightFromPounds,
      if (weight != null &&
          height != null &&
          bmi != null &&
          (weight / ((height / 100) * (height / 100)) - bmi).abs() > 1.2)
        InBodyCheck.bmiDisagrees,
      if ((weight != null &&
              fatMass != null &&
              bodyFat != null &&
              (fatMass - weight * bodyFat / 100).abs() >
                  (fatMass * 0.1 < 1.2 ? 1.2 : fatMass * 0.1)) ||
          (weight != null &&
              fatMass != null &&
              leanMass != null &&
              (weight - fatMass - leanMass).abs() > 1.5))
        InBodyCheck.compositionDisagrees,
    };

    return InBodyReading(
      InBodyScan(
        weightKg: weight,
        heightCm: height,
        bodyFatPercent: bodyFat,
        skeletalMuscleMassKg: found[_Kind.muscle],
        bmrKcal: found[_Kind.bmr]?.round(),
      ),
      checks,
    );
  }
}
