import 'package:flutter/material.dart';

/// What a set, hold or move screen left in the stack becomes once its workout
/// has been put away. It draws nothing of the bundled sample and, the moment it
/// is the screen on top again (Back from the finish page), sends her [onLeave].
class SessionOverRedirect extends StatefulWidget {
  const SessionOverRedirect({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  State<SessionOverRedirect> createState() => _SessionOverRedirectState();
}

class _SessionOverRedirectState extends State<SessionOverRedirect> {
  bool _left = false;

  @override
  Widget build(BuildContext context) {
    // Reading the route here rebuilds this when it becomes the top one.
    final top = ModalRoute.of(context)?.isCurrent ?? true;
    if (top && !_left) {
      _left = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLeave();
      });
    }
    return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
  }
}
