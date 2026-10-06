/// A coach's invite code, and the WhatsApp message that carries it.
///
/// `K07`'s "Invite a client" asks the server for her code
/// (`create_coach_invite`) and opens WhatsApp with a message holding it. The
/// woman she sends it to types it on `C01`; it waits on her phone through
/// sign-up, and once she has passed the check `accept_coach_invite` opens an
/// enquiry on the coach's desk, which the coach accepts on `K09` as she would
/// any other.
///
/// A code rather than a link: this build registers no app links, so a link
/// would open a website rather than the app. A code survives being forwarded,
/// read aloud or copied by hand, and it carries the coach's identity only on
/// the server, never in the message.
library;

/// No 0/O and no 1/I/L. Mirrors `functions/coaching/invites.py`.
const String kInviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

const int kInviteCodeLength = 8;

/// Callable names, identical on both sides.
const String kCreateCoachInviteCallable = 'create_coach_invite';
const String kAcceptCoachInviteCallable = 'accept_coach_invite';

/// The Western digit for an Arabic-Indic or Extended Arabic-Indic one, by code
/// point (as `signup/domain/digits.dart` does), or the rune unchanged.
int _westernDigit(int rune) {
  const ascii0 = 0x30;
  const arabicIndic0 = 0x0660;
  const extendedArabicIndic0 = 0x06F0;
  if (rune >= arabicIndic0 && rune <= arabicIndic0 + 9) {
    return ascii0 + rune - arabicIndic0;
  }
  if (rune >= extendedArabicIndic0 && rune <= extendedArabicIndic0 + 9) {
    return ascii0 + rune - extendedArabicIndic0;
  }
  return rune;
}

/// The code as the server stores it, or null when it cannot be one.
///
/// Forgives what copying out of a chat bubble does to a code: spaces, dashes,
/// lower case, Eastern Arabic digits. Nothing else.
String? normaliseInviteCode(String raw) {
  if (raw.length > 40) return null;
  final out = StringBuffer();
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(_westernDigit(rune)).toUpperCase();
    if (ch == ' ' || ch == '-' || ch == '_' || ch == '\u00a0') continue;
    if (!kInviteAlphabet.contains(ch)) return null;
    out.write(ch);
  }
  final code = out.toString();
  return code.length == kInviteCodeLength ? code : null;
}

/// The code as she reads it: two groups of four.
String displayInviteCode(String code) => code.length == kInviteCodeLength
    ? '${code.substring(0, 4)}-${code.substring(4)}'
    : code;

/// WhatsApp's share link with [text] prefilled and no recipient: she picks who
/// it goes to.
Uri whatsAppShareUri(String text) =>
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

/// WhatsApp to one number, for the coach interest form. [number] is in
/// international form; anything but digits is dropped.
Uri whatsAppToUri(String number, String text) => Uri.parse(
  'https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}'
  '?text=${Uri.encodeComponent(text)}',
);

/// Why redeeming did not link her.
enum InviteRedemption {
  /// Linked: the coach has her enquiry.
  linked,

  /// No such code, lapsed, her own, or refused. She asks her coach again.
  refused,

  /// Not reached. The code stays on her phone and is tried again later.
  unreachable,
}
