/// The coach side's camera: one photograph, taken live.
///
/// `K02` uses the back lens for a certificate, as the ID card is taken; `K01`
/// uses the front lens for her own photo. Either way it returns JPEG bytes and
/// keeps nothing on the phone. There is no picker for an existing picture, so
/// this asks for no photo library permission.
library;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';

/// Opens the camera over the current screen and answers with the photo, or
/// null when she closed it without one.
Future<Uint8List?> photographCertificate(BuildContext context) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => const CertificateCameraView(),
      ),
    );

/// `K01`: her own photo, with the front lens.
Future<Uint8List?> photographHerself(BuildContext context) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => const CertificateCameraView(selfie: true),
      ),
    );

/// Why the lens did not open.
enum CertificateCameraProblem { permission, unavailable }

class CertificateCameraView extends StatefulWidget {
  const CertificateCameraView({
    super.key,
    this.lenses = availableCameras,
    this.selfie = false,
  });

  /// Her own photo with the front lens, rather than a certificate with the
  /// back one.
  final bool selfie;

  /// The phone's cameras. Injectable, so a test host with no camera plugin
  /// exercises the honest "could not start" state rather than a crash.
  final Future<List<CameraDescription>> Function() lenses;

  @override
  State<CertificateCameraView> createState() => _CertificateCameraViewState();
}

class _CertificateCameraViewState extends State<CertificateCameraView> {
  CameraController? _controller;
  CertificateCameraProblem? _problem;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final lenses = await widget.lenses();
      final wanted = widget.selfie
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final back = lenses.where((c) => c.lensDirection == wanted).firstOrNull;
      if (back == null) {
        _fail(CertificateCameraProblem.unavailable);
        return;
      }
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (error) {
      final code = error.code.toLowerCase();
      _fail(
        code.contains('denied') || code.contains('restricted')
            ? CertificateCameraProblem.permission
            : CertificateCameraProblem.unavailable,
      );
    } on MissingPluginException {
      _fail(CertificateCameraProblem.unavailable);
    } catch (_) {
      _fail(CertificateCameraProblem.unavailable);
    }
  }

  void _fail(CertificateCameraProblem problem) {
    if (mounted) setState(() => _problem = problem);
  }

  Future<void> _take() async {
    final controller = _controller;
    if (controller == null || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _taking = false;
          _problem = CertificateCameraProblem.unavailable;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final controller = _controller;
    final problem = _problem;

    return AppScaffold(
      appBar: AppTopBar(
        title: widget.selfie
            ? l10n.takeYourPhoto
            : l10n.photographYourCertificate,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: [
        if (problem == null)
          AppButton(
            l10n.takeThePhoto,
            icon: Icons.photo_camera,
            onPressed: controller == null || _taking ? null : _take,
          )
        else
          AppButton(
            l10n.close,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
      ],
      children: [
        Text(
          problem == null
              ? (widget.selfie
                    ? l10n.faceTheLightWithAPlainWall
                    : l10n.layItFlatInGoodLightWith)
              : switch (problem) {
                  CertificateCameraProblem.permission =>
                    l10n.cameraAccessIsOffYouCanTurn,
                  CertificateCameraProblem.unavailable =>
                    l10n.theCameraCouldNotStartCloseThis,
                },
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (problem == null)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: controller == null
                  ? const ColoredBox(
                      color: AppColors.surfaceContainer,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : CameraPreview(controller),
            ),
          ),
      ],
    );
  }
}
