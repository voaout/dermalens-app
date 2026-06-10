import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/review_service.dart';
import '../../widgets/common/primary_button.dart';

class SideEffectReportScreen extends StatefulWidget {
  const SideEffectReportScreen({super.key});

  @override
  State<SideEffectReportScreen> createState() => _SideEffectReportScreenState();
}

class _SideEffectReportScreenState extends State<SideEffectReportScreen> {
  final _productController = TextEditingController();
  final _detailController = TextEditingController();

  final Set<String> _ingredients = {};
  final Set<String> _symptoms = {};
  String? _severity;

  static const _ingredientOptions = [
    '향료',
    '알코올',
    '에센셜오일',
    '파라벤',
    '색소',
    '산성분(AHA/BHA)',
    '레티놀',
    '잘 모름',
  ];

  static const _symptomOptions = [
    '가려움',
    '붉어짐',
    '따가움',
    '뾰루지/여드름',
    '각질/건조',
    '부어오름',
    '화끈거림',
    '기타',
  ];

  static const _severityOptions = ['경미', '보통', '심함'];

  @override
  void dispose() {
    _productController.dispose();
    _detailController.dispose();
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
    if (_productController.text.trim().isEmpty) {
      _showSnack('제품명을 입력해 주세요.');
      return;
    }
    if (_symptoms.isEmpty) {
      _showSnack('증상을 한 가지 이상 선택해 주세요.');
      return;
    }
    if (_severity == null) {
      _showSnack('증상 정도를 선택해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      // The API stores side-effect reports as free text, so compose the
      // structured selections into a readable summary.
      final parts = <String>[
        '제품: ${_productController.text.trim()}',
        if (_ingredients.isNotEmpty) '의심 성분: ${_ingredients.join(', ')}',
        '증상: ${_symptoms.join(', ')}',
        '정도: $_severity',
        if (_detailController.text.trim().isNotEmpty)
          '상세: ${_detailController.text.trim()}',
      ];
      await ReviewService.submitFeedback(
        feedbackType: 'SIDE_EFFECT',
        sideEffectText: parts.join('\n'),
      );
      if (!mounted) return;
      _showSnack('신고가 접수되었어요. 소중한 제보 감사합니다.');
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
                      '부작용 신고',
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
                    '사용 후 문제가 생긴 제품을 신고해 주세요.\n다른 사용자의 안전한 선택에 큰 도움이 돼요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const _Label('제품명', required: true),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _productController,
                    hint: '문제가 발생한 제품명을 입력해 주세요.',
                    maxLength: 50,
                  ),

                  const SizedBox(height: 22),
                  const _Label('의심 성분', required: false),
                  const SizedBox(height: 10),
                  _ChipWrap(
                    options: _ingredientOptions,
                    isSelected: _ingredients.contains,
                    onTap: (v) => setState(() {
                      if (!_ingredients.add(v)) _ingredients.remove(v);
                    }),
                  ),

                  const SizedBox(height: 22),
                  const _Label('증상', required: true),
                  const SizedBox(height: 10),
                  _ChipWrap(
                    options: _symptomOptions,
                    isSelected: _symptoms.contains,
                    onTap: (v) => setState(() {
                      if (!_symptoms.add(v)) _symptoms.remove(v);
                    }),
                  ),

                  const SizedBox(height: 22),
                  const _Label('증상 정도', required: true),
                  const SizedBox(height: 10),
                  _ChipWrap(
                    options: _severityOptions,
                    isSelected: (v) => _severity == v,
                    onTap: (v) => setState(() => _severity = v),
                  ),

                  const SizedBox(height: 22),
                  const _Label('상세 설명', required: false),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _detailController,
                    hint: '증상이 나타난 시점, 사용 빈도 등을 적어주세요.',
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 32),
                  PrimaryButton(text: '신고 접수하기', onTap: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  const _Label(this.text, {required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE15252),
              )),
        ] else ...[
          const SizedBox(width: 6),
          const Text('선택',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                color: AppColors.textSub,
              )),
        ],
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> options;
  final bool Function(String) isSelected;
  final ValueChanged<String> onTap;

  const _ChipWrap({
    required this.options,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final sel = isSelected(o);
        return GestureDetector(
          onTap: () => onTap(o),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              o,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColors.primaryDark,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;

  const _InputField({
    required this.controller,
    required this.hint,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isCollapsed: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14.5,
          height: 1.5,
          color: AppColors.textMain,
        ),
      ),
    );
  }
}
