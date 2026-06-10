import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/review_service.dart';
import '../../widgets/common/primary_button.dart';

class SatisfactionScreen extends StatefulWidget {
  const SatisfactionScreen({super.key});

  @override
  State<SatisfactionScreen> createState() => _SatisfactionScreenState();
}

class _SatisfactionScreenState extends State<SatisfactionScreen> {
  int _rating = 0;
  final Set<String> _topics = {};
  final _commentController = TextEditingController();

  static const _ratingLabels = {
    1: '많이 아쉬워요',
    2: '아쉬워요',
    3: '보통이에요',
    4: '만족해요',
    5: '아주 만족해요',
  };

  static const _topicOptions = [
    '추천 정확도',
    '분석 결과',
    '사용 편의성',
    '디자인',
    '속도',
    '성분 정보',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
      ));
  }

  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    if (_rating == 0) {
      _showSnack('별점을 선택해 주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final comment = [
        if (_topics.isNotEmpty) '좋았던 점: ${_topics.join(', ')}',
        if (_commentController.text.trim().isNotEmpty)
          _commentController.text.trim(),
      ].join('\n');
      await ReviewService.submitFeedback(
        feedbackType: 'SATISFACTION',
        satisfactionScore: _rating,
        sideEffectText: comment,
      );
      if (!mounted) return;
      _showSnack('소중한 평가 감사해요! 추천 개선에 활용할게요.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '만족도 평가',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                children: [
                  const Text(
                    'DermaLens 사용 경험은 어떠셨나요?\n남겨주신 평가는 추천 품질 개선에 활용돼요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 26),

                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final filled = i < _rating;
                            return GestureDetector(
                              onTap: () => setState(() => _rating = i + 1),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Icon(
                                  filled
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 44,
                                  color: const Color(0xFFFFC93C),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _rating == 0
                              ? '별점을 눌러 평가해 주세요'
                              : _ratingLabels[_rating]!,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _rating == 0
                                ? AppColors.textSub
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    '어떤 점이 좋았나요?',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '복수 선택 · 선택하지 않아도 돼요',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _topicOptions.map((t) {
                      final sel = _topics.contains(t);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (!_topics.add(t)) _topics.remove(t);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  sel ? Colors.white : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    '의견 남기기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _commentController,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '개선할 점이나 좋았던 점을 자유롭게 남겨주세요.',
                        isCollapsed: true,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14.5,
                        height: 1.5,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  PrimaryButton(text: '평가 보내기', onTap: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
