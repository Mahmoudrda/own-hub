/// A coach and client thread, laid out the way a messaging app is: bubbles,
/// day separators, ticks, a composer and, for the coach, a "+" to share.
///
/// Built from callbacks, so wiring it into a route is one builder: the
/// repository and ids come from the relationship, the people from whoever
/// knows their names, the share and open actions from the screens they open.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app_state/open_link.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/hand/mascot/kitten.dart';
import '../../../account/domain/safety.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';
import '../../domain/chat_screen.dart';
import '../../domain/coaching_contract.dart';
import '../member/coach_card.dart';
import '../member/report_coach_sheet.dart';
import 'chat_bubbles.dart';
import 'chat_logic.dart';
import 'chat_sheets.dart';
import 'chat_thread_controller.dart';

class ChatThreadView extends StatefulWidget {
  const ChatThreadView({
    super.key,
    required this.repository,
    required this.relId,
    required this.myUid,
    required this.person,
    this.otherIsCoach = false,
    this.subId,
    this.open = true,
    this.blocks,
    this.share = const ShareChoices(),
    this.recipeTitleOf,
    this.onOpenPlan,
    this.onOpenRecipe,
    this.onOpenLink,
    this.onBack,
    this.now,
    this.markDelay = const Duration(seconds: 2),
    this.unreadAtOpen,
  });

  final ChatThreadRepository repository;
  final String relId;
  final String myUid;
  final ChatPerson person;

  /// The other person is the coach: Report goes to her profile.
  final bool otherIsCoach;

  /// The active subscription, so a client can confirm a live session.
  final String? subId;

  /// False once the coaching ended: the thread is read-only.
  final bool open;

  /// The app's block list. Without it the menu has no Block.
  final BlockService? blocks;

  /// The coach's "+" sheet; empty for a client.
  final ShareChoices share;
  final String? Function(String recipeId)? recipeTitleOf;
  final void Function(ChatMessage plan)? onOpenPlan;
  final void Function(String recipeId)? onOpenRecipe;

  /// Opens a call link; the browser by default.
  final void Function(String link)? onOpenLink;
  final VoidCallback? onBack;
  final DateTime Function()? now;
  final Duration markDelay;

  /// Her unread lines in the relationship document when the thread opens.
  final int? unreadAtOpen;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

enum _Menu { report, block }

class _ChatThreadViewState extends State<ChatThreadView>
    with WidgetsBindingObserver {
  late final ChatThreadController _controller;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  ChatScreenReason? _refused;
  bool _sendFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = ChatThreadController(
      repository: widget.repository,
      relId: widget.relId,
      myUid: widget.myUid,
      otherUid: widget.person.uid,
      subId: widget.subId,
      open: widget.open,
      otherIsCoach: widget.otherIsCoach,
      now: widget.now,
      markDelay: widget.markDelay,
      unreadAtOpen: widget.unreadAtOpen,
    )..addListener(_onChange);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onChange)
      ..dispose();
    _scroll.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.foreground = state == AppLifecycleState.resumed;
  }

  void _onChange() {
    if (!mounted) return;
    final failed = _controller.takeSendFailure();
    if (failed != null) {
      // The server refused a line that was already cleared: give it back.
      if (_text.text.isEmpty) _text.text = failed.text;
      _sendFailed = true;
    }
    setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _controller.scrolledUp(position.pixels > 80);
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_controller.loadOlder());
    }
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    unawaited(
      _scroll.animateTo(
        0,
        duration: AppMotion.short,
        curve: AppMotion.emphasized,
      ),
    );
  }

  bool _rulesAccepted = false;
  bool _checkingRules = false;

  /// A client sees the chat rules once, before her first message, and her tick
  /// is recorded. False when she did not agree or the tick could not be saved.
  Future<bool> _rulesOk() async {
    if (_rulesAccepted || !widget.otherIsCoach) return true;
    if (_checkingRules) return false;
    _checkingRules = true;
    final l10n = AppL10n.of(context);
    try {
      if (!await widget.repository.chatRulesAccepted()) {
        if (!mounted || !await showChatRulesSheet(context)) return false;
        await widget.repository.acceptChatRules(
          rulesText: chatRulesText(l10n),
          locale: l10n.localeName.startsWith('ar') ? 'ar' : 'en',
        );
      }
      _rulesAccepted = true;
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.weCouldNotSaveYourAnswerTry)),
        );
      }
      return false;
    } finally {
      _checkingRules = false;
    }
  }

  Future<void> _send() async {
    if (!await _rulesOk() || !mounted) return;
    final outcome = _controller.send(_text.text);
    switch (outcome) {
      case Sent():
        _text.clear();
        setState(() {
          _refused = null;
          _sendFailed = false;
        });
        _toBottom();
      case Refused(:final reason):
        setState(() => _refused = reason);
      case NothingToSend():
        break;
    }
  }

  String _refusalText(AppL10n l10n, ChatScreenReason reason) =>
      switch (reason) {
        ChatScreenReason.contact => l10n.phoneNumbersCantBeSentInThe,
        ChatScreenReason.payment => l10n.paymentDetailsCantBeSharedInThe,
        ChatScreenReason.link => l10n.linksCantBeSentInTheChat,
        ChatScreenReason.abuse => l10n.someWordsInThisMessageArentAllowed,
      };

  // ---------------------------------------------------------------- menu

  Future<void> _reportProfileOrLatest() async {
    final l10n = AppL10n.of(context);
    final locale = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    if (widget.otherIsCoach) {
      await showReportCoachSheet(
        context: context,
        repository: widget.repository,
        coachUid: widget.person.uid,
      );
      return;
    }
    final latest = _controller.lastFromOther;
    if (latest == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.thereIsNoMessageFromHerTo)));
      return;
    }
    await showChatReportSheet(
      context,
      onSend: (reason, note) => _controller.reportMessage(
        latest,
        reason: reason,
        note: note,
        locale: locale,
      ),
    );
  }

  Future<void> _block() async {
    final blocks = widget.blocks;
    if (blocks == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final ok = await confirmBlock(context, widget.person.name);
    if (!ok) return;
    await _controller.block(blocks);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.nameIsBlocked(widget.person.name))),
    );
    unawaited(navigator.maybePop());
  }

  Future<void> _longPress(ChatMessage message) async {
    final l10n = AppL10n.of(context);
    final locale = l10n.localeName.startsWith('ar') ? 'ar' : 'en';
    final mine = message.isMine(widget.myUid);
    await showLineSheet(
      context,
      text: message.showsText ? message.text : null,
      onReport: mine || message.type == MessageType.system
          ? null
          : () => showChatReportSheet(
              context,
              onSend: (reason, note) => _controller.reportMessage(
                message,
                reason: reason,
                note: note,
                locale: locale,
              ),
            ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              person: widget.person,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              menu: _menu(l10n),
            ),
            const Divider(height: 1, color: AppColors.borderWarm),
            Expanded(child: _body(l10n)),
            if (widget.open) _composer(l10n) else _ClosedBanner(l10n: l10n),
          ],
        ),
      ),
    );
  }

  Widget _menu(AppL10n l10n) => PopupMenuButton<_Menu>(
    tooltip: l10n.moreOptions,
    icon: const Icon(Icons.more_vert, color: AppColors.ink),
    onSelected: (item) {
      switch (item) {
        case _Menu.report:
          unawaited(_reportProfileOrLatest());
        case _Menu.block:
          unawaited(_block());
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: _Menu.report, child: Text(l10n.report)),
      if (widget.blocks != null)
        PopupMenuItem(value: _Menu.block, child: Text(l10n.block)),
    ],
  );

  Widget _body(AppL10n l10n) {
    if (_controller.failed && !_controller.loaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.weCouldNotLoadThisChatCheck,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _controller.retry,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.tryAgain),
              ),
            ],
          ),
        ),
      );
    }
    if (!_controller.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final lines = _controller.lines;
    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Kitten(
                pose: KittenPose.wave,
                size: 72,
                moment: 'chat-empty',
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noMessagesYetSayHello,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    final now = _controller.now;
    final items = buildItems(lines, myUid: widget.myUid, now: now);
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _controller.loadingOlder
                  ? Semantics(
                      label: l10n.loadingOlderMessages,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(height: 4);
            }
            return _item(context, l10n, items[index], now);
          },
        ),
        if (_controller.unseen > 0)
          PositionedDirectional(
            bottom: 12,
            end: 16,
            child: _NewPill(
              label: l10n.newMessages,
              onTap: () {
                _controller.scrolledUp(false);
                _toBottom();
              },
            ),
          ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    AppL10n l10n,
    ChatItem item,
    DateTime now,
  ) {
    switch (item) {
      case DayItem(:final at):
        return NoticePill(dayLabel(l10n, at, now));
      case LineItem(:final message, :final tail, :final mine):
        if (message.hidden) {
          return NoticePill(
            l10n.thisMessageWasHiddenBecauseItHad,
            icon: Icons.visibility_off_outlined,
          );
        }
        if (message.type == MessageType.system) {
          return NoticePill(systemLine(l10n, message.systemKind));
        }
        final who = mine ? l10n.you : widget.person.name;
        final tick = tickOf(message, _controller.otherReadAt);
        final press = message.pending ? null : () => _longPress(message);
        if (message.type == MessageType.text) {
          return TextBubble(
            message: message,
            mine: mine,
            tail: tail,
            tick: tick,
            who: who,
            onLongPress: press,
          );
        }
        return CardBubble(
          message: message,
          mine: mine,
          tail: tail,
          tick: tick,
          who: who,
          now: now,
          session: _controller.sessions[message.sessionId],
          recipeTitle: message.recipeId == null
              ? null
              : widget.recipeTitleOf?.call(message.recipeId!),
          onOpenPlan: widget.onOpenPlan,
          onOpenRecipe: widget.onOpenRecipe,
          onJoin:
              widget.onOpenLink ?? (link) => openExternalLink(context, link),
          onConfirm: (id) => unawaited(_controller.confirmSession(id)),
          onDecline: (id) => unawaited(_controller.declineSession(id)),
          onLongPress: press,
        );
    }
  }

  Widget _composer(AppL10n l10n) {
    final refused = _refused;
    return Material(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refused != null || _sendFailed)
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amberContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  refused != null
                      ? _refusalText(l10n, refused)
                      : l10n.yourMessageCouldNotBeSentTry,
                  style: AppText.bodyM.copyWith(color: AppColors.ink),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.share.any)
                  IconButton(
                    tooltip: l10n.shareSomething,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    onPressed: () => showShareSheet(context, widget.share),
                  ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: CoachingLimits.messageMaxChars,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {
                      _refused = null;
                      _sendFailed = false;
                    }),
                    style: AppText.body.copyWith(color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: l10n.message,
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surfaceLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.send,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.send),
                  color: AppColors.primary,
                  onPressed: _text.text.trim().isEmpty
                      ? null
                      : () => unawaited(_send()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.person,
    required this.onBack,
    required this.menu,
  });

  final ChatPerson person;
  final VoidCallback onBack;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final subtitle = person.subtitle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.back,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.arrow_back),
            color: AppColors.ink,
            onPressed: onBack,
          ),
          CoachPhoto(name: person.name, photoUrl: person.photoUrl, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              container: true,
              label: <String>[person.name, ?subtitle].join(', '),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleM.copyWith(color: AppColors.ink),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.nav.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          menu,
        ],
      ),
    );
  }
}

class _NewPill extends StatelessWidget {
  const _NewPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.onPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppText.label.copyWith(color: AppColors.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: false,
    child: Container(
      width: double.infinity,
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(16),
      child: Text(
        l10n.thisCoachingHasEndedYouCanRead,
        textAlign: TextAlign.center,
        style: AppText.bodyM.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );
}
