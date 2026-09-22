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
/// TODO(build): replace with a `shared_preferences` implementation so the choice
/// survives a restart, and add it alongside the Firebase packages in one batch —
/// both bring platform channels, and adding them together means one pod install
/// and one build verification rather than two.
class InMemoryLocalePreference implements LocalePreference {
  InMemoryLocalePreference([this._value]);

  AppLanguage? _value;

  @override
  AppLanguage? read() => _value;

  @override
  Future<void> write(AppLanguage language) async => _value = language;
}
