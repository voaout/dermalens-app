import 'package:flutter/foundation.dart';

import 'notifications_store.dart';
import 'services/ocr_job_runner.dart';

/// A single OCR job tracked across screens. Holds the in-flight Future plus
/// the input images (1+장), so a card on the analyses tab can re-attach to
/// the same job and resume showing the loading screen.
class OcrJob {
  final String id;
  /// 분석에 사용된 모든 사진 (1장 이상). 첫 번째 사진이 썸네일/대표 이미지로 쓰임.
  final List<Uint8List> imagesBytes;
  final DateTime startedAt;
  final Future<OcrJobResult> future;

  OcrJobResult? result;
  Object? error;

  OcrJob({
    required this.id,
    required this.imagesBytes,
    required this.startedAt,
    required this.future,
  });

  /// 단일 이미지가 필요한 화면(로딩/결과 폴백)에서 사용할 대표 이미지.
  Uint8List get primaryImageBytes => imagesBytes.first;
  int get imageCount => imagesBytes.length;

  bool get isDone => result != null || error != null;
  bool get isRunning => !isDone;
  bool get isSuccess => result != null;
  bool get isFailed => error != null;
}

/// Store of every OCR job started in this session. Outlives any single
/// screen so the analyses tab can render in-progress + completed cards.
class AnalysisJobsStore extends ChangeNotifier {
  AnalysisJobsStore._();
  static final AnalysisJobsStore I = AnalysisJobsStore._();

  final List<OcrJob> _jobs = [];

  /// Newest-first list of all jobs (running + completed).
  List<OcrJob> get jobs => List.unmodifiable(_jobs.reversed);

  List<OcrJob> get running => _jobs.where((j) => j.isRunning).toList();
  List<OcrJob> get completed =>
      _jobs.where((j) => j.isSuccess).toList().reversed.toList();

  bool get hasRunning => _jobs.any((j) => j.isRunning);
  int get runningCount => _jobs.where((j) => j.isRunning).length;

  /// Looks up a job by id (used when re-opening a card).
  OcrJob? byId(String id) {
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// Kicks off a new OCR job and tracks it. Returns the [OcrJob] so the
  /// caller (OcrConfirmScreen) can pass it directly to [OcrLoadingScreen].
  /// 1장 이상의 이미지를 한 번의 요청으로 묶어 분석합니다.
  OcrJob start(List<Uint8List> bytesList) {
    assert(bytesList.isNotEmpty, 'OcrJob needs at least one image');
    final job = OcrJob(
      id: 'job-${DateTime.now().microsecondsSinceEpoch}',
      imagesBytes: List.unmodifiable(bytesList),
      startedAt: DateTime.now(),
      future: OcrJobRunner.run(bytesList),
    );
    _jobs.add(job);
    notifyListeners();

    job.future.then(
      (res) {
        job.result = res;
        notifyListeners();
        // Backend created a notification on completion → refresh badge.
        // ignore: unawaited_futures
        NotificationsStore.I.refresh();
      },
      onError: (Object e, StackTrace _) {
        job.error = e;
        notifyListeners();
      },
    );

    return job;
  }

  /// Removes a job from the list (e.g. user dismissed a completed card).
  void remove(String jobId) {
    _jobs.removeWhere((j) => j.id == jobId);
    notifyListeners();
  }

  void clearCompleted() {
    _jobs.removeWhere((j) => j.isDone);
    notifyListeners();
  }

  /// 모든 job 제거 — 계정 전환/로그아웃 시 호출.
  void reset() {
    _jobs.clear();
    notifyListeners();
  }
}
