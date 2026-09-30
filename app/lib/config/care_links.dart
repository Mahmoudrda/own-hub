/// Outward links that are about her health rather than about the company.
///
/// Kept apart from [LegalLinks] on purpose. Those four are store requirements
/// and `tool/release_preflight.sh` fails while any of them is blank; this one is
/// content, and a release with it empty is a release with a smaller Y11, not a
/// rejected submission.
///
/// Empty until somebody chooses the page.
///
/// **The row is still drawn, and it says what is missing.** This used to read
/// "Nothing renders a row for an empty link, so the app never shows a control
/// that opens nothing", which was never true of Y11: `cycle_hub_view.dart`
/// draws the guidance button unconditionally and the router gives it
/// `showHonestNotice(weDoNotHaveAGuidancePage)` while this constant is blank,
/// swapping in `openExternalLink` the moment it is not. That is the better
/// design of the two — a woman in severe pain is told there is no page yet
/// rather than shown a screen with one fewer option and no explanation — but a
/// doc claiming the row is absent means nobody knows the button is already
/// wired the day the address arrives.
///
/// What the button must not do is blame the wrong thing. It does not say this
/// build cannot open a browser: `url_launcher` ships, `openExternalLink`
/// exists, and A03 and A04 already use it. What is missing is the page.
library;

abstract final class CareLinks {
  /// Guidance on period pain, for the card Y11 draws when she logs severe
  /// cramps or heavy bleeding.
  ///
  /// **Choose the source before filling this in.** The button beside it is
  /// labelled "Read NHS guidance on period pain", and the NHS is a British
  /// health service; this app is for women in Egypt. Whoever fills in the
  /// address changes the label with it.
  static const String periodPainGuidance = '';
}
