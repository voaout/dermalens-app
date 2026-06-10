import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/primary_button.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _type;

  static const _types = [
    '서비스 이용',
    '계정 / 로그인',
    '분석 결과',
    '추천',
    '버그 신고',
    '기타',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
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
    if (_type == null) {
      _showSnack('문의 유형을 선택해 주세요.');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showSnack('제목을 입력해 주세요.');
      return;
    }
    if (_bodyController.text.trim().length < 10) {
      _showSnack('문의 내용은 10자 이상 입력해 주세요.');
      return;
    }
    _showSnack('문의가 접수되었어요. 영업일 기준 1~2일 내 답변드릴게요.');
    Navigator.pop(context);
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
                      '문의하기',
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
                    '서비스 이용 중 궁금한 점을 보내주세요.\n작성하신 이메일로 답변을 드려요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const _Label('문의 유형', required: true),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final sel = _type == t;
                      return GestureDetector(
                        onTap: () => setState(() => _type = t),
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
                              color: sel
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),
                  const _Label('제목', required: true),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _titleController,
                    hint: '문의 제목을 간단히 적어주세요.',
                    maxLength: 40,
                  ),

                  const SizedBox(height: 22),
                  const _Label('문의 내용', required: true),
                  const SizedBox(height: 8),
                  _BodyField(controller: _bodyController),

                  const SizedBox(height: 22),
                  const _Label('답변 받을 이메일', required: false),
                  const SizedBox(height: 8),
                  _ReadOnlyField(value: UserProfile.email),
                  const SizedBox(height: 6),
                  const Text(
                    '계정 이메일로 답변을 드려요. 변경은 개인 정보 화면에서 가능해요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5,
                      color: AppColors.textSub,
                    ),
                  ),

                  const SizedBox(height: 32),
                  PrimaryButton(text: '문의 보내기', onTap: _submit),
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
        ],
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLength;

  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isCollapsed: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14.5,
          color: AppColors.textMain,
        ),
      ),
    );
  }
}

class _BodyField extends StatefulWidget {
  final TextEditingController controller;
  const _BodyField({required this.controller});

  @override
  State<_BodyField> createState() => _BodyFieldState();
}

class _BodyFieldState extends State<_BodyField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handle);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handle);
    super.dispose();
  }

  void _handle() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final len = widget.controller.text.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: widget.controller,
            minLines: 5,
            maxLines: 8,
            maxLength: 500,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '문의하실 내용을 자세히 작성해주세요. (10자 이상)',
              isCollapsed: true,
              counterText: '',
            ),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              height: 1.55,
              color: AppColors.textMain,
            ),
          ),
          Text(
            '$len / 500',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11.5,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14.5,
                color: AppColors.textSub,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: AppColors.textSub),
        ],
      ),
    );
  }
}
