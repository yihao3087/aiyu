import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatCallItemView extends StatelessWidget {
  const ChatCallItemView({
    Key? key,
    required this.type,
    required this.content,
    required this.isISend,
    this.onTap,
  }) : super(key: key);

  final String content;
  final String type;
  final bool isISend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              (type == 'audio' ? ImageRes.voiceCallMsg : ImageRes.videoCallMsg).toImage
                ..width = 18.w
                ..height = 18.h
                ..color = isISend ? Styles.c_chatBubbleText : Styles.c_0C1C33,
              8.horizontalSpace,
              Flexible(
                child: Text(
                  content,
                  style: isISend
                      ? Styles.chatSendTextStyle(17)
                      : Styles.ts_0C1C33_17sp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
