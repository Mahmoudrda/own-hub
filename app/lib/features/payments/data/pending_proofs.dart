library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'payments_repository.dart';

class PendingProof {
  const PendingProof({
    required this.paymentId,
    required this.key,
    required this.amountPiasters,
    required this.txnNumber,
    required this.senderHandle,
    required this.paidAtClaimed,
    required this.phoneReading,
    required this.otherPayerOk,
    required this.files,
  });
  final String paymentId;
  final String key;
  final int amountPiasters;
  final String? txnNumber;
  final String? senderHandle;
  final DateTime? paidAtClaimed;
  final Map<String, Object?> phoneReading;
  final bool otherPayerOk;
  final List<String> files;

  Map<String, Object?> toJson() => <String, Object?>{
    'paymentId': paymentId,
    'key': key,
    'amount': amountPiasters,
    'txn': txnNumber,
    'handle': senderHandle,
    'paidAt': paidAtClaimed?.toUtc().toIso8601String(),
    'reading': phoneReading,
    'other': otherPayerOk,
    'files': files,
  };

  static PendingProof? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final paymentId = '${raw['paymentId']}';
    final key = '${raw['key']}';
    final amount = raw['amount'];
    if (paymentId.isEmpty || key.isEmpty || amount is! int) return null;
    return PendingProof(
      paymentId: paymentId,
      key: key,
      amountPiasters: amount,
      txnNumber: raw['txn'] as String?,
      senderHandle: raw['handle'] as String?,
      paidAtClaimed: DateTime.tryParse('${raw['paidAt']}'),
      phoneReading: Map<String, Object?>.from(
        (raw['reading'] as Map?) ?? const {},
      ),
      otherPayerOk: raw['other'] == true,
      files: <String>[
        for (final f in (raw['files'] as List? ?? const [])) '$f',
      ],
    );
  }
}

/// Proofs that could not be sent for want of signal. They stay on this phone
/// only: the list in shared preferences, the pictures (already hidden-detail
/// copies) as files in the app support folder. A proof is removed when sent,
/// and everything by [clear] ("Delete everything"). The same key goes out
/// again, so a retry never makes a second payment.
class PendingProofs {
  PendingProofs({Directory? dir}) : _dirOverride = dir;
  final Directory? _dirOverride;
  static const _k = 'payments.pendingProofs';

  Future<Directory> _folder() async {
    final base =
        _dirOverride ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/payments-pending',
        );
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
    if (list.isEmpty) {
      await p.remove(_k);
    } else {
      await p.setString(
        _k,
        jsonEncode(<Object?>[for (final e in list) e.toJson()]),
      );
    }
  }

  /// The same key replaces the earlier entry (a retry never doubles).
  Future<void> add(PendingProof proof, List<Uint8List> images) async {
    final old = (await all()).where((e) => e.key == proof.key).toList();
    for (final o in old) {
      await _deleteFiles(o);
    }
    final dir = await _folder();
    final files = <String>[];
    for (var n = 0; n < images.length; n++) {
      final f = File('${dir.path}/${proof.key}-$n.png');
      await f.writeAsBytes(images[n], flush: true);
      files.add(f.path);
    }
    final kept = (await all()).where((e) => e.key != proof.key).toList()
      ..add(
        PendingProof(
          paymentId: proof.paymentId,
          key: proof.key,
          amountPiasters: proof.amountPiasters,
          txnNumber: proof.txnNumber,
          senderHandle: proof.senderHandle,
          paidAtClaimed: proof.paidAtClaimed,
          phoneReading: proof.phoneReading,
          otherPayerOk: proof.otherPayerOk,
          files: files,
        ),
      );
    await _save(kept);
  }

  /// Sends what waits, oldest first. Stops at the first "no signal". A
  /// refusal the server will always repeat drops that entry. Returns how
  /// many went.
  Future<int> flush(PaymentsRepository repo) async {
    var sent = 0;
    for (final e in await all()) {
      try {
        final images = <Uint8List>[
          for (final f in e.files) await File(f).readAsBytes(),
        ];
        await repo.submitProof(
          paymentId: e.paymentId,
          idempotencyKey: e.key,
          amountPiasters: e.amountPiasters,
          images: images,
          txnNumber: e.txnNumber,
          senderHandle: e.senderHandle,
          paidAtClaimed: e.paidAtClaimed,
          phoneReading: e.phoneReading,
          otherPayerOk: e.otherPayerOk,
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

  Future<void> _deleteFiles(PendingProof e) async {
    for (final f in e.files) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
  }

  Future<void> _remove(PendingProof e) async {
    await _deleteFiles(e);
    await _save((await all()).where((x) => x.key != e.key).toList());
  }

  /// "Delete everything": the list and every picture. Touches the file system
  /// only when something was queued, so a wipe with nothing waiting costs no
  /// platform call.
  Future<void> clear() async {
    final queued = await all();
    if (queued.isEmpty) return;
    for (final e in queued) {
      await _deleteFiles(e);
    }
    await _save(const <PendingProof>[]);
    try {
      final base = await _folder();
      if (await base.exists()) await base.delete(recursive: true);
    } catch (_) {}
  }
}
