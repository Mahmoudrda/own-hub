/// What a thread draws: bubbles with tails, ticks, day separators, system
/// lines and the cards for plans, recipes and live sessions.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/chat_message.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/session_link.dart';
import '../../domain/subscription.dart';
import '../coaching_when.dart';
import 'chat_logic.dart';

const double _tailWidth = 7;
const double _minTarget = 48;

String tickWord(AppL10n l10n, ChatTick tick) => switch (tick) {
  ChatTick.pending => l10n.sending,
  ChatTick.sent => l10n.sent,
  ChatTick.read => l10n.seen,
};

/// The tick under a line of hers: a clock, one tick, or two.
class TickIcon extends StatelessWidget {
  const TickIcon(this.tick, {super.key});

  final ChatTick tick;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (tick) {
      ChatTick.pending => (Icons.access_time, AppColors.onSurfaceVariant),
      ChatTick.sent => (Icons.done, AppColors.onSurfaceVariant),
      ChatTick.read => (Icons.done_all, AppColors.primary),
    };
    return Icon(icon, size: 16, color: color);
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.color,
    required this.outline,
    required this.tail,
    required this.tailOnRight,
  });

  final Color color;
  final Color? outline;
  final bool tail;
  final bool tailOnRight;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 14.0;
    final left = !tailOnRight ? _tailWidth : 0.0;
    final right = size.width - (tailOnRight ? _tailWidth : 0.0);
    final body = RRect.fromLTRBAndCorners(
      left,
      0,
      right,
      size.height,
      topLeft: const Radius.circular(radius),
      topRight: const Radius.circular(radius),
      bottomLeft: const Radius.circular(radius),
      bottomRight: const Radius.circular(radius),
    );
    final path = Path()..addRRect(body);
    if (tail) {
      final tip = Path();
      if (tailOnRight) {
        tip
          ..moveTo(right - 2, 0)
          ..lineTo(size.width, 0)
          ..quadraticBezierTo(right + 1, 3, right, 12)
          ..close();
      } else {
        tip
          ..moveTo(left + 2, 0)
          ..lineTo(0, 0)
          ..quadraticBezierTo(left - 1, 3, left, 12)
          ..close();
      }
      path.addPath(tip, Offset.zero);
    }
    canvas.drawPath(path, Paint()..color = color);
    final line = outline;
    if (line != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.color != color ||
      old.outline != outline ||
      old.tail != tail ||
      old.tailOnRight != tailOnRight;
}

/// Mine sits at the end of the row (right in English, left in Arabic), hers at
/// the start.
class ChatRow extends StatelessWidget {
  const ChatRow({
    super.key,
    required this.mine,
    required this.tail,
    required this.child,
    required this.palette,
  });

  final bool mine;
  final bool tail;
  final Widget child;

  /// Fill and outline of the bubble.
  final (Color fill, Color? outline) palette;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final onRight = mine != rtl;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.only(top: tail ? 6 : 2, bottom: 1),
      child: Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * 0.82),
          child: CustomPaint(
            painter: _BubblePainter(
              color: palette.$1,
              outline: palette.$2,
              tail: tail,
              tailOnRight: onRight,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                (!onRight ? _tailWidth : 0) + 10,
                7,
                (onRight ? _tailWidth : 0) + 10,
                5,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

(Color, Color?) paletteOf(bool mine) => mine
    ? (AppColors.primaryContainer, null)
    : (AppColors.surfaceLowest, AppColors.borderWarm);

/// Time, and for her own lines the tick.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.at, required this.tick});

  final DateTime? at;
  final ChatTick? tick;

  @override
  Widget build(BuildContext context) {
    final time = at;
    final l10n = AppL10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (time != null)
          Text(
            clockOf(l10n, time),
            style: AppText.nav.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (tick != null) ...[const SizedBox(width: 4), TickIcon(tick!)],
      ],
    );
  }
}

/// A text line.
class TextBubble extends StatelessWidget {
  const TextBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.tail,
    required this.tick,
    required this.who,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final bool tail;
  final ChatTick tick;

  /// The sender as a screen reader says it.
  final String who;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final at = message.createdAt;
    final spoken = <String>[
      who,
      message.text,
      ?(at == null ? null : clockOf(l10n, at)),
      if (mine) tickWord(l10n, tick),
    ].join(', ');
    final rtlText = Bidi.detectRtlDirectionality(message.text);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: spoken,
      onLongPress: onLongPress,
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ChatRow(
          mine: mine,
          tail: tail,
          palette: paletteOf(mine),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    message.text,
                    textDirection: rtlText
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: AppText.body.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(height: 2),
                _Stamp(at: at, tick: mine ? tick : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred pill: a day separator, a system line or the hidden notice.
class NoticePill extends StatelessWidget {
  const NoticePill(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: text,
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AppText.nav.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A card inside a bubble: icon, a label, a title and an action.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.icon,
    required this.label,
    this.title,
    this.lines = const <String>[],
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String label;
  final String? title;
  final List<String> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppText.label.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
      if (title != null && title!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            isolated(context, title!),
            style: AppText.titleS.copyWith(color: AppColors.ink),
          ),
        ),
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            line,
            style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        ),
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, runSpacing: 4, children: actions),
        ),
    ],
  );
}

class _CardAction extends StatelessWidget {
  const _CardAction(this.label, this.onPressed, {this.filled = false});

  final String label;
  final VoidCallback onPressed;

  /// A small filled button for the main answer on a card.
  final bool filled;

  @override
  Widget build(BuildContext context) => filled
      ? FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(_minTarget, _minTarget),
            backgroundColor: AppColors.actionPrimary,
            foregroundColor: AppColors.onActionPrimary,
            textStyle: AppText.label,
          ),
          child: Text(label),
        )
      : TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(_minTarget, _minTarget),
            foregroundColor: AppColors.primary,
            textStyle: AppText.label,
          ),
          child: Text(label),
        );
}

/// A name written in one direction inside a line in the other keeps its own
/// order: first-strong isolates, only needed (and only added) right to left.
String isolated(BuildContext context, String name) =>
    Directionality.of(context) == TextDirection.rtl
    ? '\u2068$name\u2069'
    : name;

/// A shared workout or meal plan, a recipe or a live session.
class CardBubble extends StatelessWidget {
  const CardBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.tail,
    required this.tick,
    required this.who,
    required this.now,
    this.session,
    this.recipeTitle,
    this.onOpenPlan,
    this.onOpenRecipe,
    this.onJoin,
    this.onConfirm,
    this.onDecline,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final bool tail;
  final ChatTick tick;
  final String who;
  final DateTime now;

  /// The live-session document for a session card, once it has loaded.
  final LiveSession? session;
  final String? recipeTitle;
  final void Function(ChatMessage message)? onOpenPlan;
  final void Function(String recipeId)? onOpenRecipe;
  final void Function(String link)? onJoin;
  final void Function(String sessionId)? onConfirm;
  final void Function(String sessionId)? onDecline;
  final VoidCallback? onLongPress;

  String _when(AppL10n l10n, DateTime at) => coachWhen(l10n, at);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final at = message.createdAt;
    final (body, summary) = _body(context, l10n);
    final spoken = <String>[
      who,
      summary,
      ?(at == null ? null : clockOf(l10n, at)),
      if (mine) tickWord(l10n, tick),
    ].join(', ');
    return Semantics(
      container: true,
      label: spoken,
      onLongPress: onLongPress,
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ChatRow(
          mine: mine,
          tail: tail,
          palette: paletteOf(mine),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: AlignmentDirectional.centerStart, child: body),
                const SizedBox(height: 2),
                _Stamp(at: at, tick: mine ? tick : null),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Widget, String) _body(BuildContext context, AppL10n l10n) {
    switch (message.type) {
      case MessageType.workoutPlan:
      case MessageType.mealPlan:
        final workout = message.type == MessageType.workoutPlan;
        final label = workout ? l10n.workoutPlan : l10n.mealPlan;
        final name = message.planName ?? '';
        return (
          _CardBody(
            icon: workout ? Icons.fitness_center : Icons.restaurant_menu,
            label: label,
            title: name,
            actions: [
              if (onOpenPlan != null)
                _CardAction(l10n.open, () => onOpenPlan!(message)),
            ],
          ),
          '$label $name'.trim(),
        );
      case MessageType.recipe:
        final id = message.recipeId;
        return (
          _CardBody(
            icon: Icons.menu_book_outlined,
            label: l10n.recipe,
            title: recipeTitle,
            actions: [
              if (onOpenRecipe != null && id != null)
                _CardAction(l10n.open, () => onOpenRecipe!(id)),
            ],
          ),
          '${l10n.recipe} ${recipeTitle ?? ''}'.trim(),
        );
      case MessageType.session:
        final start = message.startsAt;
        final minutes = message.minutes;
        final sessionId = message.sessionId;
        final live = session;
        final lines = <String>[
          ?(start == null ? null : _when(l10n, start.toLocal())),
          ?(minutes == null ? null : l10n.minutesMin('$minutes')),
          if (live != null) _statusWord(l10n, live.status),
        ];
        final joinable =
            live != null &&
            live.link.isNotEmpty &&
            (live.status == SessionStatus.confirmed || mine);
        final confirmable =
            live != null &&
            live.status == SessionStatus.proposed &&
            !mine &&
            sessionId != null;
        return (
          _CardBody(
            icon: Icons.videocam_outlined,
            label: l10n.liveSession,
            lines: lines,
            actions: [
              if (joinable && onJoin != null)
                _CardAction(l10n.joinTheCall, () {
                  if (sessionLinkAllowed(live.link)) onJoin!(live.link);
                }),
              if (confirmable && onConfirm != null)
                _CardAction(
                  l10n.confirm,
                  () => onConfirm!(sessionId),
                  filled: true,
                ),
              if (confirmable && onDecline != null)
                _CardAction(l10n.cantMakeIt, () => onDecline!(sessionId)),
            ],
          ),
          '${l10n.liveSession} ${lines.join(', ')}',
        );
      case MessageType.text:
      case MessageType.system:
        return (const SizedBox.shrink(), '');
    }
  }

  static String _statusWord(AppL10n l10n, SessionStatus status) =>
      switch (status) {
        SessionStatus.proposed => l10n.waitingForConfirmation,
        SessionStatus.confirmed => l10n.confirmed,
        SessionStatus.declined => l10n.declined,
        SessionStatus.done => l10n.finished,
        SessionStatus.cancelled => l10n.cancelled,
      };
}
