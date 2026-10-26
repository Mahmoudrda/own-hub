# WO-10e2: the receipt reader (pure Dart)
Depends on: WO-10d0
Size: M
Reads first: spec sections 13.3, 13.12, 13.13 in `docs/plan/INSTAPAY-PAYMENTS-SPEC.md`; `app/lib/features/private_coaching/presentation/coach/coach_text.dart` lines 1-25 (`westernDigits`); `app/lib/features/instapay/domain/instapay_models.dart`

## Why
The phone reads the text of her screenshots and fills the form for her, so honest use takes one tap. The reader must not depend on any one bank's layout (spec 13.13): it looks for what must be true (success words, the exact amount, the coach's address or the start of her name, a transaction number or a time) anywhere in the text. This reader is a HINT for instant feedback. The server reads again and decides (spec 13.3). It must never throw, whatever text it is given.

## Final result
No screen. A function `readReceipt(texts, expected, now)` returns a `ReceiptReading` (what was found and why not) and `phoneVerdict(reading)` returns green, amber, red or wrongMessage. WO-10e4 calls it.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/domain/receipt_reader.dart | create | the reader |
| app/test/features/instapay/receipt_reader_test.dart | create | fixtures as strings, every invariant missing one at a time, garbage |

## Steps
1. File `app/lib/features/instapay/domain/receipt_reader.dart` (create). Full content:
```dart
/// Reads the text of a bank receipt (or SMS) for one expected payment.
///
/// Generic on purpose (spec 13.13): no bank logo, colour or layout is used.
/// Latin text and digits only are read on the phone by ML Kit (UNVERIFIED:
/// ML Kit v2 does not read Arabic script, see WO-10e3); Arabic phrases are
/// matched when the text contains them, and the server is the authority.
library;

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
    if (txnNumber == null && !timeInWindow) 'no_txn_or_time',
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
    'timeSeen': timeSeen?.toUtc().toIso8601String(),
    'timeInWindow': timeInWindow,
    'senderHandle': senderHandle,
  };
}

const int _maxChars = 20000;

const List<String> _failure = <String>[
  'unsuccessful', 'failed', 'declined', 'rejected', 'pending', 'insufficient',
  'فشلت', 'مرفوض', 'قيد الانتظار', 'لم تتم', 'لم يتم',
];
const List<String> _success = <String>[
  'transaction was successful', 'approved transaction', 'successful',
  'successfully', 'transfer completed', 'تمت العملية بنجاح', 'تمت بنجاح',
  'تم التحويل بنجاح', 'عملية ناجحة',
];
const List<String> _cardWords = <String>[
  'has been used for', 'available limit', 'credit card ending',
  'card ending', 'one time password', 'تم استخدام بطاقة', 'الحد المتاح',
];
const List<String> _txnLabels = <String>[
  'transaction id', 'transaction number', 'transaction no', 'reference',
  'rrn', 'رقم العملية', 'رقم المرجع', 'الرقم المرجعي',
];

/// Arabic-Indic and Persian digits to 0-9; the Arabic decimal mark to '.'.
String normalizeDigits(String s) {
  final b = StringBuffer();
  for (final u in s.runes) {
    if (u >= 0x0660 && u <= 0x0669) {
      b.writeCharCode(0x30 + u - 0x0660);
    } else if (u >= 0x06F0 && u <= 0x06F9) {
      b.writeCharCode(0x30 + u - 0x06F0);
    } else if (u == 0x066B || u == 0x066C) {
      b.write(u == 0x066B ? '.' : ',');
    } else {
      b.writeCharCode(u);
    }
  }
  return b.toString();
}

/// "500.37", "500,37", "1,500.00", "1 500,50" to piasters; null when not an amount.
int? amountToPiasters(String token) {
  final t = token.trim().replaceAll(RegExp(r'\s'), '');
  final m = RegExp(r'^(\d{1,9}(?:[.,]\d{3})*)(?:[.,](\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final whole = int.tryParse(m.group(1)!.replaceAll(RegExp(r'[.,]'), ''));
  if (whole == null) return null;
  var cents = 0;
  final frac = m.group(2);
  if (frac != null) cents = int.parse(frac.padRight(2, '0'));
  return whole * 100 + cents;
}

final RegExp _number = RegExp(r'\d{1,3}(?:[ ,.]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?');

ReceiptReading readReceipt(List<String> texts, ExpectedPayment e, DateTime now) {
  try {
    return _read(texts, e, now);
  } catch (_) {
    return const ReceiptReading();
  }
}

ReceiptReading _read(List<String> texts, ExpectedPayment e, DateTime now) {
  var joined = texts.join('\n');
  if (joined.length > _maxChars) joined = joined.substring(0, _maxChars);
  final text = normalizeDigits(joined);
  final low = text.toLowerCase();

  final failure = _failure.any(low.contains);
  final success = _success.any(low.contains) && !low.contains('unsuccessful');
  final card = _cardWords.any(low.contains) && !low.contains('instapay');

  var amountFound = false;
  int? other;
  for (final m in _number.allMatches(text)) {
    final p = amountToPiasters(m.group(0)!);
    if (p == null) continue;
    if (p == e.amountPiasters) {
      amountFound = true;
      continue;
    }
    // A different figure counts only next to a currency word.
    final from = m.start - 12 < 0 ? 0 : m.start - 12;
    final to = m.end + 12 > text.length ? text.length : m.end + 12;
    final around = low.substring(from, to);
    if (p >= 100 && RegExp(r'egp|جنيه|ج\.م|amount|المبلغ').hasMatch(around)) other ??= p;
  }

  final addr = e.coachAddress.trim().toLowerCase();
  final addressFound = addr.isNotEmpty && low.contains(addr);
  final first = e.coachAccountName.trim().split(RegExp(r'\s+')).first.toLowerCase();
  final prefix = first.length >= 3 ? first.substring(0, 3) : first;
  final nameFound = prefix.length >= 2 && low.contains(prefix);

  String? txn;
  for (final label in _txnLabels) {
    final at = low.indexOf(label);
    if (at < 0) continue;
    final end = (at + label.length + 48) > text.length ? text.length : at + label.length + 48;
    final m = RegExp(r'\b\d{10,20}\b').firstMatch(text.substring(at + label.length, end));
    if (m != null) {
      txn = m.group(0);
      break;
    }
  }

  DateTime? seen;
  final d1 = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](20\d{2})[ ,T]+(\d{1,2}):(\d{2})').firstMatch(text);
  final d2 = RegExp(r'(20\d{2})[/\-.](\d{1,2})[/\-.](\d{1,2})[ ,T]+(\d{1,2}):(\d{2})').firstMatch(text);
  if (d1 != null) {
    seen = _date(d1.group(3)!, d1.group(2)!, d1.group(1)!, d1.group(4)!, d1.group(5)!);
  } else if (d2 != null) {
    seen = _date(d2.group(1)!, d2.group(2)!, d2.group(3)!, d2.group(4)!, d2.group(5)!);
  }
  final inWindow = seen != null &&
      !seen.isBefore(e.createdAt.toLocal().subtract(const Duration(minutes: 2))) &&
      !seen.isAfter(now.toLocal().add(const Duration(minutes: 5)));

  final from = RegExp(r'(?:from|من)\W{0,6}([A-Za-z0-9._-]{3,40}@[A-Za-z0-9]{2,20})', caseSensitive: false).firstMatch(text);

  return ReceiptReading(
    successPhrase: success,
    failurePhrase: failure,
    cardMessage: card,
    amountFound: amountFound,
    otherAmountPiasters: other,
    recipientAddressFound: addressFound,
    recipientNameStartFound: nameFound,
    txnNumber: txn,
    timeSeen: seen,
    timeInWindow: inWindow,
    senderHandle: from?.group(1),
  );
}

DateTime? _date(String y, String mo, String d, String h, String mi) {
  final dt = DateTime(int.parse(y), int.parse(mo), int.parse(d), int.parse(h), int.parse(mi));
  // DateTime rolls 31 Feb into March; refuse that.
  return dt.month == int.parse(mo) ? dt : null;
}

/// The phone's hint. The server decides (spec 13.3). Unknown layout is amber,
/// never red; only a contradiction is red (spec 13.13 item 2).
PhoneVerdict phoneVerdict(ReceiptReading r) {
  if (r.cardMessage) return PhoneVerdict.wrongMessage;
  if (r.failurePhrase) return PhoneVerdict.red;
  if (!r.amountFound && r.otherAmountPiasters != null) return PhoneVerdict.red;
  if (r.successPhrase &&
      r.amountFound &&
      r.recipientFound &&
      (r.txnNumber != null || r.timeInWindow)) {
    return PhoneVerdict.green;
  }
  return PhoneVerdict.amber;
}
```
Notes the agent must keep: `failure` is checked before `success`; a bank SMS alone never gives green because a card alert has none of the five facts together (spec 13.13 item 3).
2. File `app/test/features/instapay/receipt_reader_test.dart` (create). Build the fixtures as constants at the top (synthetic, no real names or numbers):
```dart
final created = DateTime(2026, 10, 27, 14, 0);
final now = DateTime(2026, 10, 27, 14, 40);
const expected = ExpectedPayment(
  amountPiasters: 50037,
  coachAddress: 'rahma.m@instapay',
  coachAccountName: 'Rahma Mohsen',
  createdAt: ..., // use `created`
);
const receipt = 'Approved Transaction\nYour transaction was successful\n500.37 EGP\nFrom\nsara.k@instapay 1234\nTo Instapay\nRah*** M***\nrahma.m@instapay\nMore Details';
const details = 'Transaction ID 123456789012\n27/10/2026 14:32';
const cardAlert = 'Your credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre';
```
(`expected` cannot be `const` with a non-const date; make it `final`.)

## Strings to add
None.

## Tests to add or change
All in `receipt_reader_test.dart`; each calls `readReceipt([...], expected, now)` then `phoneVerdict`.
| test name | arrange, act, assert |
|---|---|
| `receipt plus details is green` | texts `[receipt, details]`; verdict green; `txnNumber == '123456789012'`; `senderHandle == 'sara.k@instapay'`; `timeInWindow` true |
| `receipt alone is amber with no_txn_or_time` | `[receipt]`; amber; `reasons` contains `no_txn_or_time` |
| `each invariant missing on its own is amber` | five variants of `receipt + details`: remove the success lines; replace `500.37` by nothing; replace both the address and `Rah*** M***`; remove txn and time; assert each is amber and never red |
| `a different amount next to EGP is red` | replace `500.37 EGP` with `450.00 EGP`; red; `otherAmountPiasters == 45000`; reasons contain `different_amount` |
| `failed or pending status is red` | replace the success lines with `Transaction failed` ; red. Also `Pending` ; red. Also `unsuccessful` ; red |
| `a card purchase alert is the wrong message` | `[cardAlert]`; `wrongMessage`; reasons contain `card_message` |
| `a bank SMS alone is never green` | `['Your account was credited EGP 500.37 on 27/10/2026 14:32 ref 123456789012']`; not green |
| `Arabic digits and decimal mark are read` | the receipt with `٥٠٠٫٣٧` and `٢٧/١٠/٢٠٢٦ ١٤:٣٢`; green (needs the Arabic success phrase `تمت العملية بنجاح` and the address in Latin) |
| `amount formats` | `amountToPiasters('500.37')==50037`; `'500,37'==50037`; `'1,500.00'==150000`; `'1 500,50'==150050`; `'abc'` null; `'٥٧٠٫٣٧'` after `normalizeDigits` is `57037` |
| `time outside the window is not accepted` | details with `20/10/2026 10:00`; `timeInWindow` false; then verdict amber when txn absent |
| `31 February is refused` | `31/02/2026 10:00`; `timeSeen` null |
| `garbage never throws` | inputs: `[]`, `['']`, 100000 random characters, `'\u0000' * 5000`, a string of 20000 digits, `'😀' * 9000`, `'((((' * 2000`; each returns a reading; none throws; verdict amber |
| `a long name and a masked name still match` | account name `Rahma Mohsen Abdelrahman Elsayed Ibrahim`; text with `Rah*** M***` and no address; `recipientNameStartFound` true |
| `the same screenshot read twice gives the same reading` | `toJson()` equal |
Run: `cd app && flutter test test/features/instapay/receipt_reader_test.dart`

## Verify
- `cd app && dart analyze lib/features/instapay test/features/instapay` ends `No issues found!`
- the test command ends `All tests passed!` with at least 14 tests.

## Do not
- Do not read an image here: only strings.
- Do not make any check depend on a bank name or layout.
- Do not send the full OCR text to the server: only `toJson()` (no names beyond the visible handle, no card digits).
- Do not turn an unreadable field into red.

## Done checklist
- [ ] reader written exactly; tests pass
- [ ] garbage test includes the 20000-digit and emoji cases

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10j2).

UNVERIFIED in this order: 1 (ML Kit v2 cannot read Arabic script; verified in WO-10e3 step 1).
