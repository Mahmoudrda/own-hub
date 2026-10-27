/// Reads the text of a bank receipt (or SMS) for one expected payment.
///
/// Generic on purpose (spec 13.13): no bank logo, colour or layout is used.
/// What must be true is searched for anywhere in the text: a success phrase,
/// the exact amount, the coach's address or the start of her name, a
/// transaction number and a time inside the window. Latin text and digits
/// are what ML Kit reads on the phone; Arabic phrases are matched when the
/// text holds them. This reader is a HINT for instant feedback. The server
/// reads again and decides (`functions/payments/receipt_checks.py`).
///
/// Never throws, whatever text it is given.
library;

import '../../events/domain/cairo_time.dart';

class ExpectedPayment {
  const ExpectedPayment({
    required this.amountPiasters,
    required this.coachAddress,
    required this.coachAccountName,
    required this.createdAt,
  });
  final int amountPiasters;
  final String coachAddress;
  final String coachAccountName;
  final DateTime createdAt;
}

enum PhoneVerdict { green, amber, red, wrongMessage }

class ReceiptReading {
  const ReceiptReading({
    this.successPhrase = false,
    this.failurePhrase = false,
    this.cardMessage = false,
    this.amountFound = false,
    this.otherAmountPiasters,
    this.recipientAddressFound = false,
    this.recipientNameStartFound = false,
    this.txnNumber,
    this.timeSeen,
    this.timeInWindow = false,
    this.senderHandle,
  });

  final bool successPhrase;
  final bool failurePhrase;
  final bool cardMessage;
  final bool amountFound;
  final int? otherAmountPiasters;
  final bool recipientAddressFound;
  final bool recipientNameStartFound;
  final String? txnNumber;

  /// Cairo wall-clock time printed on the receipt (not an instant).
  final DateTime? timeSeen;
  final bool timeInWindow;
  final String? senderHandle;

  bool get recipientFound => recipientAddressFound || recipientNameStartFound;

  /// Reason codes for the screen and for staff. Stable strings.
  List<String> get reasons => <String>[
    if (cardMessage) 'card_message',
    if (failurePhrase) 'failed_status',
    if (!successPhrase && !failurePhrase && !cardMessage) 'no_success',
    if (!amountFound && otherAmountPiasters != null) 'different_amount',
    if (!amountFound && otherAmountPiasters == null) 'no_amount',
    if (!recipientFound) 'no_recipient',
    if (txnNumber == null) 'no_txn',
    if (!timeInWindow) 'no_time',
  ];

  /// What goes to the server as `phoneReading`. No image, no full text.
  Map<String, Object?> toJson() => <String, Object?>{
    'success': successPhrase,
    'failure': failurePhrase,
    'cardMessage': cardMessage,
    'amountFound': amountFound,
    'otherAmountPiasters': otherAmountPiasters,
    'recipientAddress': recipientAddressFound,
    'recipientName': recipientNameStartFound,
    'txnNumber': txnNumber,
    'timeInWindow': timeInWindow,
    'senderHandle': senderHandle,
  };
}

const int _maxChars = 20000;

const List<String> _failure = <String>[
  'unsuccessful',
  'failed',
  'declined',
  'rejected',
  'pending',
  'in progress',
  'processing',
  'insufficient',
  'فشل',
  'مرفوض',
  'معلقه',
  'قيد التنفيذ',
  'قيد الانتظار',
  'غير ناجحه',
  'لم تتم',
  'لم يتم',
];
const List<String> _success = <String>[
  'transaction was successful',
  'transaction successful',
  'approved transaction',
  'successful',
  'successfully',
  'completed',
  'transfer completed',
  'تمت العمليه بنجاح',
  'تمت بنجاح',
  'تم التحويل بنجاح',
  'عمليه ناجحه',
  'تم بنجاح',
  'تمت العمليه',
];
const List<String> _cardWords = <String>[
  'has been used for',
  'available limit',
  'available balance',
  'your balance',
  'credit card ending',
  'card ending',
  'one time password',
  'one-time password',
  'otp',
  'verification code',
  'purchase',
  'تم استخدام بطاقه',
  'الحد المتاح',
  'الرصيد المتاح',
  'رمز التحقق',
  'عمليه شراء',
];
const List<String> _txnLabels = <String>[
  'transaction id',
  'transaction number',
  'transaction no',
  'transaction ref',
  'reference number',
  'reference no',
  'reference',
  'ref no',
  'ref.',
  'rrn',
  'رقم العمليه',
  'رقم المرجع',
  'الرقم المرجعي',
  'رقم مرجعي',
];
const List<String> _notTheAmount = <String>[
  'fee',
  'charge',
  'commission',
  'balance',
  'limit',
  'available',
  'رسوم',
  'عموله',
  'رصيد',
  'الحد',
  'المتاح',
];

final RegExp _diacritics = RegExp(r'[\u064B-\u0652\u0640]');
final RegExp _invisible = RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060\uFEFF]');

/// Arabic-Indic and Persian digits to 0-9; the Arabic decimal mark to '.',
/// the Arabic thousands mark to ','; invisible direction marks removed.
String normalizeDigits(String s) {
  final b = StringBuffer();
  for (final u in s.runes) {
    if (u >= 0x0660 && u <= 0x0669) {
      b.writeCharCode(0x30 + u - 0x0660);
    } else if (u >= 0x06F0 && u <= 0x06F9) {
      b.writeCharCode(0x30 + u - 0x06F0);
    } else if (u == 0x066B) {
      b.write('.');
    } else if (u == 0x066C) {
      b.write(',');
    } else if (u >= 0x200B && u <= 0x200F ||
        u >= 0x202A && u <= 0x202E ||
        u == 0x2060 ||
        u == 0xFEFF) {
      continue;
    } else {
      b.writeCharCode(u);
    }
  }
  return b.toString();
}

/// Lower case, diacritics off, Arabic letter variants folded.
String foldText(String s) {
  var t = s
      .toLowerCase()
      .replaceAll(_diacritics, '')
      .replaceAll(_invisible, '');
  for (final p in const [
    ['أ', 'ا'],
    ['إ', 'ا'],
    ['آ', 'ا'],
    ['ى', 'ي'],
    ['ة', 'ه'],
  ]) {
    t = t.replaceAll(p[0], p[1]);
  }
  return t;
}

/// "500.37", "500,37", "1,500.00", "1 500,50" to piasters; null when not an amount.
int? amountToPiasters(String token) {
  final t = token.trim().replaceAll(RegExp(r'\s'), '');
  final m = RegExp(r'^(\d{1,9}(?:[.,]\d{3})*)(?:[.,](\d{1,2}))?$')
      .firstMatch(t);
  if (m == null) return null;
  final whole = int.tryParse(m.group(1)!.replaceAll(RegExp(r'[.,]'), ''));
  if (whole == null) return null;
  var cents = 0;
  final frac = m.group(2);
  if (frac != null) cents = int.parse(frac.padRight(2, '0'));
  return whole * 100 + cents;
}

final RegExp _number = RegExp(
  r'(?<![\d.,])(?:\d{1,3}(?:[ ,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?![\d])',
);
final RegExp _currencyNear = RegExp(r'egp|جنيه|جم|ج\.م|\ble\b|£');

ReceiptReading readReceipt(
  List<String> texts,
  ExpectedPayment e,
  DateTime now,
) {
  try {
    return _read(texts, e, now);
  } catch (_) {
    return const ReceiptReading();
  }
}

/// A line of at most [words] words that holds one of [phrases]: a status
/// line, not a sentence that happens to hold the word.
bool _statusLine(List<String> lines, List<String> phrases, int words) {
  for (final line in lines) {
    if (line.split(RegExp(r'\s+')).length > words) continue;
    if (phrases.any(line.contains)) return true;
  }
  return false;
}

DateTime _wall(DateTime instant) {
  final c = toCairo(instant);
  return DateTime(c.year, c.month, c.day, c.hour, c.minute);
}

ReceiptReading _read(List<String> texts, ExpectedPayment e, DateTime now) {
  var joined = texts.join('\n');
  if (joined.length > _maxChars) joined = joined.substring(0, _maxChars);
  final text = normalizeDigits(joined);
  final low = foldText(text);
  final lines = <String>[
    for (final l in low.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  final failure = _statusLine(lines, _failure, 8);
  final success = !failure && _statusLine(lines, _success, 10);
  final handleish = RegExp(r'[a-z0-9._*-]+@[a-z]{3,20}').hasMatch(low);
  final card =
      _cardWords.any(
        (w) => w == 'otp' ? RegExp(r'\botp\b').hasMatch(low) : low.contains(w),
      ) &&
      !low.contains('instapay') &&
      !low.contains('انستا') &&
      !handleish;

  var amountFound = false;
  int? other;
  for (final m in _number.allMatches(low)) {
    final token = m.group(0)!;
    final p = amountToPiasters(token);
    if (p == null) continue;
    final lineStart = low.lastIndexOf('\n', m.start) + 1;
    final lineEnd = low.indexOf('\n', m.end);
    final line = low.substring(lineStart, lineEnd < 0 ? low.length : lineEnd);
    if (p == e.amountPiasters) {
      if (!_notTheAmount.any(line.contains)) amountFound = true;
      continue;
    }
    if (p < 100 || _notTheAmount.any(line.contains)) continue;
    final from = m.start - 6 < 0 ? 0 : m.start - 6;
    final to = m.end + 6 > low.length ? low.length : m.end + 6;
    final twoDecimals = RegExp(r'[.,]\d{2}$').hasMatch(token);
    if (_currencyNear.hasMatch(low.substring(from, to)) ||
        (twoDecimals && RegExp(r'amount|total|المبلغ|مبلغ').hasMatch(line))) {
      other ??= p;
    }
  }

  final addr = e.coachAddress.trim().toLowerCase();
  final addressFound = addr.isNotEmpty && low.contains(addr);
  final names = foldText(e.coachAccountName.trim()).split(RegExp(r'\s+'));
  final first = names.isEmpty ? '' : names.first;
  final prefix = first.length >= 3 ? first.substring(0, 3) : first;
  final nameFound = prefix.length >= 2 && low.contains(prefix);

  String? txn;
  for (final label in _txnLabels) {
    var at = low.indexOf(label);
    while (at >= 0 && txn == null) {
      final start = at + label.length;
      final end = start + 48 > low.length ? low.length : start + 48;
      final m = RegExp(r'(?<![\d.,])\d{10,20}(?![\d])')
          .firstMatch(low.substring(start, end));
      if (m != null) txn = m.group(0);
      at = low.indexOf(label, start);
    }
    if (txn != null) break;
  }

  final seen = _timeSeen(low);
  final inWindow =
      seen != null &&
      !seen.isBefore(_wall(e.createdAt).subtract(const Duration(minutes: 2))) &&
      !seen.isAfter(_wall(now).add(const Duration(minutes: 5)));

  final from = RegExp(
    r'(?:from|sender|payer|من|المرسل)\W{0,6}([a-z0-9._*-]{3,40}@[a-z]{3,20})',
  ).firstMatch(low);

  return ReceiptReading(
    successPhrase: success,
    failurePhrase: failure,
    cardMessage: card,
    amountFound: amountFound,
    otherAmountPiasters: amountFound ? null : other,
    recipientAddressFound: addressFound,
    recipientNameStartFound: nameFound,
    txnNumber: txn,
    timeSeen: seen,
    timeInWindow: inWindow,
    senderHandle: from?.group(1),
  );
}

const Map<String, int> _months = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
  'يناير': 1,
  'فبراير': 2,
  'مارس': 3,
  'ابريل': 4,
  'مايو': 5,
  'يونيو': 6,
  'يوليو': 7,
  'اغسطس': 8,
  'سبتمبر': 9,
  'اكتوبر': 10,
  'نوفمبر': 11,
  'ديسمبر': 12,
};

final RegExp _dmy = RegExp(
  r'(\d{1,2})[/\-.](\d{1,2})[/\-.](20\d{2})[\s,]*(?:at\s+|t)?(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm|ص|م)?',
);
final RegExp _ymd = RegExp(
  r'(20\d{2})[/\-.](\d{1,2})[/\-.](\d{1,2})[\s,]*(?:at\s+|t)?(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm|ص|م)?',
);
final RegExp _dMonY = RegExp(
  r'(\d{1,2})\s+([a-zء-ي]{3,9})\.?,?\s+(20\d{2})[,،]?\s*(?:at\s+)?(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm|ص|م)?',
);

DateTime? _timeSeen(String low) {
  final a = _dmy.firstMatch(low);
  if (a != null) {
    return _date(
      a.group(3)!,
      a.group(2)!,
      a.group(1)!,
      a.group(4)!,
      a.group(5)!,
      a.group(6),
    );
  }
  final b = _ymd.firstMatch(low);
  if (b != null) {
    return _date(
      b.group(1)!,
      b.group(2)!,
      b.group(3)!,
      b.group(4)!,
      b.group(5)!,
      b.group(6),
    );
  }
  for (final c in _dMonY.allMatches(low)) {
    final name = c.group(2)!;
    final month =
        _months[name.length > 3 && RegExp('^[a-z]+\$').hasMatch(name)
            ? name.substring(0, 3)
            : name];
    if (month == null) continue;
    return _date(
      c.group(3)!,
      '$month',
      c.group(1)!,
      c.group(4)!,
      c.group(5)!,
      c.group(6),
    );
  }
  return null;
}

DateTime? _date(
  String y,
  String mo,
  String d,
  String h,
  String mi,
  String? half,
) {
  var hour = int.parse(h);
  if (half == 'pm' || half == 'م') {
    if (hour < 12) hour += 12;
  } else if ((half == 'am' || half == 'ص') && hour == 12) {
    hour = 0;
  }
  if (hour > 23 || int.parse(mi) > 59) return null;
  final dt = DateTime(
    int.parse(y),
    int.parse(mo),
    int.parse(d),
    hour,
    int.parse(mi),
  );
  // DateTime rolls 31 Feb into March; refuse that.
  return dt.month == int.parse(mo) ? dt : null;
}

/// The phone's hint. The server decides. An unknown layout is amber, never
/// red; only a contradiction is red (spec 13.13 item 2). GREEN needs the
/// transaction number AND a time in the window, like the server (a bank SMS
/// alone never gets there).
PhoneVerdict phoneVerdict(ReceiptReading r) {
  if (r.cardMessage) return PhoneVerdict.wrongMessage;
  if (r.failurePhrase) return PhoneVerdict.red;
  if (!r.amountFound && r.otherAmountPiasters != null) return PhoneVerdict.red;
  if (r.successPhrase &&
      r.amountFound &&
      r.recipientFound &&
      r.txnNumber != null &&
      r.timeInWindow) {
    return PhoneVerdict.green;
  }
  return PhoneVerdict.amber;
}
