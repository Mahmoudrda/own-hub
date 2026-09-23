/// Where the language she picks on C02 is remembered.
///
/// **This is deliberately not `profile.language`.** C02 runs *before an account
/// exists*, so there is no user document to write to. G1's plan is explicit about
/// the split:
///
///   * `locale` — a pre-auth mirror, written here. **Not authoritative.**
///   * `profile.language` — owned by the setup flow (G2), seeded from this mirror
///     once she has an account, and written only through `ProfileRepository`.
///
/// Getting this wrong means writing to a document that does not exist yet, or two
/// fields drifting apart with no rule about which wins.
///
/// Open question carried from G1's plan: G2 must confirm that `profile.language`
/// is authoritative and that the pre-auth mirror may be created here. Both plans
/// agree on the direction, so it is built this way and the note travels with it.
library;

import 'dart:ui' show Locale;

/// The languages this product ships. Not an open set: adding one is a content
/// project, not a configuration change.
enum AppLanguage {
  arabic('ar'),
  english('en');

  const AppLanguage(this.code);

  final String code;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      code == 'en' ? AppLanguage.english : AppLanguage.arabic;
}

/// Reads and writes the pre-auth locale mirror.
abstract class LocalePreference {
  /// Her choice, or null if she has not made one yet.
  AppLanguage? read();

  Future<void> write(AppLanguage language);
}

/// In-memory implementation.
///
/// The choice does survive a restart, and it is deliberately not this class
/// that makes it: `lib/app_state/local_persistence.dart` writes one document
/// holding every store, the language among them, and reads it back before the
/// first frame. A `shared_preferences` implementation here would mean a second
/// key, written on a different schedule, that account deletion would have to
/// remember separately.
class InMemoryLocalePreference implements LocalePreference {
  InMemoryLocalePreference([this._value]);

  AppLanguage? _value;

  @override
  AppLanguage? read() => _value;

  @override
  Future<void> write(AppLanguage language) async => _value = language;
}
