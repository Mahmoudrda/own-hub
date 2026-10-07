/// Where Z15 and Z16 get their answers: the `admin_dashboard` and `admin_logs`
/// callables, behind an interface so the screens are tested without a network.
library;

import 'console_report.dart';

/// Why the console could not answer, in terms a screen can say.
enum ConsoleFailure {
  /// The account does not hold the `admin` claim.
  notAdmin,

  /// Signed out, or signed in some other way than by phone.
  signInRequired,

  /// No connection, no Firebase, or the server could not record the read.
  unavailable,
}

class ConsoleException implements Exception {
  const ConsoleException(this.failure);

  final ConsoleFailure failure;

  @override
  String toString() => 'ConsoleException(${failure.name})';
}

abstract class ConsoleSource {
  Future<ConsoleDashboard> dashboard({bool refresh = false});

  Future<ConsoleLogPage> logs(
    ConsoleLogKind kind, {
    String? before,
    String? outcome,
  });
}

/// A build with no Firebase. Says so rather than showing zeros.
class UnavailableConsoleSource implements ConsoleSource {
  const UnavailableConsoleSource();

  @override
  Future<ConsoleDashboard> dashboard({bool refresh = false}) async =>
      throw const ConsoleException(ConsoleFailure.unavailable);

  @override
  Future<ConsoleLogPage> logs(
    ConsoleLogKind kind, {
    String? before,
    String? outcome,
  }) async => throw const ConsoleException(ConsoleFailure.unavailable);
}
