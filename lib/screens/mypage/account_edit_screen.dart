import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/user_service.dart';
import '../../data/user_profile.dart';
import '../../widgets/common/primary_button.dart';
import 'password_change_screen.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  late final TextEditingController _nicknameController;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: UserProfile.nickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nicknameController.text.trim() != UserProfile.nickname;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
      ));
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final newNickname = _nicknameController.text.trim();

    if (newNickname.isEmpty) {
      _showSnack('닉네임을 입력해 주세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      await UserService.updateNickname(newNickname);
      UserProfile.nickname = newNickname;
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPasswordChange() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PasswordChangeScreen()),
    );
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
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '개인 정보',
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
                    '계정 정보를 수정할 수 있어요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const _FieldLabel('아이디'),
                  const SizedBox(height: 8),
                  _ReadOnlyField(value: UserProfile.userId),

                  const SizedBox(height: 20),
                  const _FieldLabel('이메일'),
                  const SizedBox(height: 8),
                  _ReadOnlyField(value: UserProfile.email),

                  const SizedBox(height: 20),
                  const _FieldLabel('닉네임'),
                  const SizedBox(height: 8),
                  _TextInputField(
                    controller: _nicknameController,
                    hint: '닉네임',
                    maxLength: 16,
                    onChanged: () => setState(() {}),
                  ),

                  const SizedBox(height: 28),
                  const _FieldLabel('비밀번호'),
                  const SizedBox(height: 8),
                  _PasswordRow(onTap: _openPasswordChange),

                  const SizedBox(height: 36),
                  PrimaryButton(
                    text: _hasChanges ? '저장' : '변경사항 없음',
                    onTap: _save,
                    backgroundColor:
                        _hasChanges ? AppColors.primary : AppColors.border,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

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

class _TextInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final VoidCallback onChanged;

  const _TextInputField({
    required this.controller,
    required this.hint,
    required this.onChanged,
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
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isCollapsed: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textMain,
        ),
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
                fontSize: 15,
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

class _PasswordRow extends StatelessWidget {
  final VoidCallback onTap;
  const _PasswordRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '••••••••',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  color: AppColors.textMain,
                  letterSpacing: 2,
                ),
              ),
            ),
            Text(
              '변경',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
