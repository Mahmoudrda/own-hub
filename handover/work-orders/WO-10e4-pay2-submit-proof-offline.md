# WO-10e4: PAY2, send the proof (autofill, saved handle, offline queue)
Depends on: WO-10e1, WO-10e3
Size: L
Reads first: `app/lib/features/instapay/presentation/payment_view.dart`; `app/lib/features/instapay/domain/receipt_reader.dart`; `app/lib/features/instapay/data/proof_images.dart`; `app/lib/features/instapay/data/instapay_local_store.dart`; `app/lib/ui/app_sheet.dart` lines 20-90; spec 4.2, 4.6, 4.18, 13.4, 13.12 items 1-3 and 7, 13.13 items 2, 3 and 5

## Why
She has paid in her bank app. Now she picks the screenshots and the form fills itself. The normal case is: choose, look at the summary, send. Typing is the fallback only. If she has no signal the proof is kept and sent later with the same key, so a double send or a retry never makes two payments, and her screenshots are not lost.

## Final result
PAY2 top to bottom:
1. Top bar "Send your proof", back arrow.
2. Text: "Add your bank screenshots: the receipt, and the one with More Details open." / "ضيفي لقطات شاشة البنك: الإيصال، واللي فاتح فيها More Details."
3. Outlined button "Choose screenshots" / "اختاري لقطات الشاشة". After a choice it keeps working as "replace".
4. A card of read-only rows (not controls): "Amount  500.37 EGP" (from the payment, not from the picture), "Transaction number  123456789012" or "Not found yet", "{count} pictures added" when there are pictures.
5. Text button "Edit" / "عدّلي". It reveals one field "Transaction number". The field also appears by itself when none was found after a choice.
6. First payment only: one field "Your own InstaPay address" with helper "We use it to match your receipt. Asked once." If it looks like a phone number the helper becomes "A phone number would show on your coach's receipt. Use your @ address if you have one." (it never blocks).
7. One hint line from the phone's reading (see Hints below).
8. Footer, the one primary "Send to coach" / "ابعتي لمدرّبتك".
Hints (from `phoneVerdict`): green "Everything matches. Tap send." / amber "We could not read everything. Add the screenshot with More Details open, or type the transaction number." / red "This does not match your payment. You can still send it and Own Hub will check." (primary stays on) / wrongMessage "This looks like a card message, not an InstaPay transfer receipt. Please send the transfer receipt." (primary off until she chooses again).
Controls above the fold at 390x844: back, Choose, Edit = 3 others + 1 primary. Worst case (Edit open, first payment): back, Choose, Edit, txn field, handle field = 5 others + 1 primary.
First send ever: before sending, a sheet "Help improve receipt reading?" with body "We keep only the text fields we read, never your picture. You can say no." and two buttons: "Yes, help" (the sheet's one primary) and "No thanks" (text). Asked once; the answer is kept on the phone and sent as `learnConsent` inside `phoneReading`. Counsel may switch this off before release (spec 13.13 item 5): it is one constant, `kAskLearnConsent`.
Sending shows the primary busy. Success: back to H05 (two pops), WO-10e5 changes this to open PAY3. No signal: sheet-free line "Saved. We will send it when you have signal." and she leaves with the same two pops.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/presentation/proof_view.dart | create | PAY2 |
| app/lib/features/instapay/presentation/proof_flow.dart | create | the pick, hide, read pipeline for one picture |
| app/lib/features/instapay/data/pending_proofs.dart | create | offline queue |
| app/lib/features/instapay/data/instapay_local_store.dart | edit | `consentAsked`, saved on answer |
| app/lib/features/instapay/presentation/payment_text.dart | edit | proof reason codes |
| app/lib/routing/app_router.dart | edit | replace the no-op `onIHavePaid` |
| app/test/features/instapay/proof_view_test.dart | create | PAY2 tests |
| app/test/features/instapay/pending_proofs_test.dart | create | queue tests |

## Steps
1. File `app/lib/features/instapay/data/instapay_local_store.dart`. Add inside the class, after `saveLearnConsent`:
```dart
  static const _askedKey = 'instapay.learnAsked';

  Future<bool> consentAsked() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_askedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> answerLearnConsent(bool yes) async {
    await saveLearnConsent(yes);
    try {
      await (await SharedPreferences.getInstance()).setBool(_askedKey, true);
    } catch (_) {}
  }
```
2. File `app/lib/features/instapay/presentation/proof_flow.dart` (create). One function turns one raw picture into what PAY2 needs. Full content:
```dart
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/proof_images.dart';
import '../data/receipt_ocr.dart';
import '../domain/receipt_reader.dart';
import '../domain/redaction_model.dart';
import 'redact_view.dart';

/// One picture after she hid private lines: the PNG that will be uploaded and
/// the text read from THAT png (phone and server read the same pixels).
class PreparedImage {
  const PreparedImage(this.png, this.text);
  final Uint8List png;
  final String text;
}

typedef PrepareImage = Future<PreparedImage?> Function(
  BuildContext context,
  Uint8List raw,
  ExpectedPayment expected,
);

Future<Uint8List?> _toPng(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();

/// decode (capped) -> OCR it -> let her hide lines -> OCR the result.
Future<PreparedImage?> prepareProofImage(
  BuildContext context,
  Uint8List raw,
  ExpectedPayment expected, {
  ReceiptOcr? ocr,
}) async {
  final reader = ocr ?? MlKitReceiptOcr();
  final image = await decodeCapped(raw);
  if (image == null) return null;
  final capped = await _toPng(image);
  if (capped == null) return null;
  final lines = await reader.read(capped);
  final model = RedactionModel(
    imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
    lines: lines,
    expected: expected,
  );
  if (!context.mounted) return null;
  final png = await Navigator.of(context).push<Uint8List?>(
    MaterialPageRoute<Uint8List?>(builder: (_) => RedactView(image: image, model: model)),
  );
  if (png == null) return null;
  final after = await reader.read(png);
  return PreparedImage(png, after.map((l) => l.text).join('\n'));
}
```
3. File `app/lib/features/instapay/data/pending_proofs.dart` (create). Full content:
```dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'instapay_repository.dart';

class PendingProof {
  const PendingProof({
    required this.paymentId,
    required this.key,
    required this.txnNumber,
    required this.paidAtClaimed,
    required this.senderHandle,
    required this.phoneReading,
    required this.locale,
    required this.addEvidence,
    required this.files,
  });
  final String paymentId;
  final String key;
  final String txnNumber;
  final DateTime paidAtClaimed;
  final String senderHandle;
  final Map<String, Object?> phoneReading;
  final String locale;
  final bool addEvidence;
  final List<String> files;

  Map<String, Object?> toJson() => {
    'paymentId': paymentId, 'key': key, 'txn': txnNumber,
    'paidAt': paidAtClaimed.toUtc().toIso8601String(), 'handle': senderHandle,
    'reading': phoneReading, 'locale': locale, 'evidence': addEvidence, 'files': files,
  };

  static PendingProof? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final paidAt = DateTime.tryParse('${raw['paidAt']}');
    if (paidAt == null || '${raw['paymentId']}'.isEmpty || '${raw['key']}'.isEmpty) return null;
    return PendingProof(
      paymentId: '${raw['paymentId']}', key: '${raw['key']}', txnNumber: '${raw['txn']}',
      paidAtClaimed: paidAt, senderHandle: '${raw['handle']}',
      phoneReading: Map<String, Object?>.from((raw['reading'] as Map?) ?? const {}),
      locale: '${raw['locale']}', addEvidence: raw['evidence'] == true,
      files: <String>[for (final f in (raw['files'] as List? ?? const [])) '$f'],
    );
  }
}

/// Proofs that could not be sent for want of signal. Stored on the phone only:
/// the list in shared preferences, the pictures as files in the app support
/// folder. Removed when sent, and by "Delete everything" ([clear]).
class PendingProofs {
  PendingProofs({Directory? dir}) : _dir = dir;
  final Directory? _dir;
  static const _k = 'instapay.pendingProofs';

  Future<Directory> _folder() async {
    final base = _dir ?? Directory('${(await getApplicationSupportDirectory()).path}/instapay-pending');
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  Future<List<PendingProof>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = jsonDecode(p.getString(_k) ?? '[]') as List;
      return <PendingProof>[for (final e in list) ?PendingProof.fromJson(e)];
    } catch (_) {
      return const <PendingProof>[];
    }
  }

  Future<void> _save(List<PendingProof> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(<Object?>[for (final e in list) e.toJson()]));
  }

  /// The same key replaces the earlier entry (a retry never doubles).
  Future<void> add(PendingProof proof, List<Uint8List> images) async {
    final dir = await _folder();
    final files = <String>[];
    for (var n = 0; n < images.length; n++) {
      final f = File('${dir.path}/${proof.key}-$n.png');
      await f.writeAsBytes(images[n], flush: true);
      files.add(f.path);
    }
    final kept = (await all()).where((e) => e.key != proof.key).toList();
    kept.add(PendingProof(
      paymentId: proof.paymentId, key: proof.key, txnNumber: proof.txnNumber,
      paidAtClaimed: proof.paidAtClaimed, senderHandle: proof.senderHandle,
      phoneReading: proof.phoneReading, locale: proof.locale,
      addEvidence: proof.addEvidence, files: files,
    ));
    await _save(kept);
  }

  /// Sends what waits, oldest first. Stops at the first "no signal". A refusal
  /// the server will always repeat drops that entry. Returns how many went.
  Future<int> flush(InstapayRepository repo) async {
    var sent = 0;
    for (final e in await all()) {
      try {
        final images = <Uint8List>[for (final f in e.files) await File(f).readAsBytes()];
        await repo.submitProof(
          paymentId: e.paymentId, idempotencyKey: e.key, txnNumber: e.txnNumber,
          paidAtClaimed: e.paidAtClaimed, senderHandle: e.senderHandle, images: images,
          phoneReading: e.phoneReading, locale: e.locale, addEvidence: e.addEvidence,
        );
        sent++;
        await _remove(e);
      } on PaymentFailure catch (f) {
        if (f.unreachable) return sent;
        await _remove(e);
      } on FileSystemException {
        await _remove(e);
      }
    }
    return sent;
  }

  Future<void> _remove(PendingProof e) async {
    for (final f in e.files) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
    await _save((await all()).where((x) => x.key != e.key).toList());
  }

  Future<void> clear() async {
    for (final e in await all()) {
      await _remove(e);
    }
  }
}
```
UNVERIFIED: the "Delete everything" path must call `PendingProofs().clear()`. Find it: `cd app && grep -rn "Delete everything\|deleteEverything\|wipe" lib/app_state lib/features/account | head`; add one call in the function that clears local data, with its own test (`pending is empty after delete everything`). If the function is not found, write the question to QUESTIONS.md.
4. File `app/lib/features/instapay/presentation/payment_text.dart`. Add these cases to the `switch` (before `_ =>`):
```dart
    'txn_reused' => l10n.thisTransactionNumberWasAlreadyUsed,
    'image_rejected' => l10n.weCouldNotUseThatPicturePickAnother,
    'too_many_uploads' => l10n.youHaveSentTooManyPicturesForThisPayment,
```
(reason codes UNVERIFIED against WO-10b: `grep -n "txn_reused\|image_rejected\|too_many_uploads" functions/payments/*.py`; replace with the real strings the server raises.)
5. File `app/lib/features/instapay/presentation/proof_view.dart` (create). Full content:
```dart
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../data/pending_proofs.dart';
import '../data/proof_images.dart';
import '../domain/instapay_models.dart';
import '../domain/instapay_rules.dart';
import '../domain/receipt_reader.dart';
import 'payment_text.dart';
import 'proof_flow.dart';

/// Counsel may switch the optional "help improve" question off (spec 13.13 item 5).
const bool kAskLearnConsent = true;

class ProofView extends StatefulWidget {
  const ProofView({
    super.key,
    required this.payment,
    required this.onSent,
    this.repository,
    this.picker = pickProofImages,
    this.prepare = prepareProofImage,
    this.store,
    this.pending,
    this.now,
    this.addEvidence = false,
  });

  final Payment payment;
  final void Function(ProofResult? result, {required bool queued}) onSent;
  final InstapayRepository? repository;
  final Future<List<Uint8List>> Function() picker;
  final PrepareImage prepare;
  final InstapayLocalStore? store;
  final PendingProofs? pending;
  final DateTime Function()? now;

  /// PAY6: the same screen after a dispute.
  final bool addEvidence;

  @override
  State<ProofView> createState() => _ProofViewState();
}

class _ProofViewState extends State<ProofView> {
  final _txn = TextEditingController();
  final _handle = TextEditingController();
  final List<PreparedImage> _images = <PreparedImage>[];
  ReceiptReading? _reading;
  bool _edit = false;
  bool _needHandle = false;
  bool _busy = false;
  String _error = '';
  late final String _key = InstapayLocalStore.newKey();

  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;
  InstapayLocalStore get _store => widget.store ?? InstapayLocalStore();
  DateTime get _now => (widget.now ?? DateTime.now)();

  ExpectedPayment get _expected => ExpectedPayment(
    amountPiasters: widget.payment.amountPiasters,
    coachAddress: widget.payment.address.address,
    coachAccountName: widget.payment.address.accountName,
    createdAt: widget.payment.createdAt ?? _now,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final h = await _store.senderHandle();
    if (!mounted) return;
    setState(() {
      _handle.text = h;
      _needHandle = h.isEmpty;
    });
  }

  @override
  void dispose() {
    _txn.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() => _error = '');
    final raw = await widget.picker();
    if (!mounted || raw.isEmpty) return;
    final l10n = AppL10n.of(context);
    final got = <PreparedImage>[];
    for (final bytes in raw) {
      final p = await widget.prepare(context, bytes, _expected);
      if (!mounted) return;
      if (p == null) {
        setState(() => _error = l10n.thisPictureIsTooBigOrCouldNotBeReadPickAnother);
        continue;
      }
      got.add(p);
    }
    if (got.isEmpty) return;
    final reading = readReceipt(got.map((g) => g.text).toList(), _expected, _now);
    setState(() {
      _images
        ..clear()
        ..addAll(got);
      _reading = reading;
      if (reading.txnNumber != null) _txn.text = reading.txnNumber!;
      if (reading.txnNumber == null) _edit = true;
      if (_handle.text.isEmpty && reading.senderHandle != null) _handle.text = reading.senderHandle!;
    });
  }

  PhoneVerdict? get _verdict => _reading == null ? null : phoneVerdict(_reading!);

  bool get _ready =>
      _txn.text.trim().length >= 6 &&
      _handle.text.trim().isNotEmpty &&
      _verdict != PhoneVerdict.wrongMessage &&
      !_busy;

  Future<bool> _consent() async {
    if (!kAskLearnConsent || await _store.consentAsked() || !mounted) return await _store.learnConsent();
    final l10n = AppL10n.of(context);
    final yes = await showAppSheet<bool>(context: context, children: [
      Text(l10n.helpImproveReceiptReading, style: AppText.titleL),
      Text(l10n.weKeepOnlyTheTextFieldsWeReadNeverYourPicture, style: AppText.bodyM),
      AppButton(l10n.yesHelp, key: const ValueKey('consent-yes'), onPressed: () => Navigator.of(context).pop(true)),
      AppButton(l10n.noThanks, key: const ValueKey('consent-no'), variant: AppButtonVariant.text, onPressed: () => Navigator.of(context).pop(false)),
      const SizedBox(height: 12),
    ]);
    await _store.answerLearnConsent(yes == true);
    return yes == true;
  }

  Future<void> _send() async {
    final repo = _repo;
    if (repo == null || !_ready) return;
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = '';
    });
    final consent = await _consent();
    await _store.saveSenderHandle(_handle.text);
    final reading = <String, Object?>{...?_reading?.toJson(), 'learnConsent': consent};
    final paidAt = _reading?.timeSeen ?? _now;
    final bytes = <Uint8List>[for (final i in _images) i.png];
    try {
      final r = await repo.submitProof(
        paymentId: widget.payment.id, idempotencyKey: _key, txnNumber: _txn.text.trim(),
        paidAtClaimed: paidAt, senderHandle: _handle.text.trim(), images: bytes,
        phoneReading: reading, locale: locale, addEvidence: widget.addEvidence,
      );
      if (mounted) widget.onSent(r, queued: false);
    } on PaymentFailure catch (f) {
      if (f.unreachable) {
        await (widget.pending ?? PendingProofs()).add(
          PendingProof(
            paymentId: widget.payment.id, key: _key, txnNumber: _txn.text.trim(),
            paidAtClaimed: paidAt, senderHandle: _handle.text.trim(), phoneReading: reading,
            locale: locale, addEvidence: widget.addEvidence, files: const <String>[],
          ),
          bytes,
        );
        if (mounted) widget.onSent(null, queued: true);
      } else if (mounted) {
        setState(() => _error = paymentFailureText(l10n, f));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _hint(AppL10n l10n) => switch (_verdict) {
    PhoneVerdict.green => l10n.everythingMatchesTapSend,
    PhoneVerdict.amber => l10n.weCouldNotReadEverythingAddTheScreenshot,
    PhoneVerdict.red => l10n.thisDoesNotMatchYourPaymentYouCanStillSendIt,
    PhoneVerdict.wrongMessage => l10n.thisLooksLikeACardMessageNotAnInstapayTransferReceipt,
    null => '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final txn = _txn.text.trim();
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(title: l10n.sendYourProof, onBack: () => Navigator.of(context).maybePop()),
      children: [
        Text(l10n.addYourBankScreenshotsTheReceiptAndTheOne, style: AppText.bodyM),
        AppButton(l10n.chooseScreenshots, key: const ValueKey('choose'), variant: AppButtonVariant.outlined,
            onPressed: _busy ? null : () => unawaited(_choose())),
        AppCard(children: [
          Text('${l10n.amount}  ${egpText(widget.payment.amountPiasters, arabic: arabic)}', style: AppText.bodyM),
          Text('${l10n.transactionNumber}  ${txn.isEmpty ? l10n.notFoundYet : txn}', key: const ValueKey('txn-row'), textDirection: TextDirection.ltr, style: AppText.bodyM),
          if (_images.isNotEmpty) Text(l10n.countPicturesAdded(_images.length), style: AppText.bodyM),
        ]),
        if (!_edit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(l10n.edit, key: const ValueKey('edit'), variant: AppButtonVariant.text, height: 44, fontSize: 15,
                onPressed: () => setState(() => _edit = true)),
          ),
        if (_edit)
          AppField(controller: _txn, label: l10n.transactionNumber, keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr, onChanged: (_) => setState(() {})),
        if (_needHandle)
          AppField(
            controller: _handle, label: l10n.yourOwnInstapayAddress, textDirection: TextDirection.ltr,
            helper: looksLikePhone(_handle.text) ? l10n.aPhoneNumberWouldShowOnYourCoachSReceipt : l10n.weUseItToMatchYourReceiptAskedOnce,
            onChanged: (_) => setState(() {}),
          ),
        if (_hint(l10n).isNotEmpty) Text(_hint(l10n), key: const ValueKey('hint'), style: AppText.bodyM),
        if (_error.isNotEmpty)
          Semantics(liveRegion: true, child: Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error))),
      ],
      footer: [
        AppButton(l10n.sendToCoach, key: const ValueKey('send'), onPressed: _ready ? () => unawaited(_send()) : null),
      ],
    );
  }
}
```
Getter names are placeholders (use the printed ones). `...?_reading?.toJson()` needs Dart 3 null-aware spread (fine). UNVERIFIED: `import 'receipt_reader.dart'` also exports `PhoneVerdict` (yes, same file). `AppButton` for the "Choose screenshots" key param exists (`super.key`).
6. File `app/lib/routing/app_router.dart`. In the `'H05'` builder replace the line `onIHavePaid: (payment) {}, // WO-10e4 replaces this line` with:
```dart
                      onIHavePaid: (payment) => unawaited(
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (inner) => ProofView(
                              payment: payment,
                              onSent: (result, {required bool queued}) {
                                // WO-10e5 replaces this with PAY3.
                                Navigator.of(inner)
                                  ..pop()
                                  ..pop();
                              },
                            ),
                          ),
                        ),
                      ),
```
Add `import '../features/instapay/presentation/proof_view.dart';`. Also flush the queue when PAY1 opens: in `payment_view.dart` `_open()` first line add `unawaited(PendingProofs().flush(repo));` (import `../data/pending_proofs.dart`).

## Strings to add
File `app/tool/_wo10e4_strings.json`; drop keys already present (`Edit`, `Amount` likely exist). Parameterised: `{count} pictures added` with `count` `int` example `2` (use `"type": "int"`; ICU plural is not needed: write "pictures added" with a number, but check how `countPluralOne1...` strings are done in `6-v2/src/build-flutter.mjs` PARAMETERISED and copy a plural form if the file requires one).
| English (key) | Egyptian Arabic |
|---|---|
| Send your proof | ابعتي إثبات الدفع |
| Add your bank screenshots: the receipt, and the one with More Details open. | ضيفي لقطات شاشة البنك: الإيصال، واللي فاتح فيها More Details. |
| Choose screenshots | اختاري لقطات الشاشة |
| Amount | المبلغ |
| Transaction number | رقم العملية |
| Not found yet | لسه ماتلاقاش |
| {count} pictures added | اتضاف {count} صور |
| Edit | عدّلي |
| Your own InstaPay address | عنوان إنستا باي بتاعك |
| We use it to match your receipt. Asked once. | بنستخدمه عشان نطابق الإيصال. بنسألك مرة واحدة. |
| A phone number would show on your coach's receipt. Use your @ address if you have one. | الرقم هيظهر في إيصال مدرّبتك. استخدمي عنوانك اللي فيه @ لو عندك. |
| Send to coach | ابعتي لمدرّبتك |
| Everything matches. Tap send. | كل حاجة مطابقة. اضغطي ابعتي. |
| We could not read everything. Add the screenshot with More Details open, or type the transaction number. | مقدرناش نقرا كل حاجة. ضيفي لقطة فيها More Details مفتوحة، أو اكتبي رقم العملية. |
| This does not match your payment. You can still send it and Own Hub will check. | ده مش مطابق لدفعتك. تقدري تبعتيه برضه وOwn Hub هتراجعه. |
| This looks like a card message, not an InstaPay transfer receipt. Please send the transfer receipt. | ده شكله رسالة كارت، مش إيصال تحويل إنستا باي. ابعتي إيصال التحويل. |
| Saved. We will send it when you have signal. | اتحفظ. هنبعته أول ما يبقى فيه إشارة. |
| Help improve receipt reading? | تساعدي نحسّن قراءة الإيصالات؟ |
| We keep only the text fields we read, never your picture. You can say no. | هنحتفظ بالحقول المقروءة بس، مش بصورتك. وتقدري تقولي لأ. |
| Yes, help | أيوه، هساعد |
| No thanks | لأ شكرًا |
| This transaction number was already used. | رقم العملية ده اتستخدم قبل كده. |
| We could not use that picture. Pick another. | مقدرناش نستخدم الصورة دي. اختاري صورة تانية. |
| You have sent too many pictures for this payment. | بعتي صور كتير أوي للدفع ده. |
The "Saved" line is shown by the router callback (step 6 shows no text; add to the `onSent` body: when `queued` is true call `ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(AppL10n.of(context).savedWeWillSendItWhenYouHaveSignal)))` before the pops).

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| proof_view_test.dart | `a green reading fills the number and enables send` | fake picker returns one `Uint8List(4)`; fake `prepare` returns `PreparedImage(png, text)` where text is the HSBC-like sample from WO-10e2 (receipt + details); pump `ProofView(payment: p, ...)`; tap `choose`; `txn-row` shows `123456789012`; hint is the "Everything matches" sentence; `send` enabled once the handle field has text |
| same | `no number found opens the field and keeps send off` | prepare returns text without a number; the txn field is shown; send disabled; type `123456` and a handle; enabled |
| same | `a card alert disables send` | prepare returns the card alert text; hint is the card sentence; send disabled |
| same | `amber and red keep send enabled` | amber text (receipt only + typed number); red text (450.00); both enable send |
| same | `the saved handle hides the handle field` | `SharedPreferences.setMockInitialValues({'instapay.senderHandle': 'me@instapay'})`; no handle field |
| same | `a phone number as handle shows the warning` | type `01012345678`; helper is the warning sentence; send still enabled |
| same | `send calls the repository once with the same key on a second tap` | tap send twice quickly (second while busy): `fake.calls` has one `submitProof`; the key is 24 hex |
| same | `no signal queues the proof and tells the caller` | `fake.failNext = PaymentFailure('', unreachable: true)`; `onSent(null, queued: true)`; `PendingProofs(dir: tmp).all()` has one entry with the same key |
| same | `the first send asks the question once` | `kAskLearnConsent` true; tap send; the sheet appears; tap `consent-no`; second `ProofView` does not show it |
| same | `budget: 390x844, 375x667, EN and AR, 200 percent` | `countControlsAboveFold(tester, includeChrome:false) <= 5` in the default state and with Edit open and the handle field; `filledPrimaryActions == 1` |
| pending_proofs_test.dart | `add then flush sends with the stored key and deletes the files` | `Directory.systemTemp.createTempSync()`; add one proof with 2 images; `flush(fake)`; `fake.calls.single` key equals; files gone; `all()` empty |
| same | `no signal stops the flush and keeps everything` | `failNext` unreachable; `flush` returns 0; entry kept |
| same | `a permanent refusal drops the entry` | `failNext = PaymentFailure('txn_reused')`; `all()` empty after |
| same | `adding the same key twice keeps one` | length 1 |
| same | `clear removes entries and files` | empty |
Run: `cd app && flutter test test/features/instapay`

## Verify
- `cd app && dart analyze lib/features/instapay lib/routing/app_router.dart` ends `No issues found!`
- `cd app && flutter test test/features/instapay` ends `All tests passed!`
- Manual on the Android emulator `ownhub_pixel8` with a staging project: PAY1 to "I have paid", choose the HSBC-style sample from `app/test/fixtures/instapay/` (WO-10k2), see the filled number, send; airplane mode: see the queued line; turn it off, open PAY1: the queue flushes.

## Do not
- Do not let an amber or red phone result stop her from sending (the server decides). Only the card-message result disables send.
- Do not store the OCR text or the pictures after a successful send.
- Do not use the phone clock as proof: it is only `paidAtClaimed`.
- Do not send the receipt text, only `toJson()` of the reading.

## Done checklist
- [ ] PAY2, flow, queue, store change, text mapper, router wiring
- [ ] "Delete everything" clears the queue (or a QUESTIONS.md entry)
- [ ] strings and getters; tests pass EN and AR

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10f1).

UNVERIFIED in this order: 4 (server reason codes, delete-everything hook, plural form for the picture count, `app/test/fixtures/instapay/` comes from WO-10k2).
