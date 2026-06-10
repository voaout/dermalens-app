import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/beta_rewards_store.dart';
import '../../data/services/ingredient_scan_service.dart';
import '../../data/services/parsing.dart';
import '../../data/services/product_service.dart';
import '../../widgets/common/product_image.dart';
import '../scan/widgets/image_source_sheet.dart' show ImageSourceSheet;

/// 🎯 사용자 OCR 성분 등록 (베타).
///
/// 흐름:
///   1) 제품명 검색 → 한 개 선택
///   2) 하단 카메라 버튼으로 성분표 촬영
///   3) 백엔드 `/api/products/{id}/ingredient-scan/`로 전송 → 보상 응답
///   4) 결과 다이얼로그 표시 + 누적 포인트 갱신
class IngredientRegisterScreen extends StatefulWidget {
  const IngredientRegisterScreen({super.key});

  @override
  State<IngredientRegisterScreen> createState() =>
      _IngredientRegisterScreenState();
}

class _IngredientRegisterScreenState extends State<IngredientRegisterScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  bool _uploading = false;

  /// 분석 직전까지 사용자가 모아둔 성분표 사진들 (다중 분석용).
  final List<Uint8List> _images = [];
  static const int _maxImages = 10;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final data = await ProductService.search(q);
      if (!mounted) return;
      setState(() {
        _results = listOf(data).map(normalizeProduct).toList();
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
      _snack(e.message);
    }
  }

  void _pickProduct(Map<String, dynamic> p) {
    setState(() {
      _selected = p;
      _results = [];
      _searchController.text = '${p['name'] ?? ''}';
    });
    FocusScope.of(context).unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _searchController.clear();
    });
  }

  /// 사진 추가 — source 시트로 보관함/카메라 선택 후 1장 이상 추가.
  Future<void> _addImages() async {
    if (_uploading) return;
    if (_images.length >= _maxImages) {
      _snack('최대 $_maxImages장까지 추가할 수 있어요.');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => const ImageSourceSheet(),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        // 보관함에선 한 번에 여러 장 멀티 선택.
        final remaining = _maxImages - _images.length;
        final files = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 1600,
          limit: remaining,
        );
        if (files.isEmpty) return;
        final loaded = await Future.wait(files.map((f) => f.readAsBytes()));
        if (!mounted) return;
        setState(() {
          _images.addAll(loaded.take(remaining));
        });
      } else {
        // 카메라는 한 장씩.
        final file = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() => _images.add(bytes));
      }
    } on Exception catch (e) {
      _snack(_readableError(e));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  /// 수집된 사진들을 한 번의 요청으로 묶어서 업로드.
  Future<void> _uploadAll() async {
    if (_uploading) return;
    final product = _selected;
    if (product == null) {
      _snack('먼저 제품을 선택해 주세요.');
      return;
    }
    final productId = product['id'];
    if (productId == null) {
      _snack('이 제품은 등록할 수 없어요.');
      return;
    }
    if (_images.isEmpty) {
      _snack('성분표 사진을 한 장 이상 추가해 주세요.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final res = await IngredientScanService.scanWithMultipleBytes(
        productId,
        _images,
      );
      if (!mounted) return;
      _handleScanResult(res, _images.first);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showResultDialog(
        title: '등록 불가',
        message: e.message,
        success: false,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _handleScanResult(dynamic res, Uint8List imageBytes) {
    final m = mapOf(res);
    final ok = m['success'] != false;
    final rewardRaw = m['reward_points'];
    final reward = rewardRaw is num ? rewardRaw.toInt() : 0;
    final totalRaw = m['total_points'];
    final total = totalRaw is num ? totalRaw.toInt() : null;
    final isFirst = m['is_first'] == true;
    final detected = m['detected_count'];
    final newlyConfirmed = m['newly_confirmed'];
    final message = str(m, ['message']);

    if (total != null) {
      BetaRewardsStore.I.setTotalPoints(total);
    } else if (ok && reward > 0) {
      BetaRewardsStore.I.setTotalPoints(
          BetaRewardsStore.I.totalPoints + reward);
    }

    if (ok) {
      _showResultDialog(
        title: isFirst ? '🎉 최초 등록 완료!' : '✅ 검증 완료!',
        message: message.isEmpty
            ? '성분이 등록되었습니다.'
            : message,
        success: true,
        reward: reward,
        total: total ?? BetaRewardsStore.I.totalPoints,
        detected: detected is num ? detected.toInt() : null,
        newlyConfirmed: newlyConfirmed is num ? newlyConfirmed.toInt() : null,
      );
    } else {
      // OCR 실패 (success: false, reward 0, 시도 미차감)
      _showResultDialog(
        title: 'OCR 인식 실패',
        message: message.isEmpty
            ? '성분을 인식하지 못했어요. 빛/초점/각도를 확인하고 다시 시도해 주세요.'
            : message,
        success: false,
        canRetry: true,
      );
    }
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required bool success,
    int reward = 0,
    int? total,
    int? detected,
    int? newlyConfirmed,
    bool canRetry = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSub,
              ),
            ),
            if (success && reward > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '+${reward}p 적립',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (total != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '누적 ${total}p',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (success &&
                (detected != null || newlyConfirmed != null)) ...[
              const SizedBox(height: 10),
              if (detected != null)
                _StatRow(label: '인식된 성분', value: '$detected개'),
              if (newlyConfirmed != null)
                _StatRow(label: 'DB에 신규 확정', value: '$newlyConfirmed개'),
            ],
          ],
        ),
        actions: [
          if (canRetry)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('다시 시도'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                Navigator.pop(context); // 등록 화면 닫고 홈으로
              },
              child: const Text('확인'),
            ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _readableError(Object e) {
    final m = '$e'.toLowerCase();
    if (m.contains('camera_access_denied') || m.contains('permission')) {
      return '카메라 권한을 허용해 주세요.';
    }
    if (m.contains('no_available_camera')) {
      return '사용 가능한 카메라가 없어요.';
    }
    return '카메라를 열지 못했어요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '성분 등록',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: BetaRewardsStore.I,
                    builder: (context, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${BetaRewardsStore.I.totalPoints}p',
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 검색 필드 (제품 선택 후엔 선택된 카드로 대체)
              if (_selected == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 20, color: AppColors.textSub),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onQueryChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _search,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14),
                            hintText: '제품명, 브랜드 검색',
                            hintStyle: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              color: AppColors.textSub,
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _SelectedProductCard(
                  product: _selected!,
                  onClear: _clearSelection,
                ),

              const SizedBox(height: 12),

              // 결과/안내 영역
              Expanded(
                child: _selected != null
                    ? _readyArea()
                    : _searchArea(),
              ),

              // 하단 카메라 버튼 + 규칙
              _bottomActions(),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchArea() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? '등록할 제품을 검색해 주세요.'
              : '검색 결과가 없어요.',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            color: AppColors.textSub,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _results[i];
        return GestureDetector(
          onTap: () => _pickProduct(p),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ProductImage(
                  url: p['imageUrl'],
                  width: 52,
                  height: 52,
                  borderRadius: 10,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['brand'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11.5,
                          color: AppColors.textSub,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p['name'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle_outline,
                    color: AppColors.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _readyArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.center_focus_strong,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            '성분표를 또렷하게 찍어 주세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '한글로 성분이 적힌 면이 잘 보여야 인식률이 높아요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    final ready = _selected != null;
    final hasImages = _images.isNotEmpty;
    final canAddMore = _images.length < _maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasImages) ...[
          _ImageStrip(
            images: _images,
            onRemove: _uploading ? null : _removeImage,
          ),
          const SizedBox(height: 10),
        ],
        if (!hasImages)
          // 첫 추가: 풀-width primary 버튼 (성분표 추가)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (!ready || _uploading) ? null : _addImages,
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: const Text(
                '성분표 추가',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
        else
          // 사진이 1장 이상 → [+ 더 추가] + [분석 시작 (N장)]
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: (!canAddMore || _uploading) ? null : _addImages,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(
                      canAddMore ? '더 추가' : '최대',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (!ready || _uploading) ? null : _uploadAll,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload_rounded, size: 20),
                    label: Text(
                      _uploading
                          ? '업로드 중...'
                          : '분석 시작 (${_images.length}장)',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RuleRow(text: '제품당 선착순 10명까지 등록 가능 (이후 자동 마감)'),
              const _RuleRow(text: '같은 제품은 한 번만 등록할 수 있어요'),
              const _RuleRow(
                text: 'OCR 실패 시 0p (시도 차감 없음, 다시 찍으면 OK)',
                warn: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 수집된 성분표 사진들을 가로 썸네일로 표시. 각 썸네일 우상단 ×버튼으로
/// 개별 제거. 업로드 중에는 [onRemove]가 null이라 비활성.
class _ImageStrip extends StatelessWidget {
  final List<Uint8List> images;
  final void Function(int index)? onRemove;

  const _ImageStrip({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    images[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => onRemove!(i),
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
                // 순번 배지 (좌하단)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectedProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onClear;

  const _SelectedProductCard({
    required this.product,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          ProductImage(
            url: product['imageUrl'],
            width: 52,
            height: 52,
            borderRadius: 10,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product['brand'] ?? ''}',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11.5,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product['name'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: AppColors.textSub),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String text;
  final bool warn;
  const _RuleRow({required this.text, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppColors.danger : AppColors.textSub;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                height: 1.5,
                fontWeight: warn ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: AppColors.textSub,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
