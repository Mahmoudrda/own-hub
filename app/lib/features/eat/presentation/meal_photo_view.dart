/// E12: Snap your meal.
///
/// The rear camera, full width, and one big shutter. After the shot she sees
/// the photo and chooses: "Analyse my meal" or "Retake". **A scan happens only
/// when she taps "Analyse my meal"**, never on its own: each one costs money
/// and one of her five a day, so the button says so beside it.
///
/// ## The photo
///
/// Bytes in this screen's memory and nowhere else (see `meal_camera.dart` for
/// the one moment the plugin writes a file). Drawn with [HeldPhoto], which
/// decodes outside the global image cache. Zeroed and dropped after the scan
/// answers, whatever it answers, on "Retake", and when she leaves. Nothing is
/// put in the gallery, and the camera is released whenever the app goes to
/// the background.
///
/// ## When it does not work
///
/// Every refusal has its own sentence and a next step, and every one offers
/// typing the meal instead, because the camera is a shortcut and never the
/// only way to log a meal.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app_state/meal_scan_state.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../signup/data/held_photo.dart';
import '../data/meal_camera.dart';
import '../data/meal_frame_light.dart';
import '../domain/meal_scan.dart';
import 'meal_photo_consent.dart';
import 'meal_result_card.dart';

/// What E12 says about a refused scan, and whether "Retake" is the way on.
@immutable
class ScanAdvice {
  const ScanAdvice(this.message, {required this.retake});

  final String message;

  /// True when a new photo could work. Typing is offered either way.
  final bool retake;
}

/// The sentence and the next step for [failure].
ScanAdvice scanAdviceFor(AppL10n l10n, MealScanFailure failure) =>
    switch (failure) {
      MealScanFailure.dailyLimit => ScanAdvice(
        l10n.youveUsedYour5ScansForToday,
        retake: false,
      ),
      MealScanFailure.noFoodSeen || MealScanFailure.unclear => ScanAdvice(
        l10n.weCouldntMakeOutTheFoodTry,
        retake: true,
      ),
      MealScanFailure.photoUnreadable => ScanAdvice(
        l10n.weCouldntReadThatPhotoTakeIt,
        retake: true,
      ),
      MealScanFailure.photoTooDark => ScanAdvice(
        l10n.thatPhotoIsTooDarkTryAgain,
        retake: true,
      ),
      MealScanFailure.photoBlank => ScanAdvice(
        l10n.thatPhotoLooksBlankCheckTheLens,
        retake: true,
      ),
      MealScanFailure.notVerified => ScanAdvice(
        l10n.mealPhotosOpenOnceYourAccountIs,
        retake: false,
      ),
      MealScanFailure.appOutdated => ScanAdvice(
        l10n.updateOwnHubFromTheStoreTo,
        retake: false,
      ),
      MealScanFailure.signedOut => ScanAdvice(
        l10n.signInAgainToSnapMealsYou,
        retake: false,
      ),
      // `consent_missing` sends her back to the question; if it ever lands
      // here, the honest sentence is that scanning is not available.
      MealScanFailure.unavailable ||
      MealScanFailure.paused ||
      MealScanFailure.consentMissing => ScanAdvice(
        l10n.scanningIsntAvailableRightNowTypeYour,
        retake: failure == MealScanFailure.unavailable,
      ),
    };

enum _Step { checking, consent, camera, review, scanning, failed }

class MealPhotoView extends StatefulWidget {
  const MealPhotoView({
    super.key,
    required this.state,
    this.uid,
    this.onScanned,
    this.isTooDark = mealFrameIsTooDark,
    this.isBlank = mealFrameIsBlank,
    this.onTypeInstead,
    this.onOpenSettings,
    this.onClose,
  });

  /// Her consent, the camera and the callable.
  final MealScanState state;

  /// The account her consent is remembered for.
  final String? uid;

  /// The scan answered with food; [MealScanState.result] holds it.
  final VoidCallback? onScanned;

  /// Whether a photo is too dark to send. Replaced in tests.
  final Future<bool> Function(Uint8List photo) isTooDark;

  /// Whether a photo is a flat frame with nothing in it. Replaced in tests.
  final Future<bool> Function(Uint8List photo) isBlank;

  /// E02, typing the meal.
  final VoidCallback? onTypeInstead;

  /// This app's page in the phone's settings, for a camera she turned off.
  final VoidCallback? onOpenSettings;

  final VoidCallback? onClose;

  @override
  State<MealPhotoView> createState() => _MealPhotoViewState();
}

class _MealPhotoViewState extends State<MealPhotoView>
    with WidgetsBindingObserver {
  _Step _step = _Step.checking;
  MealCameraSession? _session;
  bool _opening = false;
  bool _taking = false;
  Uint8List? _photo;
  MealScanFailure? _failure;

  /// Bumped on every open and on dispose, so a camera that finishes opening
  /// after she has left is released instead of shown.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final agreed = await widget.state.hasConsented(widget.uid);
    if (!mounted) return;
    if (!agreed) {
      setState(() => _step = _Step.consent);
      return;
    }
    await _openCamera();
  }

  Future<void> _openCamera() async {
    if (_opening) return;
    _opening = true;
    final generation = ++_generation;
    setState(() => _step = _Step.camera);
    try {
      final session = await widget.state.camera.open();
      if (!mounted || generation != _generation) {
        await session.close();
        return;
      }
      setState(() => _session = session);
    } finally {
      _opening = false;
    }
  }

  Future<void> _closeCamera() async {
    _generation++;
    final session = _session;
    _session = null;
    await session?.close();
  }

  /// Zeroes the held photo and lets it go.
  void _wipePhoto() {
    final photo = _photo;
    if (photo != null) photo.fillRange(0, photo.length, 0);
    _photo = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (_session != null) {
        unawaited(_closeCamera());
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_step == _Step.camera && _session == null && mounted) {
        unawaited(_openCamera());
      }
    }
  }

  Future<void> _shoot() async {
    final session = _session;
    if (session == null || session.problem != null || _taking) return;
    setState(() => _taking = true);
    final bytes = await session.takePhoto();
    if (!mounted) {
      if (bytes != null) bytes.fillRange(0, bytes.length, 0);
      return;
    }
    setState(() => _taking = false);
    if (bytes == null) {
      setState(() {
        _failure = MealScanFailure.photoUnreadable;
        _step = _Step.failed;
      });
      await _closeCamera();
      return;
    }
    final dark = await widget.isTooDark(bytes);
    final blank = !dark && mounted && await widget.isBlank(bytes);
    if (!mounted) {
      bytes.fillRange(0, bytes.length, 0);
      return;
    }
    if (dark || blank) {
      bytes.fillRange(0, bytes.length, 0);
      setState(() {
        _failure = dark
            ? MealScanFailure.photoTooDark
            : MealScanFailure.photoBlank;
        _step = _Step.failed;
      });
      await _closeCamera();
      return;
    }
    _photo = bytes;
    // The lens is not needed while she looks at the photo.
    await _closeCamera();
    if (mounted) setState(() => _step = _Step.review);
  }

  Future<void> _retake() async {
    _wipePhoto();
    _failure = null;
    await _openCamera();
  }

  Future<void> _analyse() async {
    final photo = _photo;
    if (photo == null || _step == _Step.scanning) return;
    final locale = Localizations.localeOf(context).languageCode;
    setState(() => _step = _Step.scanning);
    try {
      final result = await widget.state.client.analyse(photo, locale: locale);
      _wipePhoto();
      widget.state.result = result;
      if (!mounted) return;
      widget.onScanned?.call();
      // Back here only if she leaves E13 for the camera again.
      setState(() => _step = _Step.review);
    } on MealScanException catch (refused) {
      _wipePhoto();
      if (refused.failure == MealScanFailure.consentMissing) {
        // The server does not hold her agreement: forget the phone's memory
        // of it and ask again.
        await widget.state.forgetConsent();
        if (mounted) setState(() => _step = _Step.consent);
        return;
      }
      if (mounted) {
        setState(() {
          _failure = refused.failure;
          _step = _Step.failed;
        });
      }
    } catch (_) {
      _wipePhoto();
      if (mounted) {
        setState(() {
          _failure = MealScanFailure.unavailable;
          _step = _Step.failed;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    unawaited(_session?.close());
    _session = null;
    _wipePhoto();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.snapYourMeal,
        onBack: widget.onClose,
        leadingIcon: Icons.close,
      ),
      footer: _footer(l10n),
      children: _body(l10n),
    );
  }

  List<Widget> _body(AppL10n l10n) {
    switch (_step) {
      case _Step.checking:
        return [_frame(const SizedBox.expand())];
      case _Step.consent:
        return [
          MealPhotoConsentBody(
            state: widget.state,
            uid: widget.uid,
            onAgreed: () => unawaited(_openCamera()),
            onNotNow: () => widget.onClose?.call(),
          ),
        ];
      case _Step.camera:
        final session = _session;
        final problem = session?.problem;
        if (problem != null) return _cameraProblem(l10n, problem);
        return [
          // The one instruction, above the window so it is read before the
          // shutter rather than under it.
          Text(
            l10n.takeItFromAboveWithTheWhole,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          _frame(
            session == null
                ? const Center(
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 44,
                      color: AppColors.onSurfaceVariant,
                    ),
                  )
                : session.buildPreview(),
          ),
        ];
      case _Step.review:
        return [
          Text(l10n.useThisPhoto_6wkqn, style: AppText.titleL),
          _frame(_heldPhoto(l10n)),
          Text(
            l10n.thisUses1OfYour5Photos,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ];
      case _Step.scanning:
        return [
          _frame(
            Stack(
              fit: StackFit.expand,
              children: [
                _heldPhoto(l10n),
                ColoredBox(color: AppColors.surface.withValues(alpha: 0.55)),
              ],
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.readingYourPlate,
              key: const ValueKey('meal-scan-reading'),
              style: AppText.titleM,
            ),
          ),
          // The wait is the real analysis call; the card ends when it does.
          const MealResultCard(adding: true),
          Text(
            l10n.thePhotoIsWipedAsSoonAs,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ];
      case _Step.failed:
        final advice = scanAdviceFor(
          l10n,
          _failure ?? MealScanFailure.unavailable,
        );
        return [
          _frame(
            const Center(
              child: Icon(
                Icons.no_food_outlined,
                size: 48,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              advice.message,
              key: const ValueKey('meal-scan-advice'),
              style: AppText.body,
            ),
          ),
        ];
    }
  }

  List<Widget> _cameraProblem(AppL10n l10n, MealCameraProblem problem) => [
    _frame(
      const Center(
        child: Icon(
          Icons.no_photography_outlined,
          size: 48,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    ),
    if (problem == MealCameraProblem.permissionDenied) ...[
      Text(l10n.cameraAccessIsOff, style: AppText.titleM),
      Text(l10n.ownHubNeedsTheCameraToPhotograph, style: AppText.body),
    ] else
      Text(l10n.theCameraCouldntStartYouCanType, style: AppText.body),
  ];

  List<Widget> _footer(AppL10n l10n) {
    final typeIt = AppButton(
      l10n.typeItInstead,
      key: const ValueKey('meal-scan-type-instead'),
      variant: AppButtonVariant.text,
      height: 48,
      fontSize: 16,
      onPressed: widget.onTypeInstead,
    );
    switch (_step) {
      case _Step.checking:
      case _Step.consent:
        return const <Widget>[];
      case _Step.camera:
        final problem = _session?.problem;
        if (problem == MealCameraProblem.permissionDenied) {
          return [
            AppButton(l10n.openSettings, onPressed: widget.onOpenSettings),
            typeIt,
          ];
        }
        if (problem != null) {
          return [
            AppButton(l10n.tryAgain, onPressed: () => unawaited(_retake())),
            typeIt,
          ];
        }
        return [
          Center(
            child: _Shutter(
              label: l10n.takePhoto,
              onPressed: _session == null || _taking
                  ? null
                  : () => unawaited(_shoot()),
            ),
          ),
        ];
      case _Step.review:
        return [
          AppButton(
            l10n.analyseMyMeal,
            key: const ValueKey('meal-scan-analyse'),
            icon: Icons.auto_awesome_outlined,
            onPressed: _photo == null ? null : () => unawaited(_analyse()),
          ),
          AppButton(
            l10n.retake,
            key: const ValueKey('meal-scan-retake'),
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 16,
            onPressed: () => unawaited(_retake()),
          ),
        ];
      case _Step.scanning:
        return const <Widget>[];
      case _Step.failed:
        final advice = scanAdviceFor(
          l10n,
          _failure ?? MealScanFailure.unavailable,
        );
        if (advice.retake) {
          return [
            AppButton(
              l10n.retake,
              key: const ValueKey('meal-scan-retake'),
              onPressed: () => unawaited(_retake()),
            ),
            typeIt,
          ];
        }
        return [
          AppButton(
            l10n.typeItInstead,
            key: const ValueKey('meal-scan-type-instead'),
            onPressed: widget.onTypeInstead,
          ),
        ];
    }
  }

  Widget _heldPhoto(AppL10n l10n) {
    final photo = _photo;
    return Semantics(
      image: true,
      label: l10n.yourMealPhoto,
      child: photo == null
          ? const SizedBox.expand()
          : HeldPhoto(jpeg: photo, decodeWidth: 720),
    );
  }

  /// The camera's window: the full width of the page, three by four.
  Widget _frame(Widget child) => AspectRatio(
    aspectRatio: 3 / 4,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ColoredBox(color: AppColors.surfaceContainer, child: child),
    ),
  );
}

/// One big round shutter.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const ValueKey('meal-scan-shutter'),
          onTap: onPressed,
          radius: 44,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AppColors.primary : AppColors.surfaceHigh,
              border: Border.all(color: AppColors.surfaceLowest, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.photo_camera,
              size: 32,
              color: enabled ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
