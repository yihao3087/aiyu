import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

enum BubbleType {
  send,
  receiver,
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    Key? key,
    this.margin,
    this.constraints,
    this.alignment = Alignment.center,
    this.backgroundColor,
    this.child,
    required this.bubbleType,
  }) : super(key: key);
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment;
  final Color? backgroundColor;
  final Widget? child;
  final BubbleType bubbleType;

  bool get isISend => bubbleType == BubbleType.send;

  @override
  Widget build(BuildContext context) => Container(
        constraints: constraints,
        margin: margin,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        alignment: alignment,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isISend ? Styles.c_chatBubbleSend : Styles.c_FFFFFF),
          borderRadius: borderRadius(isISend),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: isISend ? 0.14 : 0.08),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
        child: child,
      );
}
