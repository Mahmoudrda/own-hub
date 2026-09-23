/// The four public pages both stores require, in one place.
///
/// Apple 5.1.1 and Google's User Data policy both want the privacy policy
/// reachable from inside the app, not only from the store listing. Play's Data
/// safety form additionally wants a deletion page a woman can use without
/// installing the app, and Apple 1.5 wants a support page that actually loads.
///
/// They are empty until the domain exists. Nothing in the app renders a row for
/// an empty link, so the app never shows a button that goes nowhere, and
/// `tool/release_preflight.sh` fails while any of them is blank: a submission
/// with an empty privacy URL is a rejection, not a detail to fix afterwards.
///
/// Fill these four in, publish the pages, then run the preflight.
library;

abstract final class LegalLinks {
  /// `https://…/privacy`
  static const String privacyPolicy = '';

  /// `https://…/terms`
  static const String terms = '';

  /// `https://…/support`
  static const String support = '';

  /// `https://…/delete-account`. This one also goes into Play Console under
  /// Data safety, Data deletion.
  static const String deleteAccount = '';

  /// True once every page has an address.
  static bool get allSet =>
      privacyPolicy.isNotEmpty &&
      terms.isNotEmpty &&
      support.isNotEmpty &&
      deleteAccount.isNotEmpty;
}
