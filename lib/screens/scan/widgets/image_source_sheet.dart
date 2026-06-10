import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../ocr_confirm_screen.dart';
import '../web_camera_io.dart'
    if (dart.library.html) '../web_camera_web.dart';

/// Opens the image picker for [source] (camera or gallery) and hands the
/// captured bytes to [OcrConfirmScreen]. Errors are surfaced via a SnackBar.
///
/// Captures the [NavigatorState] and [ScaffoldMessengerState] upfront — async
/// gaps (camera UI, file picker, await readBytes) can deactivate the
/// originating [context], so we don't rely on it after the first frame.
Future<void> pickImageForOcr(
  BuildContext context,
  ImageSource source,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  void snack(String msg) {
    if (!navigator.mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void goToConfirm(List<Uint8List> images) {
    if (!navigator.mounted || images.isEmpty) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => OcrConfirmScreen(imagesBytes: images),
      ),
    );
  }

  try {
    // Web + camera → use our getUserMedia-based webcam capture screen.
    // image_picker on desktop browsers only opens a file dialog (capture
    // attribute is ignored), so it can't actually use the laptop webcam.
    if (kIsWeb && source == ImageSource.camera) {
      final bytes = await captureFromWebcam(navigator);
      if (bytes == null) return; // cancelled or failed
      goToConfirm([bytes]);
      return;
    }

    // Native desktop (Windows/macOS/Linux) doesn't support image_picker
    // camera — fall back to the gallery file picker.
    if (source == ImageSource.camera && _isDesktopNative) {
      snack('이 환경에서는 카메라를 쓸 수 없어 갤러리에서 선택해 주세요.');
      source = ImageSource.gallery;
    }

    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        // 보관함은 한 번에 여러 장 멀티 선택. confirm 화면에서 더 추가/삭제 가능.
        final files = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (files.isEmpty) return;
        final loaded = await Future.wait(files.map((f) => f.readAsBytes()));
        goToConfirm(loaded);
      } else {
        final file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        goToConfirm([bytes]);
      }
    } on Exception catch (e) {
      snack(_readableError(e));
      return;
    }
  } catch (e) {
    // Last-resort net: surface anything we missed so the UI never silently
    // freezes on the scan screen again.
    snack('이미지 처리 중 오류가 발생했어요: $e');
  }
}

bool get _isDesktopNative {
  if (kIsWeb) return false; // web handled separately via captureFromWebcam
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

String _readableError(Object e) {
  final msg = '$e'.toLowerCase();
  if (msg.contains('camera_access_denied') || msg.contains('permission')) {
    return '카메라 권한을 허용해 주세요.';
  }
  if (msg.contains('photo_access_denied')) {
    return '사진 접근 권한을 허용해 주세요.';
  }
  if (msg.contains('no_available_camera')) {
    return '사용 가능한 카메라가 없어요.';
  }
  return '이미지를 가져오지 못했어요.';
}

/// Bottom sheet that just lets the user **choose** a source.
///
/// Returns the chosen [ImageSource] (or null if dismissed) via [Navigator.pop]
/// so the caller — running in its own stable context — can run the picker
/// after the sheet closes. Doing the pick from inside the sheet would use a
/// deactivated context once the sheet pops, and the subsequent push would
/// silently no-op.
class ImageSourceSheet extends StatelessWidget {
  const ImageSourceSheet({super.key});

  void _choose(BuildContext context, ImageSource source) {
    Navigator.pop<ImageSource>(context, source);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4F4F4F),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuItem(
            title: '사진 보관함',
            icon: Icons.photo_library_outlined,
            onTap: () => _choose(context, ImageSource.gallery),
          ),
          _MenuItem(
            title: '사진 찍기',
            icon: Icons.camera_alt_outlined,
            onTap: () => _choose(context, ImageSource.camera),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
