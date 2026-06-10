import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/analysis_jobs_store.dart';
import '../../data/services/ocr_job_runner.dart';
import '../../main.dart' show navigatorKey, scaffoldMessengerKey;
import 'ocr_result_screen.dart';

class OcrLoadingScreen extends StatefulWidget {
  /// The in-flight OCR job to observe. The job's Future may already be
  /// running (when re-opened from the analyses tab) or freshly started.
  final OcrJob job;

  const OcrLoadingScreen({super.key, required this.job});

  @override
  State<OcrLoadingScreen> createState() => _OcrLoadingScreenState();
}

class _OcrLoadingScreenState extends State<OcrLoadingScreen> {
  // "진행 중" 메시지가 기본. "거의 다 완료"는 진짜 끝나갈 때(타이머)에만 노출.
  static const String _progressMsg = '성분표를 분석하고 있어요\n잠시만 기다려주세요';
  static const String _nearlyDoneMsg = '거의 다 완료됐어요\n조금만 더 기다려주세요';
  String message = _progressMsg;

  @override
  void initState() {
    super.initState();
    // The job's future may have started earlier (e.g. user opened this
    // screen from an in-progress card). Attaching .then after completion
    // still fires immediately with the cached result.
    widget.job.future.then(_onComplete, onError: _onError);

    // 분석이 길어질 수 있어 메시지 전환은 보수적으로 — 30분 후에만 "거의 다".
    Future.delayed(const Duration(minutes: 30), () {
      if (!mounted) return;
      setState(() => message = _nearlyDoneMsg);
    });
  }

  void _onComplete(OcrJobResult result) {
    // Still on the loading screen → take the user directly to the result.
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _buildResultScreen(result),
        ),
      );
      return;
    }
    // User went home — surface a snackbar with a quick "결과 보기" action.
    final messenger = scaffoldMessengerKey.currentState;
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('성분 분석이 완료됐어요.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '결과 보기',
            onPressed: () {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => _buildResultScreen(result),
                ),
              );
            },
          ),
        ),
      );
  }

  void _onError(Object error, StackTrace _) {
    final msg = error is OcrJobError ? error.message : '$error';
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context);
    } else {
      scaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  OcrResultScreen _buildResultScreen(OcrJobResult result) {
    return buildResultScreen(result.data,
        imageBytes: widget.job.primaryImageBytes);
  }

  /// "홈으로 가기" — 분석은 백그라운드에서 계속, 사용자는 메인 탭으로 복귀.
  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new, size: 26),
              ),
              const SizedBox(height: 78),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 30,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '분석은 백그라운드에서 계속돼요.\n홈으로 가도 완료되면 알려드릴게요.',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSub,
                ),
              ),
              const Spacer(),
              const Center(child: _BlobLoading()),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _goHome,
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text(
                    '홈으로 가기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlobLoading extends StatefulWidget {
  const _BlobLoading();

  @override
  State<_BlobLoading> createState() => _BlobLoadingState();
}

class _BlobLoadingState extends State<_BlobLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final value = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(-18 + value * 20, 0),
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(18 - value * 20, -8),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
