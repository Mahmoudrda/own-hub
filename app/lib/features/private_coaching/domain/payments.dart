/// The money pages: where she pays, what she sends, the seller, the receipt.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'coach_application.dart' show referenceMatchesRail;
import 'coaching_contract.dart';
import 'parse.dart';
import 'pricing.dart';
import 'session_link.dart' show wireTime;

/// One Own Hub account a client can pay to.
class ReceivingAccount {
  const ReceivingAccount({
    this.address = '',
    this.holderName = '',
    this.enabled = false,
  });

  final String address;
  final String holderName;
  final bool enabled;

  bool get usable => enabled && address.isNotEmpty;

  factory ReceivingAccount.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return ReceivingAccount(
      address: readString(map['address']),
      holderName: readString(map['holderName']),
      enabled: readBool(map['enabled']),
    );
  }
}

/// `coachingConfig/receivingAccounts`, and the copy on a subscription (`payTo`).
class ReceivingAccounts {
  const ReceivingAccounts({
    this.instapay = const ReceivingAccount(),
    this.vodafoneCash = const ReceivingAccount(),
    this.version = 0,
  });

  final ReceivingAccount instapay;
  final ReceivingAccount vodafoneCash;
  final int version;

  ReceivingAccount? forRail(String rail) => switch (rail) {
    'instapay' => instapay,
    'vodafoneCash' => vodafoneCash,
    _ => null,
  };

  /// Rails she can pay by right now, in the contract's order.
  List<String> get usableRails => <String>[
    for (final rail in CoachingRails.names)
      if (forRail(rail)?.usable ?? false) rail,
  ];

  bool get isEmpty => usableRails.isEmpty;

  factory ReceivingAccounts.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return ReceivingAccounts(
      instapay: ReceivingAccount.fromMap(map['instapay']),
      vodafoneCash: ReceivingAccount.fromMap(map['vodafoneCash']),
      version: readInt(map['version']),
    );
  }
}

/// `coachingConfig/seller`: who she is buying from, shown at checkout.
class SellerDetails {
  const SellerDetails({
    this.companyNameEn = '',
    this.companyNameAr = '',
    this.addressEn = '',
    this.addressAr = '',
    this.commercialRegistration = '',
    this.taxCard = '',
    this.vatRatePercent = 0,
    this.supportEmail = '',
    this.supportPhone = '',
  });

  final String companyNameEn;
  final String companyNameAr;
  final String addressEn;
  final String addressAr;
  final String commercialRegistration;
  final String taxCard;
  final int vatRatePercent;
  final String supportEmail;
  final String supportPhone;

  String companyName({required bool arabic}) =>
      arabic && companyNameAr.isNotEmpty ? companyNameAr : companyNameEn;

  String address({required bool arabic}) =>
      arabic && addressAr.isNotEmpty ? addressAr : addressEn;

  /// Checkout needs the name, an address and both registration numbers.
  bool get complete =>
      companyNameEn.isNotEmpty &&
      addressEn.isNotEmpty &&
      commercialRegistration.isNotEmpty &&
      taxCard.isNotEmpty;

  factory SellerDetails.fromMap(Object? raw) {
    final map = asMap(raw) ?? const <String, Object?>{};
    return SellerDetails(
      companyNameEn: readString(map['companyNameEn']),
      companyNameAr: readString(map['companyNameAr']),
      addressEn: readString(map['addressEn']),
      addressAr: readString(map['addressAr']),
      commercialRegistration: readString(map['commercialRegistration']),
      taxCard: readString(map['taxCard']),
      vatRatePercent: readInt(map['vatRatePercent']),
      supportEmail: readString(map['supportEmail']),
      supportPhone: readString(map['supportPhone']),
    );
  }
}

class RefundInfo {
  const RefundInfo({this.amountEgp = 0, this.rail = '', this.at});

  final int amountEgp;
  final String rail;
  final DateTime? at;

  /// Null when there is no refund. The reference is staff's and not read here.
  static RefundInfo? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null || map.isEmpty) return null;
    return RefundInfo(
      amountEgp: readInt(map['amountEgp']),
      rail: readString(map['rail']),
      at: readTime(map['at']),
    );
  }
}

/// `receipts/{subId}`.
class Receipt {
  const Receipt({
    required this.subId,
    this.number = '',
    this.seller = const SellerDetails(),
    this.line = const <String, String>{},
    this.coachName = '',
    this.priceFinalEgp = 0,
    this.vatRatePercent = 0,
    this.vatEgp = 0,
    this.issuedAt,
    this.refund,
  });

  final String subId;
  final String number;
  final SellerDetails seller;

  /// The line item by language (`en`, `ar`).
  final Map<String, String> line;
  final String coachName;
  final int priceFinalEgp;
  final int vatRatePercent;
  final int vatEgp;
  final DateTime? issuedAt;
  final RefundInfo? refund;

  String lineFor({required bool arabic}) =>
      line[arabic ? 'ar' : 'en'] ?? line['en'] ?? line['ar'] ?? '';

  static Receipt? fromMap(String subId, Object? raw) {
    final map = asMap(raw);
    if (map == null || subId.isEmpty) return null;
    final number = readString(map['number']);
    if (number.isEmpty) return null;
    final line = map['line'];
    final lineMap = asMap(line);
    return Receipt(
      subId: subId,
      number: number,
      seller: SellerDetails.fromMap(map['seller']),
      line: <String, String>{
        if (line is String) 'en': line,
        if (lineMap != null)
          for (final entry in lineMap.entries)
            if (entry.value is String) entry.key: entry.value as String,
      },
      coachName: readString(map['coachName']),
      priceFinalEgp: readInt(map['priceFinalEgp']),
      vatRatePercent: readInt(map['vatRatePercent']),
      vatEgp: readInt(map['vatEgp']),
      issuedAt: readTime(map['issuedAt']),
      refund: RefundInfo.fromMap(map['refund']),
    );
  }
}

/// What the form on H04 can get wrong.
enum PaymentProofProblem { rail, reference, amount, paidAt, senderName, image }

/// "I've paid": the screenshot and the details staff check it against.
class PaymentProofForm {
  const PaymentProofForm({
    this.rail = '',
    this.reference = '',
    this.amountEgp = 0,
    this.paidAt,
    this.senderName = '',
    this.imageJpeg,
  });

  final String rail;
  final String reference;
  final int amountEgp;
  final DateTime? paidAt;
  final String senderName;
  final Uint8List? imageJpeg;

  /// How far ahead of her phone's clock a payment time may be.
  static const Duration clockSkew = Duration(minutes: 5);

  /// How far back a payment time may be.
  static const Duration oldestPayment = Duration(days: 7);

  static const int senderNameMax = 80;

  /// The ceiling for a typed amount: the dearest package.
  static int get amountMax => finalPrice(CoachingLimits.coachPriceMaxEgp);

  /// What is wrong with the form, as the server would see it.
  List<PaymentProofProblem> problems(DateTime now) {
    final out = <PaymentProofProblem>[];
    if (!CoachingRails.names.contains(rail)) out.add(PaymentProofProblem.rail);
    if (!referenceMatchesRail(rail, reference.trim())) {
      out.add(PaymentProofProblem.reference);
    }
    if (amountEgp < 1 || amountEgp > amountMax) {
      out.add(PaymentProofProblem.amount);
    }
    final at = paidAt;
    if (at == null ||
        at.isAfter(now.add(clockSkew)) ||
        at.isBefore(now.subtract(oldestPayment))) {
      out.add(PaymentProofProblem.paidAt);
    }
    final name = senderName.trim();
    if (name.length < 2 || name.length > senderNameMax) {
      out.add(PaymentProofProblem.senderName);
    }
    final image = imageJpeg;
    if (image == null ||
        image.isEmpty ||
        image.length > CoachingLimits.proofMaxBytes) {
      out.add(PaymentProofProblem.image);
    }
    return out;
  }

  bool isValid(DateTime now) => problems(now).isEmpty;

  /// The body of `submit_payment_proof`. The picture travels as base64.
  Json toRequest({required String subId, required String locale}) =>
      <String, Object?>{
        'subId': subId,
        'rail': rail,
        'reference': reference.trim(),
        'amountEgp': amountEgp,
        'paidAt': paidAt == null ? null : wireTime(paidAt!),
        'senderName': senderName.trim(),
        'imageJpeg': base64Encode(imageJpeg ?? Uint8List(0)),
        'locale': locale,
      };
}
