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
  static const String privacyPolicy = 'https://own-hub.app/privacy';

  /// `https://…/terms`
  static const String terms = 'https://own-hub.app/terms';

  /// `https://…/coach-terms`, the terms a coach accepts when she applies.
  static const String coachTerms = 'https://own-hub.app/coach-terms';

  /// `https://…/coach-agreement`, the agreement a coach accepts, prints,
  /// signs by hand and uploads.
  static const String coachAgreement = 'https://own-hub.app/coach-agreement';

  /// `https://…/coach-agreement.pdf`, the same text ready to print.
  static const String coachAgreementPdf =
      'https://own-hub.app/coach-agreement.pdf';

  /// `https://…/support`
  static const String support = 'https://own-hub.app/support';

  /// `https://…/delete-account`. This one also goes into Play Console under
  /// Data safety, Data deletion.
  static const String deleteAccount = 'https://own-hub.app/delete-account';

  /// The privacy mailbox: where "Ask for a copy" in Your data writes to.
  /// The same address as `contactPrivacy` in `site/config.json`, which the
  /// privacy policy publishes; test/release/compliance_copy_test.dart holds
  /// the two together.
  static const String privacyEmail = 'info@own-hub.app';

  /// True once every page has an address.
  static bool get allSet =>
      privacyPolicy.isNotEmpty &&
      terms.isNotEmpty &&
      support.isNotEmpty &&
      deleteAccount.isNotEmpty;

  /// [url] in her language. The site publishes every page twice, the Arabic
  /// one under `/ar/`, so `https://…/privacy` becomes `https://…/ar/privacy`.
  /// Empty stays empty, and a page already under `/ar/` is left alone.
  static String localised(String url, String languageCode) {
    if (url.isEmpty || languageCode != 'ar') return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    if (uri.path == '/ar' || uri.path.startsWith('/ar/')) return url;
    final path = uri.path.isEmpty || uri.path == '/' ? '/' : uri.path;
    return uri.replace(path: path == '/' ? '/ar/' : '/ar$path').toString();
  }

  /// Stops a release build whose public pages have no address (M2). The
  /// stores require the policy to be reachable from inside the app, and
  /// `tool/release_preflight.sh` fails on the same condition; this makes a
  /// build that skipped the preflight fail at its first launch instead of in
  /// review.
  static void requireForRelease({required bool release}) {
    if (release && !allSet) {
      throw StateError(
        'LegalLinks are empty: fill lib/config/legal_links.dart before a '
        'release build.',
      );
    }
  }
}
