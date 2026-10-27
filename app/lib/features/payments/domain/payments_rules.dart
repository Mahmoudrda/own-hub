/// Format rules for InstaPay addresses. The server is the authority
/// (`functions/payments/address.py`, `proof.py`); these only give instant
/// feedback and keep a phone number out of both fields.
library;

final RegExp _handle = RegExp(r'^[a-z0-9._-]{3,40}@[a-z]{3,20}$');
final RegExp _phoneLike = RegExp(r'^[+0-9٠-٩\s-]{8,}$');

/// True for `name@bank`. A phone number is never a valid handle here.
bool validInstapayHandle(String raw) {
  final s = raw.trim();
  return !_phoneLike.hasMatch(s) && _handle.hasMatch(s.toLowerCase());
}

bool looksLikePhone(String raw) => _phoneLike.hasMatch(raw.trim());

/// 2 to 80 characters with at least one letter (Latin or Arabic).
bool validAccountName(String raw) {
  final s = raw.trim();
  return s.length >= 2 && s.length <= 80 && RegExp(r'[A-Za-zء-ي]').hasMatch(s);
}
