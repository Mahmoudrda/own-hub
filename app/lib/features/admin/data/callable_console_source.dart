/// [ConsoleSource] over the `admin_dashboard` and `admin_logs` callables.
///
/// The server checks App Check, a phone sign-in and the `admin` claim before
/// it reads anything, and writes the read to its access log. This side only
/// turns its refusals into the three things a screen can say.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../domain/console_report.dart';
import '../domain/console_source.dart';

const String kAdminDashboardCallable = 'admin_dashboard';
const String kAdminLogsCallable = 'admin_logs';

/// The server's refusal, as a [ConsoleFailure].
ConsoleFailure consoleFailureFor(String code, String? message) =>
    switch (code) {
      'unauthenticated' => ConsoleFailure.signInRequired,
      'permission-denied' when message == 'phone_sign_in_required' =>
        ConsoleFailure.signInRequired,
      'permission-denied' => ConsoleFailure.notAdmin,
      _ => ConsoleFailure.unavailable,
    };

class CallableConsoleSource implements ConsoleSource {
  CallableConsoleSource(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> body,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Object?>(body)
          .timeout(const Duration(seconds: 30));
      final data = result.data;
      if (data is Map) return data.cast<String, Object?>();
      throw const ConsoleException(ConsoleFailure.unavailable);
    } on FirebaseFunctionsException catch (error) {
      throw ConsoleException(consoleFailureFor(error.code, error.message));
    } on ConsoleException {
      rethrow;
    } catch (_) {
      throw const ConsoleException(ConsoleFailure.unavailable);
    }
  }

  @override
  Future<ConsoleDashboard> dashboard({bool refresh = false}) async =>
      ConsoleDashboard.fromJson(
        await _call(kAdminDashboardCallable, {'refresh': refresh}),
      );

  @override
  Future<ConsoleLogPage> logs(
    ConsoleLogKind kind, {
    String? before,
    String? outcome,
  }) async => ConsoleLogPage.fromJson(
    kind,
    await _call(kAdminLogsCallable, {
      'kind': kind.wire,
      'before': ?before,
      'outcome': ?outcome,
    }),
  );
}
