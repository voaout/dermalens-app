import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/primary_button.dart';

class ProductRequestScreen extends StatefulWidget {
  const ProductRequestScreen({super.key});

  @override
  State<ProductRequestScreen> createState() => _ProductRequestScreenState();
}

class _ProductRequestScreenState extends State<ProductRequestScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _ingredientsController = TextEditingController();

  String? _category;

  static const _categories = [
    '스킨/토너',
    '에센스/세럼/앰플',
    '크림',
    '로션',
    '미스트/오일',
    '클렌징',
    '선케어',
    '기타',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _ingredientsController.dispose();
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

  void _submit() {
    final name = _nameController.text.trim();
    final brand = _brandController.text.trim();

    if (name.isEmpty) {
      _showSnack('제품명을 입력해 주세요.');
      return;
    }
    if (brand.isEmpty) {
      _showSnack('브랜드를 입력해 주세요.');
      return;
    }
    if (_category == null) {
      _showSnack('카테고리를 선택해 주세요.');
      return;
    }

    _showSnack('상품 등록 요청이 접수되었어요. 검토 후 등록됩니다.');
    Navigator.pop(context);
  }

  void _attachPhoto() {
    _showSnack('사진 첨부 기능은 곧 제공돼요.');
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
                      '상품 등록 요청',
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
                    '데이터베이스에 없는 상품을 등록 요청할 수 있어요.\n검토 후 빠르게 추가됩니다.',
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
                    controller: _nameController,
                    hint: '예) 시카 페어 크림',
                  ),

                  const SizedBox(height: 20),
                  const _Label('브랜드', required: true),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _brandController,
                    hint: '예) 닥터자르트',
                  ),

                  const SizedBox(height: 20),
                  const _Label('카테고리', required: true),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((c) {
                      final sel = _category == c;
                      return GestureDetector(
                        onTap: () => setState(() => _category = c),
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
                            c,
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
                  ),

                  const SizedBox(height: 20),
                  const _Label('가격', required: false),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _priceController,
                    hint: '예) 29000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    suffixText: '원',
                  ),

                  const SizedBox(height: 20),
                  const _Label('제품 설명', required: false),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _descController,
                    hint: '제품 특징, 용량, 사용법 등을 적어주세요.',
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 300,
                  ),

                  const SizedBox(height: 20),
                  const _Label('주요 성분', required: false),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _ingredientsController,
                    hint: '쉼표로 구분해 주세요. 예) 판테놀, 알란토인, 마데카소사이드',
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                  ),

                  const SizedBox(height: 20),
                  const _Label('제품 사진', required: false),
                  const SizedBox(height: 8),
                  _PhotoAttachBox(onTap: _attachPhoto),

                  const SizedBox(height: 32),
                  PrimaryButton(text: '등록 요청 보내기', onTap: _submit),
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
          const Text(
            '*',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE15252),
            ),
          ),
        ] else ...[
          const SizedBox(width: 6),
          const Text(
            '선택',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: AppColors.textSub,
            ),
          ),
        ],
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final String? suffixText;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.suffixText,
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
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isCollapsed: true,
          counterText: '',
          suffixText: suffixText,
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

class _PhotoAttachBox extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoAttachBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add_a_photo_outlined,
                  size: 22, color: AppColors.primary),
              SizedBox(height: 6),
              Text(
                '사진 첨부',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
