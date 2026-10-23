/// What the coaching chat refuses before it sends (and what the server hides
/// after): phone numbers, payment details, links and a short insult list.
///
/// The Python twin is `functions/coaching/chat.py`. Both give the same verdict
/// for every case in `contracts/coaching_chat_screen_vectors.json`, and the
/// steps below follow it one for one. If you change one, change the other.
///
/// The text is first normalised: decimal digits of any script become 0-9,
/// full-width letters become plain, Arabic marks, tatweel and zero-width marks
/// go, Arabic letter variants fold (أ إ آ ٱ to ا, ى to ي, ة to ه, ؤ to و,
/// ئ to ي) and the rest is lower-cased. Then, in this order, so a text gets
/// one reason:
///  1. contact: a run of digits (split by spaces, dots or dashes) that reads
///     as an Egyptian mobile number or holds ten or more digits.
///  2. payment: a wallet or transfer app name, in English or Arabic.
///  3. link: `http(s)://`, `www.`, or a name ending in a common domain.
///  4. abuse: a whole word from the insult list.
library;

enum ChatScreenReason { contact, payment, link, abuse }

abstract final class ChatScreen {
  /// Why [text] may not be sent, or null when it may.
  static ChatScreenReason? screen(String text) {
    final folded = normalise(text);
    if (_hasContact(folded)) return ChatScreenReason.contact;
    if (_payment.hasMatch(folded)) return ChatScreenReason.payment;
    if (_link.hasMatch(folded)) return ChatScreenReason.link;
    if (_abuse.hasMatch(folded)) return ChatScreenReason.abuse;
    return null;
  }

  /// First code point of each block of decimal digits (category Nd).
  static const List<int> _digitZeros = <int>[
    0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, //
    0x0BE6, 0x0C66, 0x0CE6, 0x0D66, 0x0E50, 0x0ED0, 0x0F20, 0x1040,
    0x17E0, 0x1810, 0xFF10,
  ];

  static const Map<int, int> _letters = <int, int>{
    0x0623: 0x0627, 0x0625: 0x0627, 0x0622: 0x0627, 0x0671: 0x0627, //
    0x0649: 0x064A, 0x0629: 0x0647, 0x0624: 0x0648, 0x0626: 0x064A,
  };

  static bool _dropped(int c) =>
      (c >= 0x064B && c <= 0x065F) ||
      c == 0x0670 ||
      (c >= 0x200B && c <= 0x200F) ||
      (c >= 0x202A && c <= 0x202E) ||
      (c >= 0x2066 && c <= 0x2069) ||
      c == 0x0640 ||
      c == 0xFEFF;

  static String normalise(String text) {
    final out = StringBuffer();
    for (var c in text.runes) {
      // Full-width forms are plain ASCII under NFKC.
      if (c >= 0xFF01 && c <= 0xFF5E) c = c - 0xFF01 + 0x21;
      if (c == 0x3000) c = 0x20;
      for (final zero in _digitZeros) {
        if (c >= zero && c <= zero + 9) {
          c = 0x30 + c - zero;
          break;
        }
      }
      if (_dropped(c)) continue;
      out.writeCharCode(_letters[c] ?? c);
    }
    return out.toString().toLowerCase();
  }

  // ---------------------------------------------------------------- contact

  static final RegExp _numberRun = RegExp(r'\+?\d(?:[\s.\-]*\d)*');
  static final RegExp _separators = RegExp(r'[\s.\-]');
  static final RegExp _egMobile = RegExp(r'(?:\+?20|0020|0)1[0125]\d{8}');

  /// Sets, reps or kilos written in a row ("12 10 10 8 8 6", "22.5 25 27.5"):
  /// every number one or two digits and none starting with 0, which no phone
  /// number looks like.
  static bool _looksLikeCounts(String run) {
    if (run.startsWith('+')) return false;
    final groups = run.split(RegExp(r'[\s.\-]+')).where((g) => g.isNotEmpty);
    return groups.length >= 2 &&
        groups.every((g) => g.length <= 2 && !g.startsWith('0'));
  }

  static bool _hasContact(String folded) {
    for (final run in _numberRun.allMatches(folded)) {
      if (_looksLikeCounts(run.group(0)!)) continue;
      final digits = run.group(0)!.replaceAll(_separators, '');
      if (_egMobile.hasMatch(digits)) return true;
      if (digits.replaceFirst(RegExp(r'^\++'), '').length >= 10) return true;
    }
    return false;
  }

  // ------------------------------------------------------------------ rest

  static const String _word = r'[\p{L}\p{N}_]';

  static const List<String> _paymentNames = <String>[
    'instapay', 'insta pay', 'vodafone cash', 'vodafonecash', //
    'etisalat cash', 'orange cash', 'we pay', 'wepay', 'fawry',
    'فودافون كاش', 'فودافون كش', 'انستاباي', 'انستا باي', 'اتصالات كاش',
    'اورنج كاش', 'فوري',
  ];

  static final RegExp _payment = RegExp(
    '(?<!$_word)(?:${_paymentNames.map((n) => RegExp.escape(n).replaceAll(' ', r'\s+')).join('|')})(?!$_word)',
    unicode: true,
  );

  static const String _tlds =
      'com|net|org|io|me|co|app|eg|info|biz|ly|gl|tv|xyz|link|shop|store|'
      'online|site|ai|dev|ae|sa|uk|us|ws|cc|to|gg|page|bio';

  static final RegExp _link = RegExp(
    '(?:https?://|(?<!$_word|\\.)www\\.|'
    '(?<!$_word|[@.\\-])[a-z0-9][a-z0-9\\-]*(?:\\.[a-z0-9\\-]+)*\\.(?:$_tlds)(?!$_word|-))',
    unicode: true,
  );

  static const List<String> _abuseWords = <String>[
    'stupid', 'idiot', 'moron', 'bitch', 'slut', 'whore', 'fuck', //
    'fucking', 'shit',
    'غبيه', 'غبي', 'حمار', 'حماره', 'شرموطه', 'قحبه', 'عرص', 'متخلفه',
    'متخلف', 'زباله',
  ];

  static final RegExp _abuse = RegExp(
    '(?<!$_word)(?:${_abuseWords.join('|')})(?!$_word)',
    unicode: true,
  );
}
