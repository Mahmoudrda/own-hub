/// How a write is described before it reaches the network.
///
/// Firestore's documented offline behaviour resolves conflicting changes to the
/// same document by **last write wins**, and that is the only strategy it offers.
/// For anything two devices can touch, last-write-wins silently loses data: two
/// women — or one woman on a phone and a tablet — logging into the same meal slot
/// would have one overwrite the other's array.
///
/// So writes are not expressed as "here is the new document". They are expressed
/// as an *intent*: which field, and how it combines with what is already there.
/// Commutative operations ([MergeStrategy.arrayUnion], [MergeStrategy.increment])
/// are safe to apply in any order; [MergeStrategy.lastWriteWins] is used only for
/// scalars with a single writer, where it is correct rather than convenient.
library;

import 'package:meta/meta.dart';

/// How this write combines with the value already stored.
enum MergeStrategy {
  /// Replace. Correct only when one device can own the value — her goal, her
  /// language. Never for anything two devices can append to.
  lastWriteWins,

  /// Add to a set, ignoring duplicates. Two devices appending different items to
  /// the same meal slot both survive; the same item twice collapses to one.
  arrayUnion,

  /// Add to a counter. Commutative — but **not idempotent**, which is why
  /// [WriteIntent.dedupeKey] is mandatory for this strategy.
  increment,
}

/// A single pending write.
@immutable
class WriteIntent {
  /// Creates an intent, defaulting its identity to the field it targets.
  ///
  /// Split from the generative constructor below so that one can be `const`: the
  /// default identity interpolates runtime values, which a const initialiser
  /// cannot do.
  factory WriteIntent({
    required String path,
    required String field,
    required Object? value,
    required MergeStrategy strategy,
    String? dedupeKey,
  }) {
    assert(
      strategy != MergeStrategy.increment || dedupeKey != null,
      'An increment needs an explicit dedupeKey. Increments are commutative '
      'but not idempotent: replayed on reconnect, the same increment adds '
      'twice. The key must identify the EVENT — an awardId, a weekId — not '
      'the field, so a replay collides with itself instead of paying out '
      'again. Spine C4.',
    );
    return WriteIntent._(
      path: path,
      field: field,
      value: value,
      strategy: strategy,
      dedupeKey: dedupeKey ?? '$path#$field',
    );
  }

  const WriteIntent._({
    required this.path,
    required this.field,
    required this.value,
    required this.strategy,
    required this.dedupeKey,
  });

  /// The document this applies to, e.g. `users/abc/meals/2026-09-18`.
  ///
  /// Spine C1: documents a woman writes offline have deterministic ids — a date,
  /// an ISO week, an exercise — so a replayed create collides rather than
  /// duplicating. A random id replayed after reconnect makes a second log, and
  /// duplicate logs corrupt week counting.
  final String path;

  /// The field within the document.
  final String field;

  final Object? value;
  final MergeStrategy strategy;

  /// Identity for deduplication. Two intents with the same key are the same
  /// write, however many times the queue sees them.
  final String dedupeKey;

  /// Applies this intent to a current value, returning the new one.
  ///
  /// Pure, so the merge rules are testable without a database and behave
  /// identically whether they run locally or against a replayed queue.
  Object? applyTo(Object? current) {
    switch (strategy) {
      case MergeStrategy.lastWriteWins:
        return value;
      case MergeStrategy.arrayUnion:
        final existing = (current as List?)?.toList() ?? <Object?>[];
        final additions = value is List ? value as List : [value];
        for (final item in additions) {
          if (!existing.contains(item)) existing.add(item);
        }
        return existing;
      case MergeStrategy.increment:
        final base = (current as num?) ?? 0;
        return base + (value as num);
    }
  }

  @override
  String toString() => 'WriteIntent($path.$field ${strategy.name})';
}

/// Where drained writes are handed off. Implemented by the Firestore repository
/// in production and by a fake in tests, so the queue never imports Firebase.
abstract class WriteSink {
  Future<void> apply(WriteIntent intent);
}
