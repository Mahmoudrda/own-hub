// The bank of notification lines the phone picks from. Every line can land on
// a lock screen in front of anyone, so each one is checked in both languages:
// short, no numbers, no health or body words, no guilt, Egyptian Arabic that
// speaks to her as a woman, and slots the picker knows how to fill.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/notification_voice.dart';

const _path = 'assets/content/notification_lines.json';

/// Each situation and the slots its lines may use.
const _allowedSlots = <String, Set<String>>{
  // Repeats every week on her chosen days, so no slot.
  'trainingDay': {},
  'didYouTrain': {'workout'},
  'freshStart': {'workout'},
  'comeBack': {'workout'},
  'comeBackLong': {'workout'},
  'newBest': {'move'},
  'morningMeal': {'food'},
  'middayMove': {},
  'eveningMeal': {'food'},
  'weekEnd': {'workout'},
};

const _tones = ['calm', 'playful'];
const _minLinesPerTone = 10;
const _minSlotFreePerTone = 6;
const _maxLength = 110;

/// The longest real value each slot carries. In Arabic the move name stays in
/// English inside left-to-right isolate marks, which count towards the length.
const _fill = <String, Map<String, String>>{
  'en': {
    'workout': 'Glutes and legs with a long name xxxxxxx',
    'food': 'foul with eggs and bread and salad xxxxx',
    'move': 'Bulgarian split squat with dumbbells xxx',
  },
  'ar': {
    'workout': 'جلوتس ورجلين وكمان تمرين طويل الاسم كمان',
    'food': 'فول بالبيض والعيش والسلطة والطحينة كمانك',
    'move': '\u2066Bulgarian split squat with dumbbells x\u2069',
  },
};

final _slot = RegExp(r'\{(\w+)\}');
final _digits = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');
final _arabicLetter = RegExp(r'[\u0621-\u064A\u0671-\u06D3]');
final _latinLetter = RegExp(r'[A-Za-z]');
final _arabicDiacritics = RegExp(r'[\u0640\u064B-\u0652\u0670]');
final _nonArabicLetters = RegExp(r'[^\u0621-\u064A\u0671-\u06D3]+');

/// Words that speak to a man. Compared whole, with diacritics removed and
/// hamza on alef written as a bare alef, so "إنت" and "انت" are one word.
const _masculineArabic = <String>{
  'خلص',
  'جرب',
  'ابدا',
  'انت',
  'عامل',
  'كمل',
  'شوف',
  'بص',
  'ارجع',
  'حاول',
  'اتمرن',
  'تتمرن',
  'هتتمرن',
  'تعالى',
  'عايز',
  'عاوز',
  'مستعد',
  'قادر',
  'بطل',
  'حبيبي',
  'عليك',
  'ليك',
  'بيك',
  'معاك',
  'مستنيك',
  'مستنياك',
  'اتحرك',
  'قوم',
  'خد',
  'سجل',
  'ضيف',
  'اختار',
  'تقدر',
  'تحب',
};

/// Formal Arabic words an Egyptian friend would not text.
const _formalArabic = <String>{
  'هل',
  'سوف',
  'ماذا',
  'لماذا',
  'كيف',
  'هذا',
  'هذه',
  'الان',
  'ليس',
  'لن',
  'الذي',
  'التي',
  'لقد',
  'هيا',
  'لكي',
  'يجب',
  'لست',
};

/// Words that would hint at how long she has been away or what she did not do.
const _noLookingBack = <String, Map<String, List<String>>>{
  'freshStart': {
    'en': ['yesterday'],
    'ar': ['امبارح', 'إمبارح'],
  },
  'comeBack': {
    'en': [r'\bdays\b', 'week', 'while', 'long time', r'\bages\b'],
    'ar': ['أيام', 'أسبوع', 'فترة', 'زمان', 'مدة', 'غياب', 'غبتي'],
  },
  'comeBackLong': {
    'en': [r'\bdays\b', 'week', 'while', 'long time', r'\bages\b'],
    'ar': ['أيام', 'أسبوع', 'فترة', 'زمان', 'مدة', 'غياب', 'غبتي'],
  },
};

class _Line {
  _Line(this.situation, this.tone, Map<String, Object?> json)
    : id = json['id'] as String? ?? '',
      en = json['en'] as String? ?? '',
      ar = json['ar'] as String? ?? '',
      needs = [for (final n in json['needs'] as List? ?? const []) '$n'],
      keys = json.keys.toSet();

  final String situation;
  final String tone;
  final String id;
  final String en;
  final String ar;
  final List<String> needs;
  final Set<String> keys;

  String text(String language) => language == 'en' ? en : ar;

  String filled(String language) =>
      text(language)
          .replaceAllMapped(_slot, (m) => _fill[language]![m[1]] ?? m[0]!);
}

Set<String> _slotsIn(String text) => {
  for (final m in _slot.allMatches(text)) m[1]!,
};

String _withoutSlots(String text) => text.replaceAll(_slot, ' ');

String _plainArabic(String text) =>
    _withoutSlots(text).replaceAll(_arabicDiacritics, '');

List<String> _arabicWords(String text) =>
    _plainArabic(text)
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .split(_nonArabicLetters)
        .where((w) => w.isNotEmpty)
        .toList();

/// The word itself, and the word without a leading "و" or "ف".
Iterable<String> _withoutPrefix(String word) sync* {
  yield word;
  if (word.length > 2 && (word.startsWith('و') || word.startsWith('ف'))) {
    yield word.substring(1);
  }
}

int _emojiCount(String text) => text.runes
    .where((r) => r >= 0x1F000 || (r >= 0x2600 && r <= 0x27BF))
    .length;

void main() {
  final bank =
      jsonDecode(File(_path).readAsStringSync()) as Map<String, Object?>;
  final situations = bank['situations'] as Map<String, Object?>? ?? const {};
  final lines = <_Line>[
    for (final s in situations.entries)
      for (final t in (s.value as Map<String, Object?>).entries)
        for (final l in t.value as List)
          _Line(s.key, t.key, l as Map<String, Object?>),
  ];

  /// Runs [check] on every line and reports each failure with the line id.
  void expectEveryLine(String? Function(_Line line) check) {
    final failures = [
      for (final line in lines)
        if (check(line) case final String why) '${line.id}: $why',
    ];
    expect(failures, isEmpty);
  }

  test('the bank is version 1 with exactly the known situations', () {
    expect(bank.keys.toSet(), {'version', 'situations'});
    expect(bank['version'], 1);
    expect(situations.keys.toSet(), _allowedSlots.keys.toSet());
  });

  test('every situation has both tones, each with enough lines', () {
    for (final s in _allowedSlots.keys) {
      final tones = situations[s] as Map<String, Object?>;
      expect(tones.keys.toSet(), _tones.toSet(), reason: s);
      for (final t in _tones) {
        final inTone = lines.where((l) => l.situation == s && l.tone == t);
        expect(
          inTone.length,
          greaterThanOrEqualTo(_minLinesPerTone),
          reason: '$s $t',
        );
        expect(
          inTone.where((l) => l.needs.isEmpty).length,
          greaterThanOrEqualTo(_minSlotFreePerTone),
          reason: '$s $t needs lines that work without any slot',
        );
      }
    }
  });

  test('every line has an id, English, Arabic and needs, and nothing else', () {
    expectEveryLine((l) {
      if (l.keys.difference({'id', 'en', 'ar', 'needs'}).isNotEmpty ||
          !l.keys.containsAll({'id', 'en', 'ar', 'needs'})) {
        return 'keys are ${l.keys}';
      }
      if (l.en.trim().isEmpty || l.ar.trim().isEmpty) return 'empty text';
      return null;
    });
  });

  test('ids follow the situation and tone and are unique', () {
    expectEveryLine((l) {
      final pattern = RegExp('^${l.situation}-${l.tone[0]}-\\d\\d\$');
      return pattern.hasMatch(l.id) ? null : 'id does not match ${l.tone}';
    });
    final ids = lines.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('no two lines say the same thing', () {
    for (final language in ['en', 'ar']) {
      final texts = lines.map((l) => l.text(language)).toList();
      final seen = <String>{};
      expect(texts.where((t) => !seen.add(t)), isEmpty, reason: language);
    }
  });

  test('slots are allowed for the situation and listed in needs', () {
    expectEveryLine((l) {
      final en = _slotsIn(l.en);
      final ar = _slotsIn(l.ar);
      if (en.length != ar.length || !en.containsAll(ar)) {
        return 'English uses $en, Arabic uses $ar';
      }
      if (l.needs.toSet().length != l.needs.length ||
          l.needs.toSet().length != en.length ||
          !en.containsAll(l.needs)) {
        return 'needs ${l.needs} but uses $en';
      }
      final notAllowed = en.difference(_allowedSlots[l.situation]!);
      if (notAllowed.isNotEmpty) return '$notAllowed not allowed here';
      return null;
    });
  });

  test('a filled line has no braces left and fits a lock screen', () {
    expectEveryLine((l) {
      for (final language in ['en', 'ar']) {
        final filled = l.filled(language);
        if (filled.contains('{') || filled.contains('}')) {
          return '$language keeps a brace: $filled';
        }
        if (filled.length > _maxLength) {
          return '$language is ${filled.length} characters';
        }
      }
      return null;
    });
  });

  test('no digits, no long dashes and no stray spaces', () {
    expectEveryLine((l) {
      for (final language in ['en', 'ar']) {
        final text = l.text(language);
        if (_digits.hasMatch(text)) return '$language has a digit';
        if (text.contains('\u2014') || text.contains('\u2013')) {
          return '$language has a long dash';
        }
        if (text != text.trim() || text.contains('  ')) {
          return '$language has stray spaces';
        }
      }
      return null;
    });
  });

  test('English lines are English and Arabic lines are Arabic', () {
    expectEveryLine((l) {
      if (_arabicLetter.hasMatch(l.en)) return 'Arabic inside English';
      final arabic = _withoutSlots(l.ar);
      if (_latinLetter.hasMatch(arabic)) return 'Latin letters inside Arabic';
      if (!_arabicLetter.hasMatch(arabic)) return 'no Arabic in Arabic';
      if (arabic.contains('?') || arabic.contains(',')) {
        return 'Arabic uses a Latin question mark or comma';
      }
      if (l.ar.startsWith('{move}')) return 'Arabic starts with the move name';
      return null;
    });
  });

  test('no health, guilt, appearance or coach words in English', () {
    expectEveryLine((l) {
      final text = _withoutSlots(l.en);
      for (final group in kVoiceBannedEnglish.entries) {
        for (final word in group.value) {
          if (RegExp(word, caseSensitive: false).hasMatch(text)) {
            return '${group.key}: "$word"';
          }
        }
      }
      return null;
    });
  });

  test('no health, guilt, appearance or coach words in Arabic', () {
    expectEveryLine((l) {
      final text = _plainArabic(l.ar);
      for (final group in kVoiceBannedArabic.entries) {
        for (final word in group.value) {
          if (text.contains(word)) return '${group.key}: "$word"';
        }
      }
      return null;
    });
  });

  test('Arabic speaks to her as a woman, in Egyptian, not formal Arabic', () {
    expectEveryLine((l) {
      for (final word in _arabicWords(l.ar)) {
        for (final form in _withoutPrefix(word)) {
          if (_masculineArabic.contains(form)) return 'masculine "$word"';
          if (_formalArabic.contains(form)) return 'formal "$word"';
        }
      }
      return null;
    });
  });

  test('fresh starts and come backs never look back', () {
    expectEveryLine((l) {
      final rules = _noLookingBack[l.situation];
      if (rules == null) return null;
      for (final word in rules['en']!) {
        if (RegExp(word, caseSensitive: false).hasMatch(l.en)) {
          return 'English "$word"';
        }
      }
      final ar = _plainArabic(l.ar);
      for (final word in rules['ar']!) {
        if (ar.contains(word)) return 'Arabic "$word"';
      }
      return null;
    });
  });

  test('calm lines carry no emoji, playful lines at most one', () {
    expectEveryLine((l) {
      final most = l.tone == 'calm' ? 0 : 1;
      for (final language in ['en', 'ar']) {
        if (_emojiCount(l.text(language)) > most) {
          return '$language has too many emoji for ${l.tone}';
        }
      }
      return null;
    });
  });

  test('the app bundles the bank', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(
        r'^\s*-\s*assets/content/(notification_lines\.json)?\s*$',
        multiLine: true,
      ).hasMatch(pubspec),
      isTrue,
      reason: 'pubspec.yaml must list $_path or assets/content/',
    );
  });
}
