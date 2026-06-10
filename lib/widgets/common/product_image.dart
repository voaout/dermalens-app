import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Loads a product image from a URL with a graceful placeholder/loader.
/// Falls back to a soft icon when the URL is empty or fails to load.
class ProductImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final double borderRadius;
  final double iconSize;

  const ProductImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.borderRadius = 14,
    this.iconSize = 28,
  });

  // Many product images (e.g. Naver CDN) don't send CORS headers, so they
  // can't be drawn on Flutter Web. Route through a CORS-enabling image proxy
  // on web only; native platforms use the original URL directly.
  String _resolved(String u) {
    if (kIsWeb) {
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(u)}';
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget placeholder() => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: radius,
          ),
          child: Icon(Icons.spa_outlined,
              color: AppColors.primary, size: iconSize),
        );

    if (url == null || url!.isEmpty) return placeholder();

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        color: Colors.white,
        // BoxFit.contain shows the whole image (no cropping); the white
        // background fills the letterbox area around it.
        child: Image.network(
          _resolved(url!),
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: width,
              height: height,
              alignment: Alignment.center,
              color: AppColors.primaryLight,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}
