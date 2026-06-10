import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../widgets/common/primary_button.dart';
import '../admin/admin_screen.dart';
import '../main/main_tab_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoMorph;
  late final Animation<double> _actionsReveal;
  Timer? _startTimer;

  // Hidden developer entry: tap the top corners in the secret order.
  // Sequence: left, right, left, right, left.
  static const List<String> _secret = ['L', 'R', 'L', 'R', 'L'];
  final List<String> _taps = [];
  Timer? _tapResetTimer;

  bool _kakaoLoading = false;

  Future<void> _loginWithKakao() async {
    debugPrint('[Kakao] splash 카카오 버튼 탭됨');
    if (_kakaoLoading) return;

    // appKey 안전 접근 — init 실패 시 getter가 throw할 수 있음.
    String? appKey;
    try {
      appKey = KakaoSdk.appKey;
    } catch (_) {}
    debugPrint('[Kakao] 현재 appKey: $appKey');
    final bad = appKey == null ||
        appKey.isEmpty ||
        appKey.startsWith('YOUR_');
    if (bad) {
      await _showKakaoSetupDialog();
      return;
    }

    setState(() => _kakaoLoading = true);
    try {
      // 1) SDK로 access_token 받기 (카카오톡 → 폴백: 계정 웹로그인)
      OAuthToken token;
      bool talkInstalled = false;
      try {
        talkInstalled = await isKakaoTalkInstalled();
      } catch (_) {}

      if (talkInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 2) 백엔드에 access_token 전송 → 우리 JWT 발급 + 세션 저장
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
      if (mounted) setState(() => _kakaoLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
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
          'flutter run \\\n'
          '  --dart-define=KAKAO_NATIVE_KEY=… \\\n'
          '  --dart-define=KAKAO_JS_KEY=…\n\n'
          '그리고 AndroidManifest.xml / Info.plist의 "YOUR_KAKAO_NATIVE_APP_KEY" 자리를 실제 키로 교체하세요.',
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

  void _onCornerTap(String side) {
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(seconds: 2), () => _taps.clear());

    _taps.add(side);
    if (_taps.length > _secret.length) {
      _taps.removeRange(0, _taps.length - _secret.length);
    }

    if (_taps.length == _secret.length &&
        _listEquals(_taps, _secret)) {
      _taps.clear();
      _tapResetTimer?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoMorph = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeInOutCubic),
    );

    _actionsReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    _startTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _tapResetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 4),

              AnimatedBuilder(
                animation: _logoMorph,
                builder: (context, _) {
                  return LogoText(collapseProgress: _logoMorph.value);
                },
              ),

              const Spacer(flex: 3),

              AnimatedBuilder(
                animation: _actionsReveal,
                builder: (context, child) {
                  final v = _actionsReveal.value;
                  return IgnorePointer(
                    ignoring: v < 1.0,
                    child: Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1.0 - v) * 24),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _AuthActions(
                  onLoginTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  onRegisterTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  onKakaoTap: _loginWithKakao,
                ),
              ),
                ],
              ),
            ),
          ),

          // Hidden developer entry — invisible tap zones in the top corners.
          Positioned(
            top: 0,
            left: 0,
            child: _CornerTap(onTap: () => _onCornerTap('L')),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _CornerTap(onTap: () => _onCornerTap('R')),
          ),
        ],
      ),
    );
  }
}

class _CornerTap extends StatelessWidget {
  final VoidCallback onTap;
  const _CornerTap({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Transparent, no visual — only catches taps in the corner.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(width: 64, height: 64),
    );
  }
}

class _AuthActions extends StatelessWidget {
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onKakaoTap;

  const _AuthActions({
    required this.onLoginTap,
    required this.onRegisterTap,
    required this.onKakaoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryButton(
          text: '로그인',
          onTap: onLoginTap,
        ),

        const SizedBox(height: 14),

        TextButton(
          onPressed: onRegisterTap,
          child: const Text(
            '회원가입',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        PrimaryButton(
          text: '카카오 로그인',
          backgroundColor: const Color(0xFFFFE500),
          textColor: Colors.black,
          onTap: onKakaoTap,
        ),

        const SizedBox(height: 34),
      ],
    );
  }
}

class LogoText extends StatelessWidget {
  final double collapseProgress;

  const LogoText({
    super.key,
    this.collapseProgress = 0,
  });

  static const _textStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -1.2,
    height: 1,
  );

  static double? _ermaWidthCache;
  static double _measureErmaWidth() {
    final cached = _ermaWidthCache;
    if (cached != null) return cached;
    final tp = TextPainter(
      text: const TextSpan(text: 'erma', style: _textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width;
    _ermaWidthCache = w;
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final t = collapseProgress.clamp(0.0, 1.0);
    final remain = 1.0 - t;
    final ermaWidth = _measureErmaWidth();

    // Compensate the Center re-centering of the Row so the `D` glyph stays
    // anchored at the final DLens position throughout the morph.
    final anchorOffset = ermaWidth * remain / 2;

    return Center(
      child: Transform.translate(
        offset: Offset(anchorOffset, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: const [
                // Zero-footprint glass disc painted behind the `D`. Uses
                // OverflowBox so the 44x44 circle does not contribute to the
                // Row's layout — the text flows exactly as if the glass were
                // not there.
                SizedBox.shrink(child: _BackdropGlass(size: 44)),
                Text('D', style: _textStyle),
              ],
            ),

            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: remain,
                heightFactor: 1,
                child: Opacity(
                  opacity: remain,
                  child: const Text('erma', style: _textStyle),
                ),
              ),
            ),

            const Text('Lens', style: _textStyle),
          ],
        ),
      ),
    );
  }
}

class _BackdropGlass extends StatelessWidget {
  final double size;

  const _BackdropGlass({required this.size});

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.45),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
