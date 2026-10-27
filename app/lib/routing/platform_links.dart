/// Which URLs the platform pushes onto the running app are the app's to open.
///
/// With Flutter's deep linking on, iOS and Android hand every URL the app is
/// opened with to the navigator as a route name. Two kinds are not routes: a
/// widget tap (`ownhub://widget?homeWidget=1`, read by `home_widget`) and the
/// phone sign-in callback (read by Firebase). Their plugins answer first and
/// the navigator normally never sees them; this keeps it that way if one slips
/// through, so a widget tap cannot land on the unknown-route page.
library;

import '../features/coach/domain/coach_invite.dart';
import 'app_router.dart';

/// The name WidgetsApp pushes for [uri]: the path and query, never the host.
String pushedRouteName(Uri uri) =>
    uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

/// True for a coach link (also a broken one, which explains itself) and for a
/// screen this build serves; false for anything else.
bool appFollowsPushedRoute(Uri uri) {
  final name = pushedRouteName(uri);
  return parseOwnHubLink(name) != null ||
      name.startsWith('/c/') ||
      name.startsWith('/p/') ||
      screenIdForRoute(name) != null;
}
