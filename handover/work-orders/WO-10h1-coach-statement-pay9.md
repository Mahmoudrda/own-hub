# WO-10h1: PAY9, the coach's monthly fee statement
Depends on: WO-10f1; server WO-10c (statements, `generate_fee_statements`) and the `mark_fee_statement_paid` callable (INDEX Q3)
Size: M
Reads first: `app/lib/features/instapay/presentation/coach_payments_view.dart`; `app/lib/features/instapay/domain/instapay_models.dart` (`FeeStatement`); `app/lib/features/instapay/presentation/client_paid_sheet.dart`; `DECISIONS.md` lines 707-714 (D63); spec 4.13

## Why
Own Hub's fee is owed from the moment a client's package becomes active (spec 13.1). The coach pays it by InstaPay to Own Hub and records it; the owner confirms in the dashboard. She needs one clear page: each payment, the fee, the total, and where to pay. A coach more than 30 days late cannot take new clients; existing clients are never cut off. The app never debits anything.

## Final result
PAY4's "..." menu gets "Monthly statement" / "كشف الشهر". It opens PAY9, top to bottom:
1. Top bar "Monthly statement", back arrow.
2. A card for the latest statement: "Fee for {month}" / "الرسوم عن شهر {month}", the total large (`150 EGP`), and "{count} payments" / "{count} دفعات".
3. Lines, one per payment (plain rows, not controls): reference, amount, fee; a line whose payment is in a dispute shows "disputed, pending" / "متنازع عليها، مستنية القرار".
4. If unpaid: "Pay Own Hub's fee by InstaPay to:" / "ادفعي رسوم Own Hub بإنستا باي على:", the address (left to right) with a "Copy" text button, and the line "Fees unpaid for more than 30 days stop new clients. Your current clients are never cut off." / "الرسوم اللي عدّى عليها أكتر من 30 يوم بتوقف العميلات الجداد. عميلاتك الحاليين عمرهم ما بيتقطعوا."
5. Earlier months: adjacent rows (one control group), each `2026-09, 120 EGP, paid`.
6. Footer, the one primary, only when unpaid and the total is more than zero: "Mark fee as paid" / "سجّلي إن الرسوم اتدفعت". It opens a sheet: field "Transaction number" and primary "Send"; success line "Recorded. Own Hub will confirm it." / "اتسجّلت. Own Hub هتأكدها." and the card then shows "Paid. Own Hub will confirm." / "اتدفعت. Own Hub هتأكدها."
7. Empty: "No statement yet. The first one comes on the 1st of next month." / "لسه مفيش كشف. أول كشف بيجي يوم 1 الشهر الجاي."
Controls above the fold: back, Copy, earlier group = 3 others + 1 primary.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/instapay/domain/instapay_models.dart | edit | statement lines and pay-to |
| app/lib/features/instapay/data/firestore_instapay_repository.dart | no change | `watchMyStatements` already parses via `FeeStatement.fromMap` |
| app/lib/features/instapay/presentation/fee_statement_view.dart | create | PAY9 |
| app/lib/features/instapay/presentation/coach_payments_view.dart | edit | the menu item |
| app/test/features/instapay/fee_statement_view_test.dart | create | tests |

## Steps
1. File `instapay_models.dart`. Replace the `FeeStatement` class by:
```dart
class FeeLine {
  const FeeLine({this.reference = '', this.amountPiasters = 0, this.feePiasters = 0, this.disputed = false});
  final String reference;
  final int amountPiasters;
  final int feePiasters;
  final bool disputed;
}

class FeeStatement {
  const FeeStatement({
    required this.id,
    this.month = '',
    this.totalFeePiasters = 0,
    this.lines = const <FeeLine>[],
    this.paid = false,
    this.markedPaid = false,
    this.payToAddress = '',
    this.payToName = '',
  });
  final String id;
  final String month;
  final int totalFeePiasters;
  final List<FeeLine> lines;

  /// Own Hub confirmed it.
  final bool paid;

  /// She recorded it; Own Hub has not confirmed yet.
  final bool markedPaid;
  final String payToAddress;
  final String payToName;

  int get paymentCount => lines.length;

  static FeeStatement? fromMap(String id, Object? raw) {
    final m = asMap(raw);
    if (m == null || id.isEmpty) return null;
    final to = asMap(m['payTo']) ?? const <String, Object?>{};
    final status = readString(m['status']);
    return FeeStatement(
      id: id,
      month: readString(m['month']),
      totalFeePiasters: readInt(m['totalFeePiasters']),
      lines: <FeeLine>[
        for (final l in readMaps(m['lines']))
          FeeLine(
            reference: readString(l['reference']),
            amountPiasters: readInt(l['amountPiasters']),
            feePiasters: readInt(l['feePiasters']),
            disputed: readString(l['status']) == 'disputed',
          ),
      ],
      paid: status == 'paid',
      markedPaid: status == 'marked_paid',
      payToAddress: readString(to['address']),
      payToName: readString(to['accountName']),
    );
  }
}
```
(UNVERIFIED field names `lines[].reference`, `status` values `paid`, `marked_paid`, `disputed`, and `payTo`: compare with WO-10c.) The WO-10d0 test file used `paymentCount`; it still works.
2. File `fee_statement_view.dart` (create):
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/instapay_models.dart';
import 'payment_text.dart';

class FeeStatementView extends StatefulWidget {
  const FeeStatementView({super.key, this.repository, this.onBack});
  final InstapayRepository? repository;
  final VoidCallback? onBack;

  @override
  State<FeeStatementView> createState() => _FeeStatementViewState();
}

class _FeeStatementViewState extends State<FeeStatementView> {
  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;

  Future<void> _mark(FeeStatement s) async {
    final repo = _repo;
    if (repo == null) return;
    final l10n = AppL10n.of(context);
    final txn = TextEditingController();
    final key = InstapayLocalStore.newKey();
    var error = '';
    var busy = false;
    final done = await showAppSheet<bool>(
      context: context,
      children: [
        StatefulBuilder(builder: (context, set) {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.markFeeAsPaid, style: AppText.titleL),
            AppField(controller: txn, label: l10n.transactionNumber, keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr, onChanged: (_) => set(() {})),
            if (error.isNotEmpty) Text(error, style: AppText.bodyM.copyWith(color: AppColors.error)),
            const SizedBox(height: 8),
            AppButton(l10n.send, key: const ValueKey('fee-send'),
                onPressed: txn.text.trim().length < 6 || busy
                    ? null
                    : () async {
                        set(() { busy = true; error = ''; });
                        try {
                          await repo.markFeePaid(statementId: s.id, txnNumber: txn.text.trim(), key: key);
                          if (context.mounted) Navigator.of(context).pop(true);
                        } on PaymentFailure catch (f) {
                          set(() { busy = false; error = paymentFailureText(l10n, f); });
                        }
                      }),
            const SizedBox(height: 12),
          ]);
        }),
      ],
    );
    txn.dispose();
    if (done == true && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.recordedOwnHubWillConfirmIt)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final repo = _repo;
    return StreamBuilder<List<FeeStatement>>(
      stream: repo?.watchMyStatements(),
      builder: (context, snap) {
        final all = snap.data ?? const <FeeStatement>[];
        final latest = all.isEmpty ? null : all.first;
        final unpaid = latest != null && !latest.paid && !latest.markedPaid && latest.totalFeePiasters > 0;
        return AppScaffold(
          showArt: false,
          appBar: AppTopBar(title: l10n.monthlyStatement, onBack: widget.onBack ?? () => Navigator.of(context).maybePop()),
          children: [
            if (latest == null) AppSageNote(l10n.noStatementYetTheFirstOneComesOnThe1stOfNextMonth),
            if (latest != null) ...[
              AppCard(children: [
                Text(l10n.feeForMonth(latest.month), style: AppText.bodyM),
                Text(egpText(latest.totalFeePiasters, arabic: arabic), key: const ValueKey('fee-total'), style: AppText.titleL),
                Text(l10n.countPayments(latest.paymentCount), style: AppText.bodyM),
                if (latest.paid || latest.markedPaid) Text(l10n.paidOwnHubWillConfirm, key: const ValueKey('fee-paid'), style: AppText.titleM),
              ]),
              for (final line in latest.lines)
                Text(
                  '${line.reference}  ${egpText(line.amountPiasters, arabic: arabic)}  ${egpText(line.feePiasters, arabic: arabic)}'
                  '${line.disputed ? '  ${l10n.disputedPending}' : ''}',
                  style: AppText.bodyM,
                ),
              if (unpaid) ...[
                Text(l10n.payOwnHubSFeeByInstapayTo, style: AppText.bodyM),
                Text(latest.payToAddress, textDirection: TextDirection.ltr, style: AppText.titleM),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton(l10n.copy, key: const ValueKey('copy-fee-address'), variant: AppButtonVariant.text, height: 44, fontSize: 15,
                      onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: latest.payToAddress)))),
                ),
                Text(l10n.feesUnpaidForMoreThan30DaysStopNewClients, style: AppText.bodyM),
              ],
              for (final s in all.skip(1))
                AppListItem(
                  key: ValueKey('month-${s.id}'),
                  title: s.month,
                  subtitle: '${egpText(s.totalFeePiasters, arabic: arabic)}${s.paid ? ', ${l10n.paid}' : ''}',
                ),
            ],
          ],
          footer: [
            if (unpaid) AppButton(l10n.markFeeAsPaid, key: const ValueKey('mark-fee'), onPressed: () => unawaited(_mark(latest))),
          ],
        );
      },
    );
  }
}
```
3. File `coach_payments_view.dart`. In the `AppOverflowMenu(items: [...])` list, before `...widget.extraMenu,` add:
```dart
            AppOverflowItem(
              icon: Icons.receipt_long_outlined,
              label: l10n.monthlyStatement,
              onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const FeeStatementView())),
            ),
```
and `import 'fee_statement_view.dart';`.

## Strings to add
File `app/tool/_wo10h1_strings.json`; drop existing keys (`Paid`, `Copy`). Parameterised: `Fee for {month}` (month String `2026-10`); `{count} payments` (count int).
Use every English and Arabic pair in "Final result" and: `Monthly statement` / `كشف الشهر`; `Paid` / `اتدفع`; `Total fee` / `إجمالي الرسوم`.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| fee_statement_view_test.dart | `shows the total, the lines and where to pay` | `fake.statements = [FeeStatement(...two lines, payToAddress: 'ownhub@instapay')]`; texts found |
| same | `a disputed line says so` | |
| same | `mark fee as paid sends the transaction number once` | tap `mark-fee`; type `123456`; tap `fee-send`; `fake.calls.last.$1 == 'markFeePaid'` |
| same | `paid or marked-paid hides the primary and the pay-to block` | |
| same | `empty state` | no statements: note found, no primary |
| same | `earlier months are listed` | second statement row key `month-...` |
| same | `FeeStatement.fromMap reads status paid, marked_paid, lines` | pure parse |
| same | `budget at both sizes, EN and AR, 200 percent` | `<= 5` others, `filledPrimaryActions <= 1` |
Run: `cd app && flutter test test/features/instapay/fee_statement_view_test.dart test/features/instapay/instapay_models_test.dart`

## Verify
- `cd app && dart analyze lib/features/instapay` ends `No issues found!`; the test command ends `All tests passed!`

## Do not
- Do not debit, collect or confirm anything from the app: "Mark fee as paid" only records her claim.
- Do not hide the statement from a coach who is late; only new-client rules are the server's.
- Do not show any client's name or contact on the statement.

## Done checklist
- [ ] model, PAY9, menu item, strings, tests

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10h2).

UNVERIFIED in this order: 1 (statement field names).
