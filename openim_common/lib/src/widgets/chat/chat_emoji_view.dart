import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChatEmojiView extends StatelessWidget {
  const ChatEmojiView({
    super.key,
    required this.url,
    this.width,
    this.height,
  });

  final String url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: ExtendedImage.network(
        url,
        width: width ?? 120.w,
        height: height ?? 120.w,
        fit: BoxFit.cover,
        handleLoadingProgress: true,
      ),
    );
  }
}
