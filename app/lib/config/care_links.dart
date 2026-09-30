/// Outward links that are about her health rather than about the company.
///
/// Kept apart from [LegalLinks] on purpose. Those four are store requirements
/// and `tool/release_preflight.sh` fails while any of them is blank; this one is
/// content, and a release with it empty is a release with a smaller Y11, not a
/// rejected submission.
///
/// Empty until somebody chooses the page. Nothing renders a row for an empty
/// link, so the app never shows a control that opens nothing, and the button
/// says what is actually missing rather than claiming this build cannot open a
/// browser. It can: `url_launcher` ships, `openExternalLink` exists, and A03 and
/// A04 already use it.
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
