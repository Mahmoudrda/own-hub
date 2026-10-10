/// How a woman reaches the Own Hub team from inside the app.
///
/// OWNER: fill [coachWhatsApp] with the team's WhatsApp number in
/// international form (for example +20 10 0000 0000). Until it is filled, the
/// coach interest form on C01 opens an email to [supportEmail] instead, so a
/// coach is never turned away with nothing captured.
library;

abstract final class TeamContact {
  /// The team's WhatsApp number. Empty until the owner supplies it.
  static const String coachWhatsApp = '';

  /// The monitored support mailbox: `contactSupport` in site/config.json.
  static const String supportEmail = 'support@own-hub.app';

  static bool get hasWhatsApp => coachWhatsApp.trim().isNotEmpty;
}
