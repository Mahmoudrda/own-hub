/// A coach and client thread, laid out the way a messaging app is: bubbles,
/// day separators, ticks, a composer and, for the coach, a "+" to share.
///
/// Built from callbacks, so wiring it into a route is one builder: the
/// repository and ids come from the relationship, the people from whoever
/// knows their names, the share and open actions from the screens they open.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../app_state/haptics.dart';
import '../../../../app_state/open_link.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../account/domain/safety.dart';
import '../../data/chat_repository.dart';
import '../../data/saved_reply_store.dart';
import '../../domain/chat_message.dart';
import '../../domain/chat_screen.dart';
import '../../domain/coaching_contract.dart';
import '../member/coach_card.dart';
import '../member/report_coach_sheet.dart';
import 'chat_bubbles.dart';
import 'chat_logic.dart';
import 'chat_media_bubbles.dart';
import 'chat_sheets.dart';
import 'chat_thread_controller.dart';
import 'check_in_view.dart';
import 'saved_replies_sheet.dart';
import 'voice_recorder.dart';

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
    this.recorderBuilder,
    this.savedReplyStore,
    this.starterReplies = const <String>[],
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
  final VoiceRecorder Function()? recorderBuilder;
  final SavedReplyStore? savedReplyStore;
  final List<String> starterReplies;

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
  final ImagePicker _picker = ImagePicker();
  VoiceRecorder? _recorder;
  VoiceRecorder get _rec =>
      _recorder ??= (widget.recorderBuilder ?? PluginVoiceRecorder.new)();
  late final SavedReplyStore _replyStore =
      widget.savedReplyStore ?? SavedReplyStore();
  List<SavedReply> _replies = const <SavedReply>[];
  ChatScreenReason? _refused;
  bool _sendFailed = false;
  bool _recording = false;
  bool _cancelArmed = false;

  /// Her finger is on the mic. Set before anything is awaited and cleared on
  /// release, cancel or leaving the app, so a recording that starts late (the
  /// rules sheet, the microphone prompt) never runs without a finger on it.
  bool _pressed = false;
  bool _startingRecord = false;

  /// Set when the two-minute limit stopped the recording. Nothing is sent
  /// until she lets go.
  Future<Uint8List?>? _stopped;
  DateTime? _recordStart;
  int _tickMs = 0;
  Timer? _ticker;
  double _dragX = 0;

  bool get _iAmCoach => !widget.otherIsCoach;

  Future<void> _loadReplies() async {
    if (!_iAmCoach) return;
    final list = await _replyStore.load(widget.myUid, widget.starterReplies);
    if (mounted) setState(() => _replies = list);
  }

  void _useReply(SavedReply reply) {
    final current = _text.text;
    final next = current.trim().isEmpty
        ? reply.text
        : '${current.trimRight()} ${reply.text}';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _editReply(SavedReply? reply) async {
    final text = await showReplyEditor(context, initial: reply?.text);
    if (text == null || !mounted) return;
    final next = <SavedReply>[..._replies];
    if (reply == null) {
      if (text.isNotEmpty && next.length < kSavedReplyMax) {
        next.add(
          SavedReply(
            id: 'r${DateTime.now().microsecondsSinceEpoch}',
            text: text,
          ),
        );
      }
    } else {
      final at = next.indexWhere((r) => r.id == reply.id);
      if (at >= 0) {
        if (text.isEmpty) {
          next.removeAt(at);
        } else {
          next[at] = SavedReply(id: reply.id, text: text);
        }
      }
    }
    setState(() => _replies = next);
    await _replyStore.save(widget.myUid, next);
  }

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
    unawaited(_loadReplies());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    final rec = _recorder;
    if (rec != null) unawaited(rec.dispose());
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
    if (state != AppLifecycleState.resumed) {
      // The microphone prompt and a call take the touch from the button.
      _pressed = false;
      if (_recording) unawaited(_recordEnd(send: false));
    }
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

  Future<void> _pickMedia({
    required bool video,
    required ImageSource source,
  }) async {
    if (!await _rulesOk() || !mounted) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final file = video
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(
                seconds: CoachingLimits.chatVideoMaxSeconds,
              ),
            )
          : await _picker.pickImage(
              source: source,
              maxWidth: CoachingLimits.chatImageLongSidePx.toDouble(),
              maxHeight: CoachingLimits.chatImageLongSidePx.toDouble(),
              imageQuality: 80,
            );
      if (file == null || !mounted) return;
      final limit = video
          ? CoachingLimits.chatVideoMaxBytes
          : CoachingLimits.chatImageMaxBytes;
      // The size and the length are read from the file, not from its bytes in
      // memory: a long clip from the library must not be loaded first.
      if (await file.length() > limit) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              l10n.thatFileIsTooBigAPhoto_1rnt5(
                '${CoachingLimits.chatImageMaxBytes ~/ 1000000}',
                '${CoachingLimits.chatVideoMaxBytes ~/ 1000000}',
              ),
            ),
          ),
        );
        return;
      }
      final durationMs = video ? await _videoMs(file.path) : null;
      if (durationMs != null &&
          durationMs > CoachingLimits.chatVideoMaxSeconds * 1000 + 1000) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              l10n.videosCanBeUpToSecondsSeconds(
                '${CoachingLimits.chatVideoMaxSeconds}',
              ),
            ),
          ),
        );
        return;
      }
      final bytes = await file.readAsBytes();
      final ok = await _controller.sendMedia(
        type: video ? MessageType.video : MessageType.image,
        bytes: bytes,
        contentType: video
            ? (file.path.toLowerCase().endsWith('.mov')
                  ? 'video/quicktime'
                  : 'video/mp4')
            : 'image/jpeg',
        durationMs: durationMs,
      );
      if (!ok) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.weCouldNotSendThatTryAgain)),
        );
      } else {
        _toBottom();
      }
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.weCouldNotSendThatTryAgain)),
      );
    }
  }

  Future<int> _videoMs(String path) async {
    final probe = VideoPlayerController.file(File(path));
    try {
      await probe.initialize();
      return max(500, probe.value.duration.inMilliseconds);
    } finally {
      await probe.dispose();
    }
  }

  Future<void> _recordStartHold() async {
    if (_recording || _startingRecord || !widget.open) return;
    _pressed = true;
    _startingRecord = true;
    try {
      if (!await _rulesOk() || !mounted || !_pressed) return;
      final ok = await _rec.start();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              AppL10n.of(context).allowTheMicrophoneInSettingsToSend,
            ),
          ),
        );
        return;
      }
      if (!_pressed) {
        // She let go, or the prompt took the touch, while the recorder was
        // starting: nothing is kept and nothing is sent.
        await _rec.cancel();
        return;
      }
      unawaited(AppHaptics.play(HapticMoment.actionDone));
      setState(() {
        _recording = true;
        _cancelArmed = false;
        _dragX = 0;
        _recordStart = DateTime.now();
        _tickMs = kLongPressTimeout.inMilliseconds;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        _tickMs += 250;
        if (_elapsedMs >= CoachingLimits.chatAudioMaxSeconds * 1000) {
          // The limit ends the recording, never the sending: the note goes
          // when she lets go, like any other.
          _ticker?.cancel();
          _stopped ??= _rec.stop().catchError((Object _) => null);
        }
        setState(() {});
      });
    } finally {
      _startingRecord = false;
    }
  }

  int get _elapsedMs => _stopped != null
      ? CoachingLimits.chatAudioMaxSeconds * 1000
      : _recordStart == null
      ? 0
      : max(_tickMs, DateTime.now().difference(_recordStart!).inMilliseconds);

  void _recordDrag(double dx) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final toward = rtl ? dx : -dx;
    setState(() {
      _dragX = dx;
      _cancelArmed = toward > 80;
    });
  }

  Future<void> _recordEnd({required bool send}) async {
    _pressed = false;
    if (!_recording) return;
    final ms = _elapsedMs;
    final cancel = !send || _cancelArmed;
    final stopped = _stopped;
    _stopped = null;
    _ticker?.cancel();
    setState(() => _recording = false);
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (cancel) {
      if (stopped == null) {
        await _rec.cancel();
      } else {
        await stopped;
      }
      return;
    }
    if (ms < 1000) {
      await _rec.cancel();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.holdTheMicAndSpeak)));
      return;
    }
    final bytes = await (stopped ?? _rec.stop());
    if (bytes == null || bytes.isEmpty || !mounted) return;
    final ok = await _controller.sendMedia(
      type: MessageType.audio,
      bytes: bytes,
      contentType: 'audio/mp4',
      durationMs: ms.clamp(1000, CoachingLimits.chatAudioMaxSeconds * 1000),
    );
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.weCouldNotSendThatTryAgain)),
      );
    } else {
      _toBottom();
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
            l10n.thisMessageWasHiddenAndWasNot,
            icon: Icons.visibility_off_outlined,
          );
        }
        if (message.type == MessageType.system) {
          if (message.systemKind == SystemMessageKind.checkIn &&
              message.weekKey != null &&
              widget.otherIsCoach) {
            // otherIsCoach is true on the CLIENT's side (the other person is
            // the coach): she is the one who answers.
            final week = message.weekKey!;
            return CheckInCard(
              weekKey: week,
              onAnswer: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CheckInView(relId: widget.relId, weekKey: week),
                ),
              ),
            );
          }
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
        if (message.type.isMedia) {
          return MediaBubble(
            message: message,
            mine: mine,
            tail: tail,
            tick: tick,
            who: who,
            urlOf: widget.repository.chatMediaUrl,
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
                if (_recording) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.fiber_manual_record,
                    color: _cancelArmed
                        ? AppColors.onSurfaceVariant
                        : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    durationLabel(_elapsedMs),
                    style: AppText.body.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(_dragX.clamp(-120.0, 120.0), 0),
                      child: Text(
                        _cancelArmed
                            ? l10n.releaseToCancel
                            : l10n.slideAwayToCancel,
                        style: AppText.nav.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: l10n.shareSomething,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    onPressed: () {
                      final choices = widget.share.withMedia(
                        onTakePhoto: () => unawaited(
                          _pickMedia(video: false, source: ImageSource.camera),
                        ),
                        onChoosePhoto: () => unawaited(
                          _pickMedia(video: false, source: ImageSource.gallery),
                        ),
                        onRecordVideo: () => unawaited(
                          _pickMedia(video: true, source: ImageSource.camera),
                        ),
                        onChooseVideo: () => unawaited(
                          _pickMedia(video: true, source: ImageSource.gallery),
                        ),
                      );
                      showShareSheet(
                        context,
                        _iAmCoach
                            ? choices.withReplies(
                                replies: _replies,
                                onUseReply: _useReply,
                                onEditReply: (r) => unawaited(_editReply(r)),
                                onAddReply: () => unawaited(_editReply(null)),
                              )
                            : choices,
                      );
                    },
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
                          borderSide: const BorderSide(
                            color: AppColors.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          borderSide: const BorderSide(
                            color: AppColors.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (!_recording && _text.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: l10n.send,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.send),
                    color: AppColors.primary,
                    onPressed: () => unawaited(_send()),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ScaffoldMessenger.maybeOf(context)
                        ?.showSnackBar(
                          SnackBar(content: Text(l10n.holdTheMicAndSpeak)),
                        ),
                    onLongPressStart: (_) => unawaited(_recordStartHold()),
                    onLongPressMoveUpdate: (d) =>
                        _recordDrag(d.offsetFromOrigin.dx),
                    onLongPressEnd: (_) => unawaited(_recordEnd(send: true)),
                    onLongPressCancel: () => unawaited(_recordEnd(send: false)),
                    child: Semantics(
                      button: true,
                      label: l10n.voiceNote,
                      hint: l10n.holdTheMicAndSpeak,
                      excludeSemantics: true,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.mic, color: AppColors.primary),
                      ),
                    ),
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
