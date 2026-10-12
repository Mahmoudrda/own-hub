/// Her roles, kept past a relaunch (D11).
///
/// `main.dart` holds the live value in the app-wide [RoleScope]. It used to
/// start as a trainee on every launch, so a coach who closed the app came back
/// to the trainee side with her setup gone. This is the copy that survives:
/// written to the phone in the snapshot (`app_snapshot.dart`, section `roles`)
/// and, for a new phone, read back from `users/{uid}.roles`, which only the
/// `record_signup_role` callable writes (the rules keep the field out of the
/// client's whitelist).
///
/// Nothing here grants anything on the server. Every coach privilege in the
/// rules reads the `coachV` claim, which only a woman reviewer's decision
/// mints. This decides which side of the app she opens on.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/flags/feature_flags.dart';
import '../domain/identity/user_roles.dart';
import '../features/signup/data/callable_failure.dart';
import '../features/signup/presentation/role_view.dart' show SignupRole;
import 'app_changes.dart';
import 'firebase_boot.dart';

/// Callable name, identical on both sides.
const String kRecordSignupRoleCallable = 'record_signup_role';

/// What `C08` sends.
Map<String, Object> signupRolePayload(SignupRole role) => <String, Object>{
  'role': role.name,
};

/// The roles a stored list names, or null for anything this build does not
/// recognise. Order and duplicates do not matter; an unknown name does.
Set<AppRole>? rolesFromNames(Object? raw) {
  if (raw is! List) return null;
  final out = <AppRole>{};
  for (final name in raw) {
    final role = AppRole.values.where((r) => r.name == name).firstOrNull;
    if (role == null) return null;
    out.add(role);
  }
  return out.isEmpty ? null : out;
}

/// The roles the server keeps for her, from `users/{uid}`'s data.
UserRoles? rolesFromUserDoc(Map<String, Object?>? data) {
  final roles = data?['roles'];
  if (roles is! Map) return null;
  final held = rolesFromNames(roles['held']);
  if (held == null) return null;
  // A woman who holds both opens on the trainee side, as on sign-up.
  return UserRoles(
    held: held,
    active: held.contains(AppRole.trainee) ? AppRole.trainee : AppRole.coach,
  );
}

class RoleState {
  RoleState._();

  static final RoleState instance = RoleState._();

  /// Her roles as last chosen or switched, or null when this phone has none.
  UserRoles? roles;

  /// True when she holds the coach role and not the trainee one.
  bool get coachOnly {
    final held = roles?.held;
    return held != null &&
        held.contains(AppRole.coach) &&
        !held.contains(AppRole.trainee);
  }

  /// Records [next] when it differs, so the snapshot writes it.
  void keep(UserRoles next) {
    if (roles == next) return;
    roles = next;
    AppChanges.bump();
  }

  /// Account deletion and sign-out.
  void reset() => roles = null;
}

/// Her roles at launch. None but trainee while there is no coach side: a
/// picture that switches to an app that is switched off is a door into
/// nothing. Else the roles this phone kept, else trainee when an account is
/// required (C08 decides) and both when it is not (no sign-up to ask in).
UserRoles launchRoles(FeatureFlags flags) {
  if (!flags.isOn(Feature.coachApp)) return UserRoles.trainee;
  final kept = RoleState.instance.roles;
  if (kept != null) return kept;
  return flags.isOn(Feature.accountRequired)
      ? UserRoles.trainee
      : UserRoles.both;
}

/// Where her role choice is sent, and read back from on a new phone.
abstract class RoleRecordStore {
  Future<void> record(SignupRole role);

  /// What the server keeps, or null when it has nothing or cannot be read.
  Future<UserRoles?> read(String uid);
}

class FirebaseRoleRecordStore implements RoleRecordStore {
  FirebaseRoleRecordStore({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseBoot.functions,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  Future<void> record(SignupRole role) async {
    final callable = _functions.httpsCallable(
      kRecordSignupRoleCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    try {
      await callable.call<Object?>(signupRolePayload(role));
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error);
    }
  }

  @override
  Future<UserRoles?> read(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 3));
      return rolesFromUserDoc(snapshot.data());
    } catch (_) {
      return null;
    }
  }
}

/// A build with no back end: her roles stay on this phone.
class InMemoryRoleRecordStore implements RoleRecordStore {
  final Map<String, UserRoles> _byUid = <String, UserRoles>{};
  final List<SignupRole> recorded = <SignupRole>[];

  @override
  Future<void> record(SignupRole role) async => recorded.add(role);

  @override
  Future<UserRoles?> read(String uid) async => _byUid[uid];

  void seed(String uid, UserRoles roles) => _byUid[uid] = roles;
}
