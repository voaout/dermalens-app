#!/bin/bash

# ============================================================
# Vercel용 Flutter Web 빌드 스크립트
# ------------------------------------------------------------
# Vercel은 Flutter를 기본 지원하지 않으므로, 빌드 단계에서
# Flutter SDK를 직접 받아와서 web 번들을 만든다.
#
# 진행 순서:
#   1) Flutter SDK clone (stable 채널)
#   2) Web 활성화
#   3) 의존성 설치 (pub get)
#   4) flutter build web --release  → build/web 출력
#
# Vercel은 build/web을 정적 호스팅으로 서빙.
# ============================================================

set -e  # 어느 한 단계라도 실패하면 즉시 중단

echo "▶ Flutter SDK clone (stable channel)"
git clone --depth=1 -b stable https://github.com/flutter/flutter.git _flutter

export PATH="$PWD/_flutter/bin:$PATH"

echo "▶ Flutter version"
flutter --version

echo "▶ Web 지원 활성화"
flutter config --enable-web

echo "▶ pub get"
flutter pub get

echo "▶ Web 빌드 (release)"
# 배포에서도 API 베이스 URL은 lib/core/network/api.dart 기본값(Railway)을 사용.
# 다른 URL로 띄우려면 --dart-define=API_BASE_URL=... 추가.
flutter build web --release

echo "✅ Build 완료 — build/web에 정적 자산이 생성됐습니다."
