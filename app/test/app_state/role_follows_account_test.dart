import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/role_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';

final _flags = FeatureFlags.allOff.with_({
  Feature.coachApp: true,
  Feature.accountRequired: true,
});

void main() {
  setUp(() => RoleState.instance.roles = null);
  tearDown(() => RoleState.instance.roles = null);

  test(
    'a coach signing out, then a member signing in, gets the member side',
    () {
      RoleState.instance.roles = UserRoles.coach;

      final afterSignOut = rolesAfterAccountChange('coachA', null, _flags);
      expect(afterSignOut, isNotNull);
      expect(RoleState.instance.roles, isNull);
      expect(rolesAfterAccountChange(null, 'memberB', _flags), isNull);
      expect(afterSignOut!.active, AppRole.trainee);
    },
  );

  test('another account signing in without a sign-out drops the old side', () {
    RoleState.instance.roles = UserRoles.coach;
    final next = rolesAfterAccountChange('coachA', 'memberB', _flags);
    expect(next?.active, AppRole.trainee);
    expect(RoleState.instance.roles, isNull);
  });

  test('the same account, or a first sign-in, keeps what the phone has', () {
    RoleState.instance.roles = UserRoles.coach;
    expect(rolesAfterAccountChange('a', 'a', _flags), isNull);
    expect(rolesAfterAccountChange(null, 'a', _flags), isNull);
    expect(RoleState.instance.roles, UserRoles.coach);
  });
}
