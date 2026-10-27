/// The screen a link opens while the app is already running. Invite links are
/// kept and sent by [AppRouter.followLink]; this only says so.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/coach_invite.dart';

class OwnHubLinkView extends StatefulWidget {
  const OwnHubLinkView({super.key, required this.link, required this.onOpen});

  /// Null when the link did not parse.
  final OwnHubLink? link;

  /// Called once, after the first frame, with the parsed link.
  final void Function(OwnHubLink link) onOpen;

  @override
  State<OwnHubLinkView> createState() => _OwnHubLinkViewState();
}

class _OwnHubLinkViewState extends State<OwnHubLinkView> {
  @override
  void initState() {
    super.initState();
    final link = widget.link;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onOpen(link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ok = widget.link != null;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.yourCoachsInvitation,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Text(
          ok ? l10n.savedOnceYouAreInWeWill : l10n.thisLinkDoesNotWorkAskYour,
        ),
        AppButton(
          l10n.continueLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
