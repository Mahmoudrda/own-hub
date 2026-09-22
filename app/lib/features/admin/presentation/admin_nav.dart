/// The admin bottom bar — G16 §1.
///
/// > "An account holding admin sees it through the same profile-picture
/// > switcher, with its own bottom navigation: **Library · Import · Media ·
/// > Export**. Four tabs, matching the trainee and coach bars."
///
/// ## Why the list lives here and not in `app_nav_bar.dart`
///
/// [AppNavBar] normally chooses its tabs from the woman's active role, and
/// `AppRole` has two members: trainee and coach. There is no admin role, and
/// adding one means editing `lib/domain/identity/user_roles.dart` — which is
/// another group's file and not this feature's to change. `screens-admin.mjs`
/// takes the same position for the same reason: "`navBar()` hardcodes the client
/// and coach tab sets, so the admin bar is local to this file."
///
/// [AppNavBar] already documents the way through: "Passing an explicit list is
/// for tests and for the design gallery." Every admin screen passes
/// [adminTabs] explicitly, so no role lookup happens and no `RoleScope` is
/// needed above these screens.
///
/// **This is a wiring decision the owner should ratify**, and it is reported
/// rather than taken quietly: if admin becomes a real third role in `AppRole`,
/// this list should move into `tabsFor` beside the other two and these screens
/// should stop passing it.
///
/// ## The Library tab is labelled "Library"
///
/// It was `contentLibrary` — "Content library" — for one release, because the
/// design's single word did not exist in the dictionary and a tab may not invent
/// one. It exists now, as `libraryLabel`: `library` is a Dart keyword, so the
/// generated getter carries the suffix and this is the right name to use rather
/// than a collision to work around.
///
/// The screen it opens still calls itself "Content library" in its app bar. That
/// is not a disagreement — a tab is a word and a title is a name, and the design
/// draws exactly that pair.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_nav_bar.dart';

String _libraryLabel(AppL10n l) => l.libraryLabel;
String _importLabel(AppL10n l) => l.importLabel;
String _mediaLabel(AppL10n l) => l.media;
String _exportLabel(AppL10n l) => l.exportLabel;

/// Library · Import · Media · Export, in the order §1 gives them.
const List<NavDestination> adminTabs = [
  NavDestination(
    screenId: 'Z01',
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: _libraryLabel,
  ),
  NavDestination(
    screenId: 'Z08',
    icon: Icons.upload_file_outlined,
    activeIcon: Icons.upload_file,
    label: _importLabel,
  ),
  NavDestination(
    screenId: 'Z10',
    icon: Icons.perm_media_outlined,
    activeIcon: Icons.perm_media,
    label: _mediaLabel,
  ),
  NavDestination(
    screenId: 'Z11',
    icon: Icons.download_outlined,
    activeIcon: Icons.download,
    label: _exportLabel,
  ),
];

/// The bar, with the admin tabs already supplied.
///
/// A three-line wrapper, and it earns its place: six screens render this bar, and
/// six copies of `destinations: adminTabs` is six chances for one of them to
/// forget and fall back to the trainee tabs — which would silently put Home,
/// Train, Community and Eat at the bottom of the admin console.
class AdminNavBar extends StatelessWidget {
  const AdminNavBar({super.key, required this.activeScreenId, this.onSelect});

  final String activeScreenId;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) => AppNavBar(
    activeScreenId: activeScreenId,
    destinations: adminTabs,
    onSelect: onSelect,
  );
}
