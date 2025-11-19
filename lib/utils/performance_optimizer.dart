import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// أداة تحسين الأداء
class PerformanceOptimizer {
  /// تحسين بناء الويدجتات
  static Widget optimizedBuilder({
    required Widget Function(BuildContext) builder,
    String? key,
  }) {
    return Builder(
      key: key != null ? Key(key) : null,
      builder: builder,
    );
  }

  /// تأخير بناء الويدجتات الثقيلة حتى بعد بناء الإطار
  static void scheduleMicrotask(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      callback();
    });
  }

  /// تحسين قوائم طويلة
  static Widget optimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsets? padding,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      cacheExtent: 500, // تحسين الكاش
    );
  }

  /// تحسين GridView
  static Widget optimizedGridView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    EdgeInsets? padding,
  }) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      gridDelegate: gridDelegate,
      cacheExtent: 500,
    );
  }

  /// تحسين الصور
  static Widget optimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit? fit,
  }) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.error);
      },
    );
  }

  /// تحسين النصوص الطويلة
  static Widget optimizedText({
    required String text,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}

