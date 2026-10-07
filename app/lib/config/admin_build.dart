/// Whether this binary is the owner's admin build.
///
/// The admin console (`Z01` to `Z18`) is never in a store build. A release
/// binary refuses every admin route whatever is defined here, because
/// `kReleaseMode` is checked first and is a compile-time constant. This flag
/// decides only whether a **profile** build carries the console, and it is set
/// by one script, `tool/admin_access.sh build`, which refuses to make a release
/// build and writes its APK under `build/admin/`, a path nothing uploads from.
///
///   * debug: the console resolves, as it always has, for working on it;
///   * profile with `--dart-define=ADMIN_BUILD=true`: the owner's admin build,
///     installed on her own phone, with the console switched on at start;
///   * profile without it: no console;
///   * release, with or without it: no console, ever.
///
/// Being in the build is not being allowed in. Every write the console makes
/// and every count it reads is refused by the server unless her account holds
/// the `admin` claim, which only `functions/tools/grant_admin.py` sets.
library;

/// `--dart-define=ADMIN_BUILD=true`. False in every build that does not ask.
const bool kAdminBuild = bool.fromEnvironment('ADMIN_BUILD');
