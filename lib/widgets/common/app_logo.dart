import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../screens/main/main_tab_screen.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;

  /// Whether tapping the logo navigates home. Disabled on the auth screens
  /// (login / register / profile setup) where there's no home yet.
  final bool goHomeOnTap;

  const AppLogo({
    super.key,
    this.fontSize = 28,
    this.goHomeOnTap = true,
  });

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainTabScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: AppColors.primary,
      letterSpacing: -1,
      height: 1,
      shadows: [
        Shadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

    return GestureDetector(
      onTap: goHomeOnTap ? () => _goHome(context) : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              SizedBox.shrink(child: _BackdropGlass(size: fontSize + 8)),
              Text('D', style: textStyle),
            ],
          ),
          Text('Lens', style: textStyle),
        ],
      ),
    );
  }
}

class _BackdropGlass extends StatelessWidget {
  final double size;

  const _BackdropGlass({required this.size});

  @override
  Widget build(BuildContext context) {
    final scale = size / 44.0;
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
              width: 1.2 * scale,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14 * scale,
                offset: Offset(0, 5 * scale),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 18 * scale,
                offset: Offset(0, 3 * scale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
