/// Opening a page outside the app, which is something only the policy and
/// terms rows do.
///
/// It lives here rather than in a screen for the same reason every other
/// outside-the-app call does: `lib/features/**` describes what a woman sees,
/// and never reaches past the phone by itself.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_l10n.dart';
import 'honest_notice.dart';

/// Opens [url] in her browser. Says so plainly if it cannot, rather than
/// leaving a tap that appears to have done nothing.
Future<void> openExternalLink(BuildContext context, String url) async {
  if (url.isEmpty) return;
  final text = AppL10n.of(context).thatPageCouldNotBeOpenedTry;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && messenger != null && context.mounted) {
    showHonestNotice(context, text);
  }
}
