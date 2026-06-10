import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../main/main_tab_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showKakaoSetupDialog() async {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '카카오 키 설정 필요',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          '카카오 앱 키가 설정되지 않았어요.\n\n'
          '실행 시 키를 주입해 주세요:\n'
          'flutter run\n'
          '  --dart-define=KAKAO_NATIVE_KEY=…\n'
          '  --dart-define=KAKAO_JS_KEY=…\n\n'
          '추가로 AndroidManifest.xml / Info.plist의 "YOUR_KAKAO_NATIVE_APP_KEY" 자리도 실제 키로 교체해야 합니다.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithKakao() async {
    // 탭이 실제로 도달했는지 콘솔에서 즉시 확인 가능.
    debugPrint('[Kakao] 로그인 버튼 탭됨');
    if (_loading) return;

    // KakaoSdk.appKey getter가 init 안 됐을 때 throw할 수 있어 방어적으로.
    String? appKey;
    try {
      appKey = KakaoSdk.appKey;
    } catch (_) {
      appKey = null;
    }
    debugPrint('[Kakao] 현재 appKey: $appKey');
    final bad = appKey == null ||
        appKey.isEmpty ||
        appKey.startsWith('YOUR_');
    if (bad) {
      await _showKakaoSetupDialog();
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) 카카오 SDK로 access_token 받기.
      //    - 카카오톡 앱이 깔려 있으면 그쪽으로 (지문/얼굴/저장된 세션으로 빠름).
      //    - 실패하거나 미설치면 카카오 계정 웹로그인으로 폴백.
      OAuthToken token;
      bool talkInstalled = false;
      try {
        talkInstalled = await isKakaoTalkInstalled();
      } catch (_) {
        // Web/desktop처럼 지원 안 되는 환경 — 계정 로그인으로 진행.
      }

      if (talkInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          // 사용자가 카카오톡에서 취소했거나 실패 → 계정 로그인 폴백.
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 2) access_token을 백엔드로 전송 → 우리 JWT 발급 + 세션 저장.
      await AuthService.kakaoAppLogin(token.accessToken);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainTabScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(
          e.isUnauthorized ? '카카오 계정으로 로그인할 수 없어요.' : e.message);
    } on KakaoAuthException catch (e) {
      if (!mounted) return;
      _showSnack('카카오 인증 실패: ${e.errorDescription ?? e.error}');
    } on KakaoClientException catch (e) {
      if (!mounted) return;
      _showSnack('카카오 클라이언트 오류: ${e.reason}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('카카오 로그인 중 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final pw = _pwController.text;
    if (email.isEmpty || pw.isEmpty) {
      _showSnack('이메일과 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.login(email: email, password: pw);
      if (!mounted) return;
      // Clear the auth stack so MainTabScreen becomes the root route.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainTabScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.isUnauthorized ? '아이디 또는 비밀번호가 올바르지 않아요.' : e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 52),
              const AppLogo(fontSize: 36, goHomeOnTap: false),
              const SizedBox(height: 46),
              CustomTextField(
                label: '이메일',
                hintText: 'example@dermalens.com',
                controller: _emailController,
              ),
              const SizedBox(height: 18),
              CustomTextField(
                label: '비밀번호',
                hintText: '비밀번호를 입력하세요',
                obscureText: true,
                controller: _pwController,
              ),
              const Spacer(),
              _loading
                  ? const _LoadingButton()
                  : PrimaryButton(text: '로그인', onTap: _login),
              const SizedBox(height: 14),
              _KakaoLoginButton(
                onTap: _loading ? null : _loginWithKakao,
              ),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카카오 공식 가이드 톤(노란 #FEE500 + 검은 텍스트)에 가깝게 그린 버튼.
class _KakaoLoginButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _KakaoLoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_rounded,
            size: 18, color: Color(0xFF3C1E1E)),
        label: const Text(
          '카카오로 로그인',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3C1E1E),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE500),
          disabledBackgroundColor: const Color(0xFFFFF4A0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  const _LoadingButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    );
  }
}
