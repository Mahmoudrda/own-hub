/// Pieces shared by the G screens, built once so they cannot drift apart.
///
/// The prototype defines `coachRow()`, `dateStrip()`, `setRow()` and `bubble()`
/// at the top of `6-v2/src/screens-coached.mjs` because each appears on several
/// screens and must stay identical across all of them. They are feature-local
/// rather than `lib/ui/` primitives for the same reason they are local in the
/// prototype: a chat bubble and a prescribed/actual row are this flow's
/// vocabulary, not the product's.
///
/// **Every string here arrives as a parameter.** Nothing in this file reaches
/// for the dictionary on its own, so a widget cannot become a second place copy
/// lives.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;

/// The bottom bar the coaching screens carry.
///
/// The prototype writes `navBar('Coaching')`, and there is **no Coaching tab**:
/// `app_nav_bar.dart` records why in full — it was the fifth tab, it pointed at
/// `H01`, and D11 moved hiring a coach into her profile because "hiring a coach
/// and being a coach are different things, and only the second one is a role".
///
/// So Home stays active here, exactly as it does on My cycle, which is reached
/// the same way. Marking a tab active that the bar does not have would light
/// nothing and leave her unable to tell which tab she is on.
class CoachedNavBar extends StatelessWidget {
  const CoachedNavBar({super.key, this.onSelectTab});

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    return AppNavBar(
      activeScreenId: 'T01',
      onSelect: (id) {
        final onTab = onSelectTab;
        if (onTab != null) {
          onTab(id);
          return;
        }
        openScreen(context, id);
      },
    );
  }
}

/// The coach's row: her photo, her name, her hours, and a way to message her.
///
/// `coachRow()` in the prototype. The verified tick sits next to her name
/// because that is what she is being trusted for.
class CoachRow extends StatelessWidget {
  const CoachRow({
    super.key,
    required this.name,
    required this.detail,
    this.onMessage,
    this.messageTooltip,
  });

  final String name;

  /// Her working hours and reply promise, as one line. Empty renders nothing.
  final String detail;

  final VoidCallback? onMessage;
  final String? messageTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            name.isEmpty ? '' : name.characters.first.toUpperCase(),
            style: AppText.titleM.copyWith(color: AppColors.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(name, style: AppText.titleM)),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.verified,
                    size: 16,
                    color: AppColors.primaryDim,
                  ),
                ],
              ),
              // Empty renders nothing rather than a blank line: a detail we
              // were not given is absent, not a gap where the mockup's
              // sample hours used to sit.
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onMessage != null) ...[
          const SizedBox(width: 12),
          // Ringed in pencil rather than set on a filled disc — the same ring
          // every leading icon in a list wears.
          IconButton(
            onPressed: onMessage,
            tooltip: messageTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const HandIconRing(
              seed: 11,
              size: 44,
              icon: Icon(
                Icons.chat_bubble_outline,
                size: 22,
                color: AppColors.primaryDim,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One day in G04's strip: a weekday and a date, stacked.
@immutable
class StripDay {
  const StripDay({required this.weekday, required this.dayOfMonth});

  /// "Sat", from the dictionary — never built from a date by this widget.
  final String weekday;

  /// The number, as a value. Digits stay Western in both languages.
  final String dayOfMonth;
}

/// The week strip across the top of the coaching tab. `dateStrip()`.
class CoachedDateStrip extends StatelessWidget {
  const CoachedDateStrip({
    super.key,
    required this.days,
    required this.selectedIndex,
    this.onSelect,
  });

  final List<StripDay> days;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          // The chosen day is a block of ink; the others are slips of paper
          // framed in pencil, each cut a little differently.
          Expanded(
            child: HandSurface(
              seed: handSeed(['strip-day', i, days[i].dayOfMonth]),
              fill: i == selectedIndex
                  ? AppColors.primary
                  : AppColors.surfaceLowest,
              frame: i == selectedIndex
                  ? null
                  : AppColors.outline.withValues(alpha: 0.55),
              frameWidth: 1.05,
              radius: 5,
              looseCorner: 13,
              onTap: onSelect == null ? null : () => onSelect!(i),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                children: [
                  Text(
                    days[i].weekday,
                    style: AppText.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    days[i].dayOfMonth,
                    style: AppText.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One set on G06: what her coach prescribed, and what she actually did.
///
/// The two are side by side and they are **never the same field**. The actual
/// column shows [actual] only when she has logged something; until then it says
/// [notYetLabel] in words, which is an absence rather than a zero.
class PrescribedActualRow extends StatelessWidget {
  const PrescribedActualRow({
    super.key,
    required this.label,
    required this.prescribed,
    required this.actual,
    required this.prescribedLabel,
    required this.actualLabel,
    this.notYetLabel = '',
    this.done = false,
    this.current = false,
  });

  /// "Set 2".
  final String label;

  /// "12 kg × 12" — what was asked for.
  final String prescribed;

  /// What she did, or null when she has not logged this set.
  final String? actual;

  /// The dictionary's word for the left column.
  final String prescribedLabel;

  /// The dictionary's word for the right column.
  final String actualLabel;

  /// What the right column says before she has logged the set.
  final String notYetLabel;

  final bool done;
  final bool current;

  // A done set is a plain slip of sage, the set she is on is ringed in ink,
  // and the rest wait on white paper framed in pencil — the same three
  // kinds of line as the coach's own first-week list.
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: HandSurface(
        seed: handSeed(['set-row', label]),
        fill: done ? AppColors.tertiaryContainer : AppColors.surfaceLowest,
        frame: done
            ? null
            : current
            ? AppColors.primary
            : AppColors.outline.withValues(alpha: 0.55),
        frameWidth: current ? 2 : 1.05,
        level: current ? HandLevel.expressive : HandLevel.crafted,
        radius: 5,
        looseCorner: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            done
                ? const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.tertiary,
                  )
                : HandCircled(
                    seed: label.hashCode,
                    level: HandLevel.crafted,
                    width: current ? HandStroke.pen : 1.1,
                    color: current
                        ? AppColors.primary
                        : AppColors.outline.withValues(alpha: 0.75),
                    inflate: EdgeInsets.zero,
                    child: const SizedBox.square(dimension: 20),
                  ),
            const SizedBox(width: 10),
            // Every part of this row can give. In Arabic "prescribed" and "you
            // did" are longer words, and with the two columns at their intrinsic
            // width the row overflowed by 51 pixels — off the side of the screen,
            // taking her actual numbers with it. The set row is the one place in
            // this flow where a truncated number would be a wrong number, so the
            // label yields first and the columns yield second.
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Flexible(
              child: _Column(title: prescribedLabel, value: prescribed),
            ),
            // A separator between two figures that are already labelled, so
            // it is decoration and takes `outlineVariant` rather than the
            // boundary role.
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.outlineVariant,
            ),
            Flexible(
              child: _Column(
                title: actualLabel,
                value: actual ?? notYetLabel,
                // An unlogged set is grey, not green: it is not an achievement of
                // zero, it is an absence.
                valueColour: actual == null
                    ? AppColors.onSurfaceVariant
                    : AppColors.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.value,
    this.valueColour = AppColors.onSurface,
  });

  final String title;
  final String value;
  final Color valueColour;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        Text(
          value,
          maxLines: 1,
          style: AppText.label.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColour,
          ),
        ),
      ],
    );
  }
}

/// A chat bubble. `bubble()` in the prototype.
///
/// [state] is the delivery state as she reads it — "Delivered", "Read", or the
/// queued wording. It is a string rather than an enum because the words are the
/// dictionary's and the widget must not choose between them.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    this.text,
    this.mine = false,
    this.state,
    this.attachmentLabel,
    this.onOpenAttachment,
    this.voiceDuration,
    this.voicePlayTooltip,
    this.queued = false,
  });

  final String? text;
  final bool mine;

  /// "Delivered", "Read", or the queued wording. Null shows nothing.
  final String? state;

  /// The record this bubble refers to — "Thursday · full-body strength".
  final String? attachmentLabel;

  /// Opens that record. A bubble points at a record; it is not a picture of one.
  final VoidCallback? onOpenAttachment;

  /// "0:24" for a voice note. A value, not copy.
  final String? voiceDuration;

  final String? voicePlayTooltip;

  /// Waiting to sync. Full opacity plus the cloud glyph, per G8's convention —
  /// never a dimmed row, because what she wrote is not provisional.
  final bool queued;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (attachmentLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AppListItem(
                  title: attachmentLabel!,
                  onTap: onOpenAttachment,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  leading: const Icon(
                    Icons.fitness_center,
                    size: 20,
                    color: AppColors.primaryDim,
                  ),
                ),
              ),
            // Hers on blush, her coach's on white paper framed in pencil,
            // each with its one loose corner on the side it was sent from.
            HandSurface(
              seed: handSeed(['bubble', text ?? voiceDuration ?? '']),
              looseAt: mine ? HandCorner.bottomEnd : HandCorner.bottomStart,
              fill: mine ? AppColors.primaryContainer : AppColors.surfaceLowest,
              frame: mine ? null : AppColors.outline.withValues(alpha: 0.55),
              frameWidth: 1.05,
              radius: 6,
              looseCorner: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: voiceDuration != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 20,
                          color: AppColors.primaryDim,
                          semanticLabel: voicePlayTooltip,
                        ),
                        const SizedBox(width: 8),
                        const _Waveform(),
                        const SizedBox(width: 8),
                        Text(
                          voiceDuration!,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Text(text ?? '', style: AppText.body),
            ),
            if (state != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (queued) ...[
                      const Icon(
                        Icons.cloud_queue,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      state!,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The little bars behind a voice note. Decoration, and it carries no meaning —
/// a real waveform of her voice would be a second copy of it.
class _Waveform extends StatelessWidget {
  const _Waveform();

  static const List<double> _heights = [
    10,
    16,
    22,
    14,
    20,
    12,
    18,
    10,
    14,
    8,
    16,
    12,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final h in _heights)
          Container(
            width: 3,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// A system chip in the thread — "Plan updated · Thursday 18 September".
///
/// Visibly **separate from what the coach wrote**: centred, pill-shaped, in the
/// restorative green rather than in either party's bubble colour. A plan change
/// is not a message and must not be able to look like one.
class PlanUpdatedChip extends StatelessWidget {
  const PlanUpdatedChip({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  // A swipe of sage marker across the thread rather than a bubble: the
  // system noting something in the margin, in neither party's colour.
  @override
  Widget build(BuildContext context) {
    final chip = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: MarkerHighlight(
        color: AppColors.tertiaryContainer,
        cover: 0.78,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.tertiary,
            ),
          ),
        ),
      ),
    );
    return Center(
      child: onTap == null
          ? chip
          : HandPressable(onTap: onTap, builder: (_, _) => chip),
    );
  }
}

/// A row of key and value — `kv()` in the prototype.
class CoachedKeyValue extends StatelessWidget {
  const CoachedKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  // Ruled underneath in pencil, like a line in a ledger; the last line
  // stands open.
  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      // A split row, so a long value moves to its own line instead of
      // running off the page.
      child: AppSplitRow(
        start: Text(
          label,
          style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
        ),
        end: Text(
          value,
          style: AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
    if (last) return line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        HandRule(seed: handSeed(['kv', label]), height: 3),
      ],
    );
  }
}

/// The composer at the bottom of G14 and G15.
///
/// When [enabled] is false it renders [closedNotice] instead: an ended
/// relationship is readable and its composer is closed with a plain
/// explanation, never a control that fails when she taps it.
class CoachedComposer extends StatelessWidget {
  const CoachedComposer({
    super.key,
    required this.hint,
    this.onAttach,
    this.onVoice,
    this.enabled = true,
    this.closedNotice,
    this.attachTooltip,
    this.voiceTooltip,
    this.onSendText,
    this.sendTooltip,
  });

  final String hint;
  final VoidCallback? onAttach;
  final VoidCallback? onVoice;
  final bool enabled;
  final String? closedNotice;
  final String? attachTooltip;
  final String? voiceTooltip;

  /// Supplied by a host that can actually store a message.
  ///
  /// Without it the row is the prototype's: a hint, a paperclip and a mic,
  /// and nothing that pretends to send. With it the hint becomes a field and
  /// the mic makes room for a send arrow carrying her words.
  final ValueChanged<String>? onSendText;
  final String? sendTooltip;

  @override
  Widget build(BuildContext context) {
    if (onSendText case final send?) {
      if (enabled) {
        return _WritableComposer(
          hint: hint,
          onAttach: onAttach,
          attachTooltip: attachTooltip,
          sendTooltip: sendTooltip,
          onSendText: send,
        );
      }
    }
    if (!enabled) {
      return AppCard(
        variant: AppCardVariant.filled,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          Text(
            closedNotice ?? hint,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: AppRadius.full,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onAttach,
              tooltip: attachTooltip,
              iconSize: 22,
              color: AppColors.primaryDim,
              icon: const Icon(Icons.add),
            ),
            Expanded(
              child: Text(
                hint,
                style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            IconButton(
              onPressed: onVoice,
              tooltip: voiceTooltip,
              iconSize: 22,
              color: AppColors.primaryDim,
              icon: const Icon(Icons.mic_none),
            ),
          ],
        ),
      ],
    );
  }
}

/// The composer once there is somewhere to put her message.
///
/// The same pill, the same paperclip and the same hint — a field where the
/// hint was, and the mic replaced by a send arrow that is dark only when she
/// has written something. The mic stays absent rather than inert: there is no
/// recorder in this build, and `G15` says so on its own screen.
class _WritableComposer extends StatefulWidget {
  const _WritableComposer({
    required this.hint,
    required this.onSendText,
    this.onAttach,
    this.attachTooltip,
    this.sendTooltip,
  });

  final String hint;
  final ValueChanged<String> onSendText;
  final VoidCallback? onAttach;
  final String? attachTooltip;
  final String? sendTooltip;

  @override
  State<_WritableComposer> createState() => _WritableComposerState();
}

class _WritableComposerState extends State<_WritableComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final words = _controller.text.trim();
    if (words.isEmpty) return;
    widget.onSendText(words);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: AppRadius.full,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onAttach,
              tooltip: widget.attachTooltip,
              iconSize: 22,
              color: AppColors.primaryDim,
              icon: const Icon(Icons.add),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                style: AppText.body.copyWith(color: AppColors.onSurface),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: AppText.body.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _controller.text.trim().isEmpty ? null : _send,
              tooltip: widget.sendTooltip,
              iconSize: 22,
              color: AppColors.primaryDim,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
