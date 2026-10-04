/// The Firestore half of the recipe library.
///
/// `seeded_recipe_library.dart` describes the wire format; this is its reader.
///
///   * **Once a day**, at start-up or on Eat open, read `meta/recipes`
///     (`{ version: N }`). One small document.
///   * Only when `N` is newer than what the phone already holds (the seed or the
///     cache), read `recipeIndex/en_v{N}` for the list of ids and sections, then
///     each `recipes/{id}`. That full fetch happens once per version bump.
///   * Every fetched recipe goes through [Recipe.fromJson], the same model the
///     seed uses, and [recipeProblems], the same rules the seed is held to. One
///     failure refuses the whole set.
///   * A complete, valid set is written to its own preference key and then
///     handed over as one finished [RecipeBook]. Nothing is ever shown half
///     updated, because nothing is handed over until it is whole.
///   * Offline, on any error, or with Firebase unavailable: the seed, or the
///     last complete set already cached.
///
/// The seed stays the floor: remote recipes are merged with [mergeByVersion], so
/// a server document can replace a recipe with a newer version or add one, and
/// never take one away.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../app_state/local_persistence.dart';
import '../domain/recipe.dart';
import '../domain/recipe_validation.dart';
import 'seeded_recipe_library.dart';

/// The cached remote library. Its own key, beside the snapshot, so a bad
/// recipe cache can never touch her week and erasing one never erases the
/// other. Public, non-personal content.
const String kRecipeCacheKey = 'own_hub.recipes';

/// When the version document was last read. Kept apart from the cache so the
/// daily check does not rewrite 200 KB of recipes.
const String kRecipeCheckKey = 'own_hub.recipes_checked_at';

/// Which index document is read. The rows are the same in every locale today
/// (see `tool/build_recipe_index.py`), and the book carries both titles.
const String kRecipeIndexLocale = 'en';

/// Where the remote library is read from. Firestore in the app, a fake in tests.
abstract class RecipeRemoteSource {
  /// `meta/recipes.version`, or null when the document is missing.
  Future<int?> readVersion();

  /// `recipeIndex/{locale}_v{version}`, or null when missing.
  Future<Map<String, Object?>?> readIndex(int version);

  /// `recipes/{recipeId}`, or null when missing.
  Future<Map<String, Object?>?> readRecipe(String recipeId);
}

enum RecipeRefreshOutcome {
  /// Checked within the last day, or backing off after a failure.
  notDue,

  /// No Firebase, or nobody signed in who may read the library.
  unavailable,

  /// The server has nothing newer.
  upToDate,

  /// A newer, complete and valid set is cached and returned.
  updated,

  /// The server's set broke a rule. The seed or cache is kept.
  rejected,

  /// The network or the server failed. The seed or cache is kept.
  failed,
}

@immutable
class RecipeRefreshResult {
  const RecipeRefreshResult(this.outcome, [this.book]);

  final RecipeRefreshOutcome outcome;

  /// The new library, only when [outcome] is [RecipeRefreshOutcome.updated].
  final RecipeBook? book;
}

class _Rejected implements Exception {
  const _Rejected(this.why);
  final String why;
  @override
  String toString() => 'rejected: $why';
}

class RecipeSync implements RecipeLibrary {
  RecipeSync({
    required this.seed,
    required this.source,
    SnapshotStorage? cache,
    SnapshotStorage? checks,
    DateTime Function()? now,
  }) : cache = cache ?? const PreferencesSnapshotStorage(key: kRecipeCacheKey),
       checks =
           checks ?? const PreferencesSnapshotStorage(key: kRecipeCheckKey),
       _now = now ?? DateTime.now;

  /// The bundled library. Always the floor.
  final RecipeLibrary seed;

  /// The remote source, or null when it cannot be used right now (Firebase
  /// down, nobody signed in, not verified). Asked on every refresh.
  final RecipeRemoteSource? Function() source;

  final SnapshotStorage cache;
  final SnapshotStorage checks;
  final DateTime Function() _now;

  /// The version document is read at most this often.
  static const Duration checkEvery = Duration(hours: 24);

  /// After a failed check, the next attempt waits this long, in this run only.
  static const Duration retryAfterFailure = Duration(hours: 1);

  DateTime? _notBefore;
  Future<RecipeRefreshResult>? _inFlight;

  /// The seed, merged with the last complete remote set when one is cached.
  @override
  Future<RecipeBook> load() async {
    final base = await seed.load();
    try {
      final raw = await cache.read();
      if (raw == null) return base;
      final remote = _parse(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
        base,
      );
      if (remote.contentVersion <= base.contentVersion) return base;
      return _merge(base, remote);
    } catch (_) {
      // A cache this build cannot read is no cache. The seed still works.
      return base;
    }
  }

  /// Checks the server if a day has passed, and fetches a newer set if there
  /// is one. Never throws.
  Future<RecipeRefreshResult> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<RecipeRefreshResult> _refresh() async {
    final now = _now();
    final notBefore = _notBefore;
    if (notBefore != null && now.isBefore(notBefore)) {
      return const RecipeRefreshResult(RecipeRefreshOutcome.notDue);
    }
    final remote = source();
    if (remote == null) {
      return const RecipeRefreshResult(RecipeRefreshOutcome.unavailable);
    }
    try {
      final last = DateTime.tryParse(await checks.read() ?? '');
      if (last != null && now.difference(last) < checkEvery) {
        _notBefore = last.add(checkEvery);
        return const RecipeRefreshResult(RecipeRefreshOutcome.notDue);
      }
    } catch (_) {
      // An unreadable check time is treated as "never checked".
    }

    try {
      final version = await remote.readVersion();
      await _recordCheck(now);
      final current = await load();
      if (version == null || version <= current.contentVersion) {
        return const RecipeRefreshResult(RecipeRefreshOutcome.upToDate);
      }
      final payload = await _fetch(remote, version);
      final base = await seed.load();
      final book = _merge(base, _parse(payload, base));
      await cache.write(jsonEncode(payload));
      return RecipeRefreshResult(RecipeRefreshOutcome.updated, book);
    } on _Rejected catch (error) {
      if (kDebugMode) debugPrint('Recipe library refused: $error');
      return const RecipeRefreshResult(RecipeRefreshOutcome.rejected);
    } catch (error) {
      _notBefore = now.add(retryAfterFailure);
      if (kDebugMode) debugPrint('Recipe library check failed: $error');
      return const RecipeRefreshResult(RecipeRefreshOutcome.failed);
    }
  }

  Future<void> _recordCheck(DateTime at) async {
    _notBefore = at.add(checkEvery);
    try {
      await checks.write(at.toUtc().toIso8601String());
    } catch (_) {
      // The in-memory limit still holds for this run.
    }
  }

  /// Reads the index and every free recipe it names. Throws [_Rejected] on a
  /// shape problem; network errors propagate as they are.
  Future<Map<String, Object?>> _fetch(
    RecipeRemoteSource remote,
    int version,
  ) async {
    final index = await remote.readIndex(version);
    if (index == null) throw const _Rejected('no index document');
    if (index['version'] != version) {
      throw const _Rejected('index version does not match');
    }
    final rows = index['rows'];
    if (rows is! List || rows.isEmpty) throw const _Rejected('no rows');
    final ids = <String>[];
    for (final row in rows) {
      if (row is! Map) throw const _Rejected('a row is not a map');
      final id = row['recipeId'];
      if (id is! String || id.isEmpty) throw const _Rejected('a row has no id');
      if (ids.contains(id)) throw _Rejected('$id is listed twice');
      // Drafts are never read at all. Pro rows are not readable by a free
      // account under the rules, and nothing is sold, so they are not asked for.
      if (row['status'] == RecipeStatus.draft.name) continue;
      if ((row['tier'] ?? RecipeTier.free.name) != RecipeTier.free.name) {
        continue;
      }
      ids.add(id);
    }
    if (ids.isEmpty) throw const _Rejected('no readable rows');

    final recipes = <Map<String, Object?>>[];
    for (final id in ids) {
      final doc = await remote.readRecipe(id);
      if (doc == null) throw _Rejected('$id is listed but missing');
      if (doc['recipeId'] != id) throw _Rejected('$id carries another id');
      recipes.add(doc);
    }
    return {
      'version': version,
      'sections': index['sections'],
      'recipes': recipes,
    };
  }

  /// The remote set as a book, or [_Rejected]. The same parse and the same
  /// rules as the seed.
  RecipeBook _parse(Map<String, Object?> payload, RecipeBook base) {
    final version = payload['version'];
    if (version is! int) throw const _Rejected('no version');
    final RecipeBook book;
    try {
      book = RecipeBook.fromJson({
        'schemaVersion': base.schemaVersion,
        'contentVersion': version,
        'sections': payload['sections'] ?? const <Object?>[],
        'recipes': payload['recipes'],
      });
    } catch (error) {
      throw _Rejected('does not parse: $error');
    }
    final sectionIds = {
      for (final s in [...base.sections, ...book.sections]) s.sectionId,
    };
    final problems = [
      for (final r in [...book.recipes, ...book.assemblies])
        ...recipeProblems(r, sectionIds: sectionIds),
    ];
    if (problems.isNotEmpty) throw _Rejected(problems.join('; '));
    return book;
  }

  /// One finished book: the seed, with the remote set laid over it.
  static RecipeBook _merge(RecipeBook base, RecipeBook remote) {
    final sections = {for (final s in base.sections) s.sectionId: s};
    for (final s in remote.sections) {
      sections[s.sectionId] = s;
    }
    return RecipeBook(
      schemaVersion: base.schemaVersion,
      contentVersion: remote.contentVersion,
      sections: sections.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      recipes: List.unmodifiable(mergeByVersion(base.recipes, remote.recipes)),
      assemblies: List.unmodifiable(
        mergeByVersion(base.assemblies, remote.assemblies),
      ),
      letterAr: base.letterAr,
    );
  }
}
