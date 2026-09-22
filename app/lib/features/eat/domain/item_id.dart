/// Identity for a logged meal item, and why there are two ways to make one.
///
/// HANDOFF rule 3 turns on a single distinction: **re-logging a planned meal
/// corrects it, and "another helping" is a second item.** G5 §1.4 keeps those
/// apart structurally rather than by a flag, and this file is where that
/// structure starts — one function that is deterministic, one that is not.
///
///   * [plannedItemId] hashes the plan reference, so logging the same planned
///     meal twice produces the *same* id both times. The write then removes the
///     old entry and unions the new one, which replaces rather than appends.
///   * [freshItemId] mints a new id every call, so a helping and a free log can
///     never collide with what is already in the slot.
///
/// There is deliberately no third function that takes a "correct or append?"
/// parameter. A boolean there is exactly how the two intents collapse into one
/// code path, which is the failure `P0-LOG-10` exists to catch.
///
/// ## Why SHA-1, and why that is not a security claim
///
/// G5 §1.4 and §1.1 specify `sha1` for both `itemId` and `plateId`. Nothing here
/// is a security boundary — these are content-addressed map keys, chosen so that
/// two of her own devices, offline, independently produce the same key for the
/// same plate. What matters is that the function is **stable across devices and
/// across releases**, which rules out `Object.hashCode` (documented as varying
/// between runs) and rules out anything seeded by the platform.
///
/// The ids are truncated to the widths the plan names — 16 hex characters for a
/// plate, 12 for a grocery line — because they are keys inside a document that
/// is capped at 40 plates and 120 grocery lines. At those sizes a collision is
/// not a practical concern, and a shorter key is a smaller document.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A monotonic counter behind [freshItemId], so two helpings logged in the same
/// millisecond still differ.
///
/// The timestamp alone is not enough: `DateTime.now()` has millisecond
/// resolution on some platforms, and "tap Log, tap Another helping" is well
/// inside one millisecond when the taps are synthesised by a test.
int _mintCounter = 0;

/// A deterministic id for an item logged **from the plan**.
///
/// The same plan reference always produces the same id, on any device, in any
/// release. That is what makes re-logging a correction: the write removes the
/// entry carrying this id and unions the replacement, so the slot still holds
/// one item rather than two.
///
/// [assignmentId] is the plan assignment's `yyyy-MM-dd` key, [slot] the meal
/// slot, [index] the position within that slot's prescription.
String plannedItemId({
  required String assignmentId,
  required String slot,
  required int index,
}) {
  final digest = sha1.convert(utf8.encode('$assignmentId|$slot|$index'));
  return digest.toString().substring(0, 16);
}

/// A fresh id, for a second helping or a free log.
///
/// Never derived from the food, the slot or the day — two helpings of the same
/// dish in the same slot are two items, and deriving the id from their content
/// would silently merge them back into one.
String freshItemId() {
  final seed = '${DateTime.now().microsecondsSinceEpoch}-${_mintCounter++}';
  return sha1.convert(utf8.encode(seed)).toString().substring(0, 16);
}

/// The id of a plate in the suggestion rollup — G5 §1.1.
///
/// `sha1(sorted(foodId + ':' + size).join('|'))`, truncated to 16. Deterministic
/// and **order-independent**: koshari + eggs and eggs + koshari are the same
/// plate, so the same combination logged on a phone and on a tablet lands on one
/// key instead of two.
String plateIdOf(Iterable<({String foodId, String size})> items) {
  final parts = [for (final i in items) '${i.foodId}:${i.size}']..sort();
  return sha1.convert(utf8.encode(parts.join('|'))).toString().substring(0, 16);
}

/// The id of one line on the grocery list — G5 §1.1.
///
/// `sha1(ingredientId + ':' + unit)`, truncated to 12, so a tick made on two
/// devices converges on one key rather than ticking two separate lines.
String groceryItemKey({required String ingredientId, required String unit}) {
  return sha1
      .convert(utf8.encode('$ingredientId:$unit'))
      .toString()
      .substring(0, 12);
}
