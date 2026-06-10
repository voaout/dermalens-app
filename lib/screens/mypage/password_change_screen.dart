import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/primary_button.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
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
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      _showSnack('현재 비밀번호를 입력해 주세요.');
      return;
    }
    if (next.length < 8) {
      _showSnack('새 비밀번호는 8자 이상이어야 해요.');
      return;
    }
    if (next == current) {
      _showSnack('새 비밀번호는 현재 비밀번호와 달라야 해요.');
      return;
    }
    if (next != confirm) {
      _showSnack('새 비밀번호 확인이 일치하지 않아요.');
      return;
    }

    _showSnack('비밀번호가 변경되었어요.');
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
                      '비밀번호 변경',
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
                    '안전한 비밀번호로 정기적으로 변경해 주세요.\n8자 이상이어야 해요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 28),

                  const _Label('현재 비밀번호'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _currentController,
                    obscured: !_showCurrent,
                    onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  ),

                  const SizedBox(height: 20),
                  const _Label('새 비밀번호'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _newController,
                    obscured: !_showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),

                  const SizedBox(height: 20),
                  const _Label('새 비밀번호 확인'),
                  const SizedBox(height: 8),
                  _PasswordField(
                    controller: _confirmController,
                    obscured: !_showConfirm,
                    onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  ),

                  const SizedBox(height: 36),
                  PrimaryButton(text: '비밀번호 변경', onTap: _submit),
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
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textMain,
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscured;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.obscured,
    required this.onToggle,
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscured,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '••••••••',
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
