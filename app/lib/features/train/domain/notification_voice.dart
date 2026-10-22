/// The words of a reminder, picked on the phone.
///
/// A bank of short lines is written ahead of time in two tones, calm and
/// playful. This file only chooses among them: nothing is generated and
/// nothing leaves the phone. The choice follows what she has done in the app:
/// which tone she opens more, which line she has not seen lately, and the
/// small facts a line may name (her next session, a food she logs, a move she
/// just improved).
///
/// Pure: the bank is parsed from a string and the history is passed in, so
/// every rule is tested without a phone.
library;

import 'dart:convert';

import '../../../domain/format/day_key.dart';

const String kToneCalm = 'calm';
const String kTonePlayful = 'playful';

/// A line is not shown again within this many days either side of its date.
const int kVoiceRepeatDays = 14;

/// Every this-many-th pick tries the tone she opens less, so a tone she never
/// saw can still win her over.
const int kVoiceExploreEvery = 5;

const int kVoiceSentKept = 120;
const int kVoiceScheduledKept = 64;

/// Left-to-right isolates, so an English name keeps its order inside an
/// Arabic sentence.
final String _isolateStart = String.fromCharCode(0x2066);
final String _isolateEnd = String.fromCharCode(0x2069);

final RegExp _arabicLetter = RegExp(r'[؀-ۿ]');
final RegExp _placeholder = RegExp(r'\{(\w+)\}');

/// One line in the bank.
class VoiceLine {
  const VoiceLine({
    required this.id,
    required this.en,
    required this.ar,
    this.needs = const <String>[],
  });

  final String id;
  final String en;
  final String ar;

  /// The slots (`workout`, `food`, `move`) the line names.
  final List<String> needs;

  String textFor(String locale) => locale == 'ar' ? ar : en;
}

/// What she opened of one tone, against what was sent.
class ToneStat {
  ToneStat({this.sent = 0, this.taps = 0});

  int sent;
  int taps;

  /// A tone nobody has tried scores the same as any other, and the score
  /// moves a little with each send and each tap.
  double get score => (taps + 1) / (sent + 2);
}

/// A notification the phone scheduled: which line it carries, so a tap on it
/// can be told apart later. The payload of the notification never says.
class ScheduledLine {
  const ScheduledLine({
    required this.lineId,
    required this.tone,
    required this.at,
  });

  final String lineId;
  final String tone;
  final DateTime at;
}

/// What the phone remembers of the words it has used. Phone only.
class VoiceHistory {
  VoiceHistory();

  static final VoiceHistory instance = VoiceHistory();

  /// Line id to the day it was last scheduled for.
  final Map<String, String> sent = <String, String>{};

  final Map<String, ToneStat> toneStats = <String, ToneStat>{};

  /// Notification id to what it carries.
  final Map<int, ScheduledLine> scheduled = <int, ScheduledLine>{};

  bool get touched =>
      sent.isNotEmpty || toneStats.isNotEmpty || scheduled.isNotEmpty;

  double scoreOf(String tone) => (toneStats[tone] ?? ToneStat()).score;

  /// Whether [lineId] was scheduled for a day within [kVoiceRepeatDays] of
  /// [on].
  bool usedNear(String lineId, DateTime on) {
    final key = sent[lineId];
    final day = key == null ? null : DateTime.tryParse(key);
    if (day == null) return false;
    final mid = DateTime(on.year, on.month, on.day);
    return day.difference(mid).inDays.abs() < kVoiceRepeatDays;
  }

  /// Notes that notification [id] will show [lineId] at [at].
  ///
  /// A line counts as sent once per notification id and date. The same line
  /// on the same day again (a replan) changes nothing. A different line for
  /// an id whose earlier one has not shown yet takes that one's place, so it
  /// is not counted twice.
  void schedule({
    required int id,
    required String lineId,
    required String tone,
    required DateTime at,
    required DateTime now,
  }) {
    final prev = scheduled[id];
    if (prev != null && prev.lineId == lineId && _sameDay(prev.at, at)) {
      scheduled[id] = ScheduledLine(lineId: lineId, tone: tone, at: at);
      return;
    }
    if (prev != null) _refund(prev, now);
    (toneStats[tone] ??= ToneStat()).sent++;
    sent[lineId] = dayKey(at);
    scheduled[id] = ScheduledLine(lineId: lineId, tone: tone, at: at);
    _trim();
  }

  /// Notification [id] is no longer going to show: what it was counted for
  /// is given back, unless it has already shown.
  void cancel(int id, DateTime now) {
    final prev = scheduled[id];
    // One already shown stays, so a later tap from the notification centre
    // still counts; the cap trims it in time.
    if (prev == null || !prev.at.isAfter(now)) return;
    _refund(prev, now);
    scheduled.remove(id);
  }

  void _refund(ScheduledLine prev, DateTime now) {
    if (!prev.at.isAfter(now)) return;
    final stat = toneStats[prev.tone];
    if (stat != null && stat.sent > 0) stat.sent--;
    if (sent[prev.lineId] == dayKey(prev.at)) sent.remove(prev.lineId);
  }

  /// A tap on notification [id]. False when it carries none of ours.
  bool tap(int id) {
    final line = scheduled[id];
    if (line == null) return false;
    (toneStats[line.tone] ??= ToneStat()).taps++;
    return true;
  }

  void _trim() {
    if (sent.length > kVoiceSentKept) {
      final oldest = sent.entries.toList()
        ..sort((a, b) {
          final byDay = a.value.compareTo(b.value);
          return byDay != 0 ? byDay : a.key.compareTo(b.key);
        });
      for (final e in oldest.take(sent.length - kVoiceSentKept)) {
        sent.remove(e.key);
      }
    }
    if (scheduled.length > kVoiceScheduledKept) {
      final oldest = scheduled.entries.toList()
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      for (final e in oldest.take(scheduled.length - kVoiceScheduledKept)) {
        scheduled.remove(e.key);
      }
    }
  }

  VoiceHistory copy() => VoiceHistory()..adopt(this);

  /// Becomes a copy of [other].
  void adopt(VoiceHistory other) {
    restore(
      sent: other.sent,
      toneStats: {
        for (final e in other.toneStats.entries)
          e.key: ToneStat(sent: e.value.sent, taps: e.value.taps),
      },
      scheduled: other.scheduled,
    );
  }

  /// Puts back what the snapshot held.
  void restore({
    Map<String, String> sent = const <String, String>{},
    Map<String, ToneStat> toneStats = const <String, ToneStat>{},
    Map<int, ScheduledLine> scheduled = const <int, ScheduledLine>{},
  }) {
    this.sent
      ..clear()
      ..addAll(sent);
    this.toneStats
      ..clear()
      ..addAll(toneStats);
    this.scheduled
      ..clear()
      ..addAll(scheduled);
    _trim();
  }

  /// Account deletion, sign-out and tests.
  void reset() => restore();

  Map<String, Object?> toJson() => <String, Object?>{
    'sent': sent,
    'toneStats': {
      for (final e in toneStats.entries)
        e.key: <String, Object?>{'sent': e.value.sent, 'taps': e.value.taps},
    },
    'scheduled': {
      for (final e in scheduled.entries)
        '${e.key}': <String, Object?>{
          'lineId': e.value.lineId,
          'tone': e.value.tone,
          'at': e.value.at.toIso8601String(),
        },
    },
  };
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// What the phone knows that a reminder may use, and that decides whether
/// some of them are sent at all. All of it is read on the phone.
class NotificationFacts {
  const NotificationFacts({
    this.locale = 'en',
    this.slots = const <String, String>{},
    this.protectedStage = false,
    this.severeToday = false,
    this.lastBestAt,
  });

  /// `en` or `ar`.
  final String locale;

  /// `workout`, `food` and `move`, where she has a value for them.
  final Map<String, String> slots;

  /// Pregnant or postpartum: calm lines only.
  final bool protectedStage;

  /// Today's check-in is a severe day.
  final bool severeToday;

  /// The day of the last session that beat one of her bests.
  final DateTime? lastBestAt;
}

/// The longest slot value a line may carry, so a filled line stays short.
const int kVoiceSlotMaxLength = 40;

final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);

/// English words that never go on a lock screen, in a line or in a value
/// filled into one. Matched case-insensitively anywhere
/// in the line, so "body" also blocks "somebody".
const Map<String, List<String>> kVoiceBannedEnglish = {
  'health or medical': [
    'weight',
    'kg',
    'kilo',
    'calorie',
    'kcal',
    'cycle',
    'period',
    'pregnan',
    'diet',
    'fat',
    'bmi',
    'sick',
    'pain',
    'injur',
    'body',
    'health',
    'heal',
    'medic',
    'bleed',
    'cure',
    'detox',
    'immun',
    'metabol',
    'hormone',
    'doctor',
    'therap',
    'symptom',
  ],
  'guilt or pressure': [
    'miss',
    'skip',
    'fail',
    'lazy',
    'streak',
    'behind',
    'should have',
    "should've",
    'give up',
    'excuse',
    'last chance',
    'disappoint',
    'guilt',
    'shame',
    r'\bmust\b',
  ],
  'appearance': [
    'burn',
    'tone up',
    'toned',
    'slim',
    'skinny',
    'bikini',
    'belly',
    'thigh',
    'beach',
    r'\blos(e|ing)\b',
    r'\bshed\b',
    'in shape',
  ],
  'the coach': ['rahma'],
};

/// Arabic fragments that never go on a lock screen, matched anywhere after the
/// diacritics are removed.
const Map<String, List<String>> kVoiceBannedArabic = {
  'health or medical': [
    'وزن',
    'كيلو',
    'سعرات',
    'كالوري',
    'دورة',
    'بريود',
    'حامل',
    'حمل',
    'رجيم',
    'ريجيم',
    'دايت',
    'دهون',
    'تخسيس',
    'تعبان',
    'ألم',
    'آلام',
    'إصابة',
    'اصابة',
    'جسم',
    'صحة',
    'صحية',
    'نزيف',
    'مناعة',
    'علاج',
    'هرمون',
    'دكتور',
    'مرض',
  ],
  'guilt or pressure': [
    'فوتي',
    'فاتك',
    'فاتتك',
    'كسل',
    'متأخر',
    'اتأخرتي',
    'لازم',
    'تستسلمي',
    'آخر فرصة',
    'زعلان',
    'عيب',
    'وحشتي',
    'قصرتي',
    'مقصرة',
    'ستريك',
    'ذنب',
  ],
  'appearance': [
    'تنحفي',
    'نحيفة',
    'كرش',
    'تخسي',
    'رشاقة',
    'رشيقة',
    'بطن',
    'سمنة',
    'تخينة',
    'حرق',
    'بيكيني',
  ],
  'the coach': ['رحمة'],
};

final RegExp _arabicMarks = RegExp('[\u0640\u064B-\u0652\u0670]');

/// The first word of [kVoiceBannedEnglish] or [kVoiceBannedArabic] that
/// [text] holds, or null when it holds none.
String? voiceBannedWord(String text) {
  for (final words in kVoiceBannedEnglish.values) {
    for (final word in words) {
      if (RegExp(word, caseSensitive: false).hasMatch(text)) return word;
    }
  }
  final plain = text.replaceAll(_arabicMarks, '');
  for (final words in kVoiceBannedArabic.values) {
    for (final word in words) {
      if (plain.contains(word)) return word;
    }
  }
  return null;
}

/// The bank and the rule for choosing from it.
class NotificationVoice {
  const NotificationVoice(this._lines);

  /// A bank with nothing in it: every pick is null and the plain texts stay.
  static const NotificationVoice empty = NotificationVoice(
    <String, Map<String, List<VoiceLine>>>{},
  );

  /// The bank in [source]. A missing or malformed bank, or a malformed line,
  /// costs that part and never throws.
  factory NotificationVoice.parse(String? source) {
    if (source == null) return empty;
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return empty;
    }
    final situations = decoded is Map ? decoded['situations'] : null;
    if (situations is! Map) return empty;
    final out = <String, Map<String, List<VoiceLine>>>{};
    for (final entry in situations.entries) {
      final tones = entry.value;
      if (entry.key is! String || tones is! Map) continue;
      final byTone = <String, List<VoiceLine>>{};
      for (final tone in const [kToneCalm, kTonePlayful]) {
        final raw = tones[tone];
        if (raw is! List) continue;
        final lines = <VoiceLine>[];
        for (final item in raw) {
          if (item is! Map) continue;
          final id = item['id'];
          final en = item['en'];
          final ar = item['ar'];
          final needs = item['needs'];
          if (id is! String || en is! String || ar is! String) continue;
          lines.add(
            VoiceLine(
              id: id,
              en: en,
              ar: ar,
              needs: needs is List
                  ? [
                      for (final n in needs)
                        if (n is String) n,
                    ]
                  : const <String>[],
            ),
          );
        }
        byTone[tone] = lines;
      }
      out[entry.key as String] = byTone;
    }
    return NotificationVoice(out);
  }

  final Map<String, Map<String, List<VoiceLine>>> _lines;

  bool get isEmpty => _lines.isEmpty;

  /// A line for [situation], or null when none fits and the caller keeps its
  /// plain text.
  ///
  /// [seed] is any number that differs from one notification to the next; the
  /// same seed gives the same answer. [keep] is a line already chosen for
  /// this very notification: it is returned again while it still fits, so a
  /// replan does not reword a note.
  ({String lineId, String tone, String text})? pick(
    String situation, {
    required String locale,
    Map<String, String> slots = const <String, String>{},
    required VoiceHistory history,
    bool protectedStage = false,
    required int seed,
    required DateTime now,
    String? keep,
  }) {
    final tones = _lines[situation];
    if (tones == null) return null;
    final s = seed.abs();
    for (final tone in _toneOrder(history, protectedStage, s)) {
      final fits = <VoiceLine>[
        for (final line in tones[tone] ?? const <VoiceLine>[])
          if (_fits(line, locale, slots) &&
              (line.id == keep || !history.usedNear(line.id, now)))
            line,
      ];
      if (fits.isEmpty) continue;
      final kept = fits.where((l) => l.id == keep).firstOrNull;
      final line = kept ?? fits[s ~/ kVoiceExploreEvery % fits.length];
      return (
        lineId: line.id,
        tone: tone,
        text: _fill(line.textFor(locale), locale, slots),
      );
    }
    return null;
  }

  static List<String> _toneOrder(
    VoiceHistory history,
    bool protectedStage,
    int seed,
  ) {
    if (protectedStage) return const [kToneCalm];
    final better = history.scoreOf(kTonePlayful) > history.scoreOf(kToneCalm)
        ? kTonePlayful
        : kToneCalm;
    final other = better == kToneCalm ? kTonePlayful : kToneCalm;
    return seed % kVoiceExploreEvery == 0 ? [other, better] : [better, other];
  }

  static bool _fits(VoiceLine line, String locale, Map<String, String> slots) {
    final text = line.textFor(locale);
    if (text.trim().isEmpty) return false;
    // A value with a number, a long name or a banned word would break the
    // lock-screen rules, so the line waits for one without.
    bool has(String slot) {
      final value = (slots[slot] ?? '').trim();
      return value.isNotEmpty &&
          value.length <= kVoiceSlotMaxLength &&
          !_digit.hasMatch(value) &&
          voiceBannedWord(value) == null;
    }

    if (!line.needs.every(has)) return false;
    return _placeholder.allMatches(text).every((m) => has(m.group(1)!));
  }

  static String _fill(String text, String locale, Map<String, String> slots) =>
      text.replaceAllMapped(_placeholder, (m) {
        final value = slots[m.group(1)!]!.trim();
        final plain = locale == 'ar' && !_arabicLetter.hasMatch(value);
        return plain ? '$_isolateStart$value$_isolateEnd' : value;
      });
}
