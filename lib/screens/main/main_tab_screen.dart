import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../data/analysis_jobs_store.dart';
import '../../data/notifications_store.dart';
import '../analyses/analyses_screen.dart';
import '../home/home_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../mypage/mypage_screen.dart';
import '../scan/widgets/image_source_sheet.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    HomeScreen(),
    ChatbotScreen(),
    AnalysesScreen(),
    MyPageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Pull the badge count on mount; the store will also refresh after each
    // OCR job completion via OcrJobRunner.
    NotificationsStore.I.refresh();
  }

  Future<void> _showCameraMenu() async {
    // Capture the Navigator now — async gaps below may invalidate `context`.
    final navigator = Navigator.of(context);
    final source = await showGeneralDialog<ImageSource>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'camera_menu',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, _) {
        return FadeTransition(
          opacity: animation,
          child: Stack(
            children: const [
              Positioned(
                left: 180,
                right: 40,
                bottom: 104,
                child: Material(
                  color: Colors.transparent,
                  child: ImageSourceSheet(),
                ),
              ),
            ],
          ),
        );
      },
    );
    // ImageSourceSheet pops with the chosen source — the previous version
    // never read it, so the picker never ran. Hand it off now.
    if (source == null) return;
    if (!navigator.mounted) return;
    pickImageForOcr(navigator.context, source);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6FA),
            borderRadius: BorderRadius.circular(24),
          ),
          // 5개 슬롯을 Expanded로 균등 분할 — 각 아이템 크기가 달라도
          // 슬롯 폭이 같아서 시각적으로 한쪽으로 쏠리지 않는다.
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  selected: selectedIndex == 0,
                  onTap: () => setState(() => selectedIndex = 0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.chat_bubble_outline,
                  selected: selectedIndex == 1,
                  onTap: () => setState(() => selectedIndex = 1),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _showCameraMenu,
                  behavior: HitTestBehavior.opaque,
                  child: const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Color(0xFF5A3EA6),
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _AnalysesNavItem(
                  selected: selectedIndex == 2,
                  onTap: () {
                    setState(() => selectedIndex = 2);
                    // 분석 탭 진입 = 알림 확인 → 뱃지 클리어.
                    if (NotificationsStore.I.hasUnread) {
                      NotificationsStore.I.markAllRead();
                    }
                  },
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  selected: selectedIndex == 3,
                  onTap: () => setState(() => selectedIndex = 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4번째 탭(분석) 아이콘. 진행 중인 OCR job이 있으면 "분석 중" pill을,
/// 읽지 않은 알림이 있으면 카톡 스타일 빨간 점을 함께 표시합니다.
class _AnalysesNavItem extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AnalysesNavItem({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          width: 56,
          height: 52,
          child: AnimatedBuilder(
          animation: Listenable.merge([
            AnalysisJobsStore.I,
            NotificationsStore.I,
          ]),
          builder: (context, _) {
            final jobs = AnalysisJobsStore.I;
            final notif = NotificationsStore.I;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 26,
                  color: selected ? AppColors.primary : AppColors.textMain,
                ),
                if (jobs.hasRunning)
                  Positioned(
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        '분석 중',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  )
                else if (notif.hasUnread)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          notif.unreadCount > 99 ? '99+' : '${notif.unreadCount}',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Icon(
          icon,
          size: 26,
          color: selected ? AppColors.primary : AppColors.textMain,
        ),
      ),
    );
  }
}