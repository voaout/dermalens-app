import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../data/analysis_jobs_store.dart';
import 'ocr_loading_screen.dart';
import 'web_camera_io.dart'
    if (dart.library.html) 'web_camera_web.dart';

/// 분석 시작 전 확인 화면.
///
/// 1장 이상의 사진을 받아 큰 메인 프리뷰 + 가로 썸네일 스트립으로 표시.
/// 사용자는 여기서 사진을 더 추가하거나 개별 사진을 빼고 [분석 시작]을 누름.
class OcrConfirmScreen extends StatefulWidget {
  final List<Uint8List> imagesBytes;

  const OcrConfirmScreen({
    super.key,
    required this.imagesBytes,
  });

  @override
  State<OcrConfirmScreen> createState() => _OcrConfirmScreenState();
}

class _OcrConfirmScreenState extends State<OcrConfirmScreen> {
  late final List<Uint8List> _images;
  int _selected = 0;
  static const int _maxImages = 10;

  @override
  void initState() {
    super.initState();
    _images = List.of(widget.imagesBytes);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _removeAt(int index) {
    setState(() {
      _images.removeAt(index);
      if (_images.isEmpty) {
        Navigator.pop(context); // 다 비우면 이전 화면으로
        return;
      }
      if (_selected >= _images.length) _selected = _images.length - 1;
    });
  }

  Future<void> _addMore() async {
    if (_images.length >= _maxImages) {
      _showSnack('최대 $_maxImages장까지 추가할 수 있어요.');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
        decoration: BoxDecoration(
          color: const Color(0xFF4F4F4F),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceItem(
              icon: Icons.photo_library_outlined,
              label: '사진 보관함',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _SourceItem(
              icon: Icons.camera_alt_outlined,
              label: '사진 찍기',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final remaining = _maxImages - _images.length;
        final files = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1600,
          limit: remaining,
        );
        if (files.isEmpty) return;
        final loaded = await Future.wait(files.map((f) => f.readAsBytes()));
        if (!mounted) return;
        setState(() => _images.addAll(loaded.take(remaining)));
      } else {
        // 카메라 — 웹은 getUserMedia 위젯, 모바일은 image_picker.
        Uint8List? bytes;
        // captureFromWebcam은 웹 빌드에서만 실제로 동작; 그 외엔 stub이 null 반환.
        bytes = await captureFromWebcam(Navigator.of(context));
        if (bytes == null) {
          final file = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
            maxWidth: 1600,
          );
          if (file == null) return;
          bytes = await file.readAsBytes();
        }
        if (!mounted) return;
        setState(() => _images.add(bytes!));
      }
    } on Exception catch (e) {
      _showSnack('사진을 가져오지 못했어요: $e');
    }
  }

  void _startAnalysis() {
    if (_images.isEmpty) return;
    final job = AnalysisJobsStore.I.start(_images);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OcrLoadingScreen(job: job)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _images.length;
    final canAddMore = count < _maxImages;
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new, size: 24),
              ),
              const SizedBox(height: 36),
              Text(
                count > 1
                    ? '$count장의 사진으로\n분석을 진행할까요?'
                    : '이 사진으로\n분석을 진행할까요?',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 26,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 20),

              // 메인 프리뷰
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _images.isEmpty
                        ? const SizedBox.shrink()
                        : InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: Image.memory(
                              _images[_selected],
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 썸네일 스트립 + "추가" 타일
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + (canAddMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    if (i == _images.length) {
                      // 마지막은 "사진 추가" 타일
                      return _AddTile(onTap: _addMore);
                    }
                    return _ThumbTile(
                      bytes: _images[i],
                      selected: i == _selected,
                      onTap: () => setState(() => _selected = i),
                      onRemove: () => _removeAt(i),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFB8BFC9),
                            width: 1.2,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '다시 선택',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5A3EA6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _images.isEmpty ? null : _startAnalysis,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          count > 1 ? '분석 시작 ($count장)' : '분석 시작',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  final Uint8List bytes;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ThumbTile({
    required this.bytes,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  bytes,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close,
                      size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: const Icon(Icons.add_a_photo_outlined,
            color: AppColors.primary),
      ),
    );
  }
}

class _SourceItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(icon, size: 22, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
