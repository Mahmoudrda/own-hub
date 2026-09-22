/// Which app she is looking at, and which ones she is entitled to.
///
/// `DECISIONS.md` **D11**. This replaces a single, immutable `client | coach`
/// enum that could only be changed by messaging support. A woman now chooses
/// **train, coach, or both** at `C08`, and one who holds both switches the whole
/// app — navigation and experience together — by tapping her profile picture.
///
/// # Why this is two fields and not one
///
/// The old design's one useful property was a security property: a woman could
/// not give herself coach privileges by writing her own document. Making the
/// role freely switchable would throw that away if it stayed a single field, so
/// it is split, and the split is the whole design:
///
///   * [held] — the roles she has **earned**. `users/{uid}.roles.held` is
///     **server-write-only**. Becoming a coach still means the coach
///     application and its certificate checks; nothing on the client can add
///     [AppRole.coach] to this set.
///   * [active] — the app she is **looking at**. Hers to write, because
///     choosing which of her own apps to open is not a privilege.
///
/// So switching is free and granting is not, which is exactly the distinction
/// the original rule was protecting.
///
/// # Being coached is not a role
///
/// Hiring a coach does not put [AppRole.coach] in [held]. `F53 — Find a coach`
/// is a *trainee* feature; the coach role is for women who coach others. The two
/// were conflated while "Coaching" was a tab in her navigation bar, and D11
/// separates them: the tab is gone, the capability moved to her profile.
// `prefer_initializing_formals` asks for `required this._active`, which Dart
// forbids outright: a named parameter cannot begin with an underscore. The only
// way to satisfy the lint is to make the stored value public, and it is private
// deliberately — reading it raw skips the entitlement fallback in
// [UserRoles.active], which is the one guarantee this class exists to make.
//
// Scoped to the file rather than the line because `dart format` reflows the
// constructor across lines, which silently detaches a line-scoped ignore from
// the initializer it was meant to cover. That already happened once here.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:flutter/widgets.dart';

/// The two apps this product contains. Neither is a subset of the other.
enum AppRole { trainee, coach }

/// Her roles, and which one is live.
@immutable
class UserRoles {
  // On the `prefer_initializing_formals` suppression, see the file-level note
  // above `library;`: `this._active` is what the lint wants and what Dart
  // forbids.
  const UserRoles({required this.held, required AppRole active})
    : _active = active;

  /// She only trains. The common case, and the default.
  static const trainee = UserRoles(
    held: {AppRole.trainee},
    active: AppRole.trainee,
  );

  /// She only coaches.
  static const coach = UserRoles(held: {AppRole.coach}, active: AppRole.coach);

  /// Both. Opens on the trainee side, because that is the app she uses daily;
  /// coaching is work, and work should be something she chooses to open.
  static const both = UserRoles(
    held: {AppRole.trainee, AppRole.coach},
    active: AppRole.trainee,
  );

  /// Earned, not chosen. Server-write-only — see the note at the top of this
  /// file.
  final Set<AppRole> held;

  final AppRole _active;

  /// The app she is looking at.
  ///
  /// Deliberately derived rather than returned raw. [held] can **shrink** —
  /// a coach whose certification lapses, an account restricted after review —
  /// and a stored `active` that outlived its entitlement must not leave her
  /// sitting inside an app she no longer holds. Falling back to a role she does
  /// hold is the safe reading, and it needs no migration step to be correct.
  AppRole get active {
    if (held.contains(_active)) return _active;
    return held.isEmpty ? AppRole.trainee : held.first;
  }

  /// True only for a woman who holds both. A single-role account must never be
  /// shown a switcher: there is nothing to switch to, and offering one implies
  /// the app is hiding something from her.
  bool get canSwitch => held.length > 1;

  /// The role the switcher would move her to.
  AppRole get otherRole =>
      active == AppRole.trainee ? AppRole.coach : AppRole.trainee;

  /// Flips to the other held role. A no-op for a single-role account, rather
  /// than an error — the UI should not have offered it, and crashing her app is
  /// a worse answer than doing nothing.
  UserRoles switched() =>
      canSwitch ? UserRoles(held: held, active: otherRole) : this;

  /// Moves to [role] if she holds it.
  UserRoles activating(AppRole role) =>
      held.contains(role) ? UserRoles(held: held, active: role) : this;

  @override
  bool operator ==(Object other) =>
      other is UserRoles &&
      other.active == active &&
      other.held.length == held.length &&
      other.held.containsAll(held);

  @override
  int get hashCode =>
      Object.hash(active, held.length, held.contains(AppRole.coach));

  @override
  String toString() =>
      'UserRoles(held: ${held.map((r) => r.name).join('+')}, active: ${active.name})';
}

/// Holds her roles for the whole app, the way [LocaleScope] holds the locale.
///
/// Switching role changes navigation and the screen underneath it at once, so
/// it cannot live inside any one screen's state.
class RoleScope extends InheritedNotifier<ValueNotifier<UserRoles>> {
  const RoleScope({
    super.key,
    required ValueNotifier<UserRoles> super.notifier,
    required super.child,
  });

  static ValueNotifier<UserRoles> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoleScope>()!.notifier!;

  /// Null when there is no scope above this widget.
  ///
  /// Every screen in this product is also rendered standalone — in tests and in
  /// the design gallery — with no app shell around it. Those call sites are
  /// correct, so reading the role must degrade to a sensible default rather
  /// than assert.
  static ValueNotifier<UserRoles>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoleScope>()?.notifier;

  /// Her roles, or [UserRoles.trainee] when nothing has been chosen yet.
  static UserRoles rolesOf(BuildContext context) =>
      maybeOf(context)?.value ?? UserRoles.trainee;
}
