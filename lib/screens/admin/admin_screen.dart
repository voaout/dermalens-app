import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_session.dart';
import '../../data/services/auth_service.dart';
import '../../widgets/common/primary_button.dart';
import '../main/main_tab_screen.dart';

/// Hidden developer / admin screen.
///
/// Not exposed in normal navigation — reached via the secret tap sequence on
/// the splash screen. Intended for dev/test/demo: inspect system state, run a
/// health check, set a test session, and jump straight into the app.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _userIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();

  String _healthStatus = '확인 안 함';
  bool _busy = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _checkHealth() async {
    setState(() {
      _busy = true;
      _healthStatus = '확인 중…';
    });
    try {
      await ApiClient.I.get(Api.health);
      if (!mounted) return;
      setState(() => _healthStatus = '정상 (서버 연결됨)');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _healthStatus = '오류: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setManualSession() {
    final id = _userIdController.text.trim();
    if (id.isEmpty) {
      _snack('user_id를 입력해 주세요.');
      return;
    }
    AuthSession.save(token: 'dev-token', userId: id);
    setState(() {});
    _snack('테스트 세션을 설정했어요. (user_id: $id)');
  }

  Future<void> _testLogin() async {
    final email = _emailController.text.trim();
    final pw = _pwController.text;
    if (email.isEmpty || pw.isEmpty) {
      _snack('이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.login(email: email, password: pw);
      if (!mounted) return;
      setState(() {});
      _snack('로그인 성공 (user_id: ${AuthSession.userId})');
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearSession() {
    AuthSession.clear();
    setState(() {});
    _snack('세션을 초기화했어요.');
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainTabScreen()),
      (route) => false,
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
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '관리자 · 개발자 모드',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  const Icon(Icons.lock_outline, size: 18, color: AppColors.textSub),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  const Text(
                    '개발·테스트·시연용 숨김 화면입니다.\n일반 사용자에게 노출되지 않습니다.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // --- 서버 ---
                  const _SectionTitle('서버'),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Base URL', value: Api.baseUrl),
                  _InfoRow(label: '상태', value: _healthStatus),
                  const SizedBox(height: 10),
                  _OutlineButton(
                    label: '서버 상태 확인 (health)',
                    onTap: _busy ? null : _checkHealth,
                  ),

                  const SizedBox(height: 26),

                  // --- 세션 ---
                  const _SectionTitle('세션'),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: '로그인',
                    value: AuthSession.isLoggedIn ? '로그인됨' : '로그아웃',
                  ),
                  _InfoRow(
                    label: 'user_id',
                    value: '${AuthSession.userId ?? '-'}',
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _userIdController,
                    hint: 'user_id (예: 1)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _OutlineButton(
                    label: 'user_id로 테스트 세션 설정',
                    onTap: _setManualSession,
                  ),
                  const SizedBox(height: 18),
                  _Field(controller: _emailController, hint: '이메일'),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _pwController,
                    hint: '비밀번호',
                    obscure: true,
                  ),
                  const SizedBox(height: 8),
                  _OutlineButton(
                    label: '테스트 로그인',
                    onTap: _busy ? null : _testLogin,
                  ),
                  const SizedBox(height: 8),
                  _OutlineButton(
                    label: '세션 초기화',
                    onTap: _clearSession,
                    destructive: true,
                  ),

                  const SizedBox(height: 30),

                  // --- 바로가기 ---
                  const _SectionTitle('바로가기'),
                  const SizedBox(height: 12),
                  PrimaryButton(text: '메인 화면(홈)으로 이동', onTap: _goHome),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textMain,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: AppColors.textSub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          color: AppColors.textMain,
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  const _OutlineButton({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE15252) : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onTap == null ? AppColors.border : color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.textSub : color,
          ),
        ),
      ),
    );
  }
}
