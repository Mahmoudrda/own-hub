/// The "…" button: rare and destructive actions in one bottom sheet instead of
/// on the screen itself.
///
/// A destructive row never fires on the first tap. The sheet swaps to a short
/// question with the action and a way back, so there is no system dialog and
/// the woman stays in the same place.
library;

import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_list_item.dart';
import 'app_sheet.dart';
import 'hand/hand.dart';

class AppOverflowItem {
  const AppOverflowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.confirmMessage,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// When set the row is destructive: tapping it asks this question first, and
  /// [onTap] runs only once she confirms with the row's own label.
  final String? confirmMessage;
}

class AppOverflowMenu extends StatelessWidget {
  const AppOverflowMenu({super.key, required this.items, this.color});

  final List<AppOverflowItem> items;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final label = AppL10n.of(context).moreOptions;
    return IconButton(
      key: const ValueKey('overflow-menu'),
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(Icons.more_horiz, color: color ?? AppColors.onSurface),
      onPressed: () => showAppSheet<void>(
        context: context,
        gap: 8,
        children: [_OverflowBody(items: items)],
      ),
    );
  }
}

class _OverflowBody extends StatefulWidget {
  const _OverflowBody({required this.items});

  final List<AppOverflowItem> items;

  @override
  State<_OverflowBody> createState() => _OverflowBodyState();
}

class _OverflowBodyState extends State<_OverflowBody> {
  AppOverflowItem? _asking;

  void _run(AppOverflowItem item) {
    Navigator.of(context).pop();
    item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final asking = _asking;
    return AnimatedSwitcher(
      duration: handMotionOff(context) ? Duration.zero : HandTiming.pressOut,
      switchInCurve: HandTiming.standard,
      child: asking == null
          ? Column(
              key: const ValueKey('overflow-list'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in widget.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppListItem(
                      key: ValueKey('overflow-row-${item.label}'),
                      title: item.label,
                      leading: Icon(
                        item.icon,
                        color: item.confirmMessage == null
                            ? AppColors.onSurface
                            : AppColors.error,
                      ),
                      onTap: item.confirmMessage == null
                          ? () => _run(item)
                          : () => setState(() => _asking = item),
                    ),
                  ),
              ],
            )
          : Column(
              key: const ValueKey('overflow-ask'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  asking.confirmMessage!,
                  key: const ValueKey('overflow-confirm-message'),
                  style: AppText.titleL,
                ),
                const SizedBox(height: 12),
                AppButton(
                  asking.label,
                  key: const ValueKey('overflow-confirm'),
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _run(asking),
                ),
                const SizedBox(height: 4),
                AppButton(
                  l10n.cancel,
                  key: const ValueKey('overflow-cancel'),
                  variant: AppButtonVariant.text,
                  height: 48,
                  onPressed: () => setState(() => _asking = null),
                ),
              ],
            ),
    );
  }
}
