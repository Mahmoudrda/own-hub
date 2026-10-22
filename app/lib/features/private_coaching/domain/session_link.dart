/// The link a coach puts on a live session, and the time format the server
/// reads. Same rules as `sessions.check_link` on the server.
library;

import 'coaching_contract.dart';

/// Longest link accepted.
const int kSessionLinkMax = 300;

/// Whether [link] is an https link to an allowed meeting host: no address
/// with a port, user info, spaces or non-ASCII characters.
bool sessionLinkAllowed(String link) {
  if (link.isEmpty || link.length > kSessionLinkMax) return false;
  if (RegExp(r'[\s\\\x00-\x1f\x7f]').hasMatch(link)) return false;
  if (link.codeUnits.any((c) => c > 127)) return false;
  final Uri uri;
  try {
    uri = Uri.parse(link);
  } on FormatException {
    return false;
  }
  if (uri.scheme != 'https' || uri.host.isEmpty) return false;
  if (uri.hasPort || uri.userInfo.isNotEmpty) return false;
  if (uri.authority != uri.host) return false;
  return _hostAllowed(uri.host);
}

bool _hostAllowed(String host) {
  for (final allowed in CoachingIds.sessionLinkHosts) {
    if (allowed.startsWith('*.')) {
      final suffix = allowed.substring(1);
      if (host.endsWith(suffix) && host.length > suffix.length) return true;
    } else if (host == allowed) {
      return true;
    }
  }
  return false;
}

/// `2026-10-24T18:30:00+00:00`: UTC, whole seconds, an explicit offset. The
/// server refuses a time without an offset.
String wireTime(DateTime at) {
  final u = at.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final year = u.year.toString().padLeft(4, '0');
  return '$year-${two(u.month)}-${two(u.day)}T'
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)}+00:00';
}
