/// Keeps the ID card and selfie screens out of screenshots, screen recordings
/// and the app switcher.
///
/// Android sets the window's secure flag through the `secure` method on the
/// settings channel, which also blanks the recent-apps thumbnail. iOS has no
/// such flag, so while one of these screens is up and the app goes inactive
/// (the moment the switcher takes its snapshot) a plain linen cover is drawn
/// over it until she is back.
///
/// Screens can overlap while one route replaces another, so the flag is
/// counted: it comes off only when the last screen holding it closes. A phone
/// that refuses changes nothing: a failure here must never touch the capture.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

const MethodChannel _channel = MethodChannel('com.ownhub.app/settings');

Future<void> _platformSecure(bool on) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _channel.invokeMethod<void>('secure', on);
  }
}

/// Does the platform work. Tests replace it.
@visibleForTesting
Future<void> Function(bool on) secureApply = _platformSecure;

int _holds = 0;

void _hold(bool on) {
  _holds += on ? 1 : -1;
  if (_holds < 0) _holds = 0;
  if (on && _holds != 1) return;
  if (!on && _holds != 0) return;
  unawaited(_run(on));
}

Future<void> _run(bool on) async {
  try {
    await secureApply(on);
  } catch (_) {
    // The screen may be capturable; the capture carries on.
  }
}

class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen>
    with WidgetsBindingObserver {
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _hold(true);
    WidgetsBinding.instance.addObserver(this);
  }

  // An observer rather than AppLifecycleListener, which asserts on the
  // paused-to-resumed jump some tests and platforms make.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) _cover(true);
    if (state == AppLifecycleState.resumed) _cover(false);
  }

  void _cover(bool on) {
    if (defaultTargetPlatform != TargetPlatform.iOS || _covered == on) return;
    if (mounted) setState(() => _covered = on);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_covered) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        const ColoredBox(color: AppColors.surface),
      ],
    );
  }
}
