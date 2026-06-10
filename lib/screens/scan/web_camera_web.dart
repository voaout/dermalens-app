// Web-only webcam capture using getUserMedia.
//
// Used on Flutter Web when the user taps "사진 촬영하기" — opens the laptop
// webcam (or the back camera on mobile browsers) in a live preview and
// returns the captured frame as JPEG bytes.
//
// This file is only compiled into web builds via conditional import in
// image_source_sheet.dart, so dart:html is safe here.

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:ui_web' as ui_web;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Opens the webcam capture screen. Returns JPEG bytes, or null if cancelled.
/// Takes a [NavigatorState] (not a BuildContext) so the caller can capture it
/// before any async gap that might unmount the original context.
Future<Uint8List?> captureFromWebcam(NavigatorState navigator) {
  return navigator.push<Uint8List?>(
    MaterialPageRoute(builder: (_) => const _WebCameraScreen()),
  );
}

class _WebCameraScreen extends StatefulWidget {
  const _WebCameraScreen();

  @override
  State<_WebCameraScreen> createState() => _WebCameraScreenState();
}

class _WebCameraScreenState extends State<_WebCameraScreen> {
  late final String _viewType;
  late final html.VideoElement _video;
  html.MediaStream? _stream;
  String? _error;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _viewType = 'webcam-${DateTime.now().microsecondsSinceEpoch}';
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.background = '#000';

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _video);

    _start();
  }

  Future<void> _start() async {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) {
      setState(() {
        _error = '이 브라우저는 카메라 API를 지원하지 않아요.';
        _starting = false;
      });
      return;
    }

    // Prefer the rear camera (mobile); fall back to any available camera
    // (laptop webcams ignore facingMode).
    try {
      _stream = await devices.getUserMedia({
        'video': {'facingMode': 'environment'},
        'audio': false,
      });
    } catch (_) {
      try {
        _stream = await devices.getUserMedia({'video': true, 'audio': false});
      } catch (e) {
        setState(() {
          _error = _readableError(e);
          _starting = false;
        });
        return;
      }
    }

    _video.srcObject = _stream;
    if (!mounted) return;
    setState(() => _starting = false);
  }

  String _readableError(Object e) {
    final s = '$e';
    if (s.contains('NotAllowedError') || s.contains('PermissionDenied')) {
      return '카메라 권한을 허용해 주세요.';
    }
    if (s.contains('NotFoundError') || s.contains('DevicesNotFound')) {
      return '사용 가능한 카메라를 찾지 못했어요.';
    }
    if (s.contains('NotReadableError')) {
      return '다른 앱이 카메라를 사용 중이에요.';
    }
    if (s.contains('SecurityError')) {
      return 'HTTPS 환경에서만 카메라를 쓸 수 있어요. (localhost 제외)';
    }
    return '카메라를 시작하지 못했어요.';
  }

  @override
  void dispose() {
    _stream?.getTracks().forEach((t) => t.stop());
    _video.srcObject = null;
    super.dispose();
  }

  void _capture() {
    final vw = _video.videoWidth;
    final vh = _video.videoHeight;
    if (vw == 0 || vh == 0) return;

    // Downscale to ≤1600px on the long edge — keeps OCR readable while
    // shrinking the upload to well under a megabyte.
    const maxEdge = 1600;
    final scale = (vw > vh ? vw : vh) > maxEdge
        ? maxEdge / (vw > vh ? vw : vh)
        : 1.0;
    final w = (vw * scale).round();
    final h = (vh * scale).round();

    final canvas = html.CanvasElement(width: w, height: h);
    canvas.context2D.drawImageScaled(_video, 0, 0, w, h);

    // toDataUrl is synchronous and avoids the Blob → ArrayBuffer dance.
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64Str = dataUrl.split(',').last;
    final bytes = base64Decode(base64Str);

    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 라이브 프리뷰
            Positioned.fill(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : _starting
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : HtmlElementView(viewType: _viewType),
            ),

            // 닫기
            Positioned(
              top: 12,
              left: 12,
              child: _RoundIconButton(
                icon: Icons.close,
                onTap: () => Navigator.pop(context),
              ),
            ),

            // 촬영 셔터
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Center(
                child: GestureDetector(
                  onTap: _error == null && !_starting ? _capture : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _error == null && !_starting
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 안내
            const Positioned(
              left: 0,
              right: 0,
              bottom: 130,
              child: Center(
                child: Text(
                  '성분표가 프레임에 들어오게 촬영해 주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final _ = AppColors.primary; // keep the import live across all platforms
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
