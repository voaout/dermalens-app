import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/splash_screen.dart';

/// 카카오 개발자 콘솔에서 발급받은 키.
///   - nativeAppKey: Android/iOS 앱 키
///   - javaScriptAppKey: 웹 빌드용 JS 키
/// 실제 키로 교체하거나, 빌드 시 `--dart-define=KAKAO_NATIVE_KEY=...`로 주입.
const _kKakaoNativeKey = String.fromEnvironment(
  'KAKAO_NATIVE_KEY',
  defaultValue: 'edcd9b1947b5b240da054d9a8a79db7a',
);
const _kKakaoJavascriptKey = String.fromEnvironment(
  'KAKAO_JS_KEY',
  defaultValue: '8dfb940028a3a9b2e8ca780db31dc5b0',
);

/// Global keys so background work (OCR completion, push-style alerts, …)
/// can show a SnackBar / navigate without holding a BuildContext.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    KakaoSdk.init(
      nativeAppKey: _kKakaoNativeKey,
      javaScriptAppKey: _kKakaoJavascriptKey,
    );
  } catch (e, st) {
    // 키가 placeholder거나 웹에서 Kakao JS가 아직 로드 안 됐을 때 → 앱 시작
    // 자체는 살려두고 카카오 호출만 실패하게.
    debugPrint('[Kakao] KakaoSdk.init failed: $e\n$st');
  }
  runApp(
    const ProviderScope(
      child: DermaLensApp(),
    ),
  );
}

class DermaLensApp extends StatelessWidget {
  const DermaLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DermaLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const SplashScreen(),
    );
  }
}
