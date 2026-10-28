/// The coach's home: who members see, whether her portfolio is live, and the
/// way into her dashboard, portfolio, packages and application.
library;

import 'package:flutter/material.dart';

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/private_coaching_state.dart';
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_chevron.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_sage_note.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../payments/presentation/payment_address_view.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coaching_failure.dart';
import 'coach_application_view.dart';
import 'coach_data.dart';
import 'coach_photo.dart';
import 'coach_text.dart';
import 'coach_widgets.dart';
import 'packages_view.dart';
import 'portfolio_edit_view.dart';
import 'portfolio_media_view.dart';

class CoachSpaceView extends StatefulWidget {
  const CoachSpaceView({
    super.key,
    required this.repository,
    this.coaching,
    this.onPreviewPortfolio,
    this.onOpenDashboard,
    this.onOpenChats,
    this.onInviteClient,
    this.onShareProfile,
    this.onBack,
    this.instapayOn = false,
    this.onOpenPayments,
    this.onOpenStatements,
    this.photoChooser = chooseCoachPhoto,
    this.imageChooser = chooseCoachImage,
  });

  final CoachingRepository repository;

  /// Where the dashboard counts come from; the app's own by default.
  final PrivateCoachingState? coaching;

  /// Opens the member view of her portfolio. Gets her uid.
  final void Function(String coachUid)? onPreviewPortfolio;
  final VoidCallback? onOpenDashboard;
  final VoidCallback? onOpenChats;

  /// "Invite a client": her code, shared on WhatsApp.
  final VoidCallback? onInviteClient;

  /// "Share my profile link": her public portfolio link.
  final void Function(String coachUid)? onShareProfile;
  final VoidCallback? onBack;

  /// InstaPay payments are on (the flag and the server switch): shows the
  /// rows that belong to them.
  final bool instapayOn;

  /// Opens her payments inbox. Given while the payments flag is on, even if
  /// the server has paused new payments: she still answers the open ones.
  final VoidCallback? onOpenPayments;

  /// Opens her monthly fee statements. Given with the payments flag, like
  /// [onOpenPayments].
  final VoidCallback? onOpenStatements;
  final CoachPhotoChooser photoChooser;
  final CoachImageChooser imageChooser;

  @override
  State<CoachSpaceView> createState() => _CoachSpaceViewState();
}

class _CoachSpaceViewState extends State<CoachSpaceView> {
  late final CoachSpaceData _data = CoachSpaceData(widget.repository);
  bool? _accepting;
  String _error = '';

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _setAccepting(bool value) async {
    final l10n = AppL10n.of(context);
    setState(() {
      _accepting = value;
      _error = '';
    });
    try {
      await widget.repository.updateCoachProfile(acceptingClients: value);
    } on CoachingFailure catch (failure) {
      if (mounted) setState(() => _error = coachFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.myCoachSpace,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      children: [
        CoachDataGate(
          data: _data,
          builder: (context) {
            if (_data.suspended) return _paused(l10n);
            final profile = _data.profile;
            if (profile == null) return _notReady(l10n);
            final hasPackage = _data.packages.any((p) => p.active);
            final live = profile.published && hasPackage;
            final accepting = _accepting ?? profile.acceptingClients;
            final coaching = widget.coaching ?? PrivateCoachingState.instance;
            return <Widget>[
              AppCard(
                children: [
                  Row(
                    children: [
                      CoachPhoto(
                        name: profile.displayName,
                        photoUrl: profile.photoUrl,
                        size: 72,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.displayName, style: AppText.titleL),
                            const SizedBox(height: 6),
                            AppPill(
                              live
                                  ? l10n.yourPortfolioIsLive
                                  : hasPackage
                                  ? l10n.yourPortfolioIsNotLiveYet
                                  : l10n.notVisibleYetAddAPackage,
                              background: live
                                  ? AppColors.tertiaryContainer
                                  : AppColors.amberContainer,
                              foreground: live
                                  ? AppColors.onTertiaryContainer
                                  : AppColors.amber,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!live)
                    Text(
                      l10n.turnOnOnePackageAndMembersCan,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  CoachSwitchRow(
                    title: l10n.acceptingNewClients,
                    value: accepting && hasPackage,
                    subtitle: hasPackage ? '' : l10n.notVisibleYetAddAPackage,
                    onChanged: _accepting == null && hasPackage
                        ? _setAccepting
                        : null,
                  ),
                  if (_error.isNotEmpty) CoachFieldError(_error),
                ],
              ),
              if (widget.onOpenDashboard != null)
                ListenableBuilder(
                  listenable: AppChanges.instance,
                  builder: (context, _) => _dashboard(l10n, coaching),
                ),
              if (widget.onInviteClient != null)
                _nav(
                  title: l10n.inviteAClient,
                  subtitle: l10n.alreadyCoachingSomeoneSendHerYourCode,
                  icon: Icons.person_add_alt,
                  onTap: widget.onInviteClient!,
                ),
              if (widget.onShareProfile != null && live)
                _nav(
                  title: l10n.shareMyProfileLink,
                  subtitle: l10n.membersWhoOpenItLandOnYour,
                  icon: Icons.link,
                  onTap: () => widget.onShareProfile!(profile.uid),
                ),
              _nav(
                title: l10n.myPortfolio,
                subtitle: l10n.photoHeadlineAndHowYouCoach,
                icon: Icons.person_outline,
                onTap: () => _push(
                  PortfolioEditView(
                    data: _data,
                    photoChooser: widget.photoChooser,
                  ),
                ),
              ),
              _nav(
                title: l10n.myPackages,
                subtitle: l10n.countOf6Packages(
                  countLabel(_data.packages.length),
                ),
                icon: Icons.inventory_2_outlined,
                onTap: () => _push(PackagesView(data: _data)),
              ),
              if (widget.onOpenPayments != null)
                _nav(
                  title: l10n.payments,
                  subtitle: l10n.paymentsFromYourClients,
                  icon: Icons.payments_outlined,
                  onTap: widget.onOpenPayments!,
                ),
              if (widget.onOpenStatements != null)
                _nav(
                  title: l10n.feeStatements,
                  subtitle: l10n.whatYouOweOwnHubEachMonth,
                  icon: Icons.receipt_long_outlined,
                  onTap: widget.onOpenStatements!,
                ),
              if (widget.instapayOn)
                _nav(
                  title: l10n.myInstapayAddress,
                  subtitle: l10n.whereClientsPayYou,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => _push(const PaymentAddressView()),
                ),
              _nav(
                title: l10n.photosAndResults,
                subtitle: l10n.whatMembersSeeAfterOwnHubChecks,
                icon: Icons.photo_library_outlined,
                onTap: () => _push(
                  PortfolioMediaView(
                    data: _data,
                    imageChooser: widget.imageChooser,
                  ),
                ),
              ),
              if (widget.onPreviewPortfolio != null)
                _nav(
                  title: l10n.previewMyPortfolio,
                  subtitle: l10n.seeItTheWayMembersDo,
                  icon: Icons.visibility_outlined,
                  onTap: () => widget.onPreviewPortfolio!(profile.uid),
                ),
              _nav(
                title: l10n.myApplication,
                subtitle: l10n.whatWasApproved,
                icon: Icons.verified_outlined,
                onTap: () => _push(CoachApplicationView(data: _data)),
              ),
              AppSageNote(l10n.membersCanAskToJoinYourPackages),
            ];
          },
        ),
      ],
    );
  }

  Widget _nav({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) => AppListItem(
    variant: AppCardVariant.filled,
    title: title,
    subtitle: subtitle,
    leading: Icon(icon),
    trailing: const AppChevron(),
    onTap: onTap,
  );

  Widget _dashboard(AppL10n l10n, PrivateCoachingState coaching) {
    return AppCard(
      variant: AppCardVariant.tonal,
      onTap: widget.onOpenDashboard,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.dashboard, style: AppText.titleL),
        ),
        Text(l10n.requestsChatsAndClientsInOnePlace, style: AppText.bodyM),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            AppPill(
              l10n.countPluralOne1NewRequestOther(coaching.requests.length),
            ),
            AppPill(l10n.countPluralOne1UnreadChatOther(coaching.unreadChats)),
            AppPill(
              l10n.countPluralOne1ClientOtherCount(
                coaching.activeClients.length,
              ),
            ),
          ],
        ),
        if (widget.onOpenChats != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onOpenChats,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.chats),
            ),
          ),
      ],
    );
  }

  List<Widget> _paused(AppL10n l10n) => <Widget>[
    AppCard(
      variant: AppCardVariant.filled,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.yourCoachSpaceIsPaused, style: AppText.titleL),
        ),
        Text(l10n.pleaseContactOwnHubNothingCanBe, style: AppText.body),
      ],
    ),
  ];

  List<Widget> _notReady(AppL10n l10n) => <Widget>[
    AppCard(
      variant: AppCardVariant.filled,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.yourCoachSpaceIsNotReadyYet, style: AppText.titleL),
        ),
        Text(l10n.itOpensHereOnceYourApplicationIs, style: AppText.body),
      ],
    ),
  ];
}
