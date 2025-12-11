import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:focus_detector_v2/focus_detector_v2.dart';
import 'package:openim_common/openim_common.dart';
import 'package:rxdart/rxdart.dart';

import 'chat_file_view.dart';
import 'chat_location_view.dart';
import 'chat_notice_view.dart';
import 'chat_voice_view.dart';
import 'chat_emoji_view.dart';
import 'chat_video_view.dart';

double maxWidth = 247.w;
double pictureWidth = 120.w;
double videoWidth = 120.w;
double locationWidth = 220.w;

BorderRadius borderRadius(bool isISend) => BorderRadius.only(
      topLeft: Radius.circular(isISend ? 6.r : 0),
      topRight: Radius.circular(isISend ? 0 : 6.r),
      bottomLeft: Radius.circular(6.r),
      bottomRight: Radius.circular(6.r),
    );

class MsgStreamEv<T> {
  final String id;
  final T value;

  MsgStreamEv({required this.id, required this.value});

  @override
  String toString() {
    return 'MsgStreamEv{msgId: $id, value: $value}';
  }
}

class CustomTypeInfo {
  final Widget customView;
  final bool needBubbleBackground;
  final bool needChatItemContainer;

  CustomTypeInfo(
    this.customView, [
    this.needBubbleBackground = true,
    this.needChatItemContainer = true,
  ]);
}

typedef CustomTypeBuilder = CustomTypeInfo? Function(
  BuildContext context,
  Message message,
);
typedef NotificationTypeBuilder = Widget? Function(
  BuildContext context,
  Message message,
);
typedef ItemViewBuilder = Widget? Function(
  BuildContext context,
  Message message,
);
typedef ItemVisibilityChange = void Function(
  Message message,
  bool visible,
);

class ChatItemView extends StatefulWidget {
  const ChatItemView({
    Key? key,
    this.mediaItemBuilder,
    this.itemViewBuilder,
    this.customTypeBuilder,
    this.notificationTypeBuilder,
    this.sendStatusSubject,
    this.visibilityChange,
    this.timelineStr,
    this.leftNickname,
    this.leftFaceUrl,
    this.rightNickname,
    this.rightFaceUrl,
    required this.message,
    this.textScaleFactor = 1.0,
    this.ignorePointer = false,
    this.showLeftNickname = true,
    this.showRightNickname = false,
    this.highlightColor,
    this.allAtMap = const {},
    this.patterns = const [],
    this.onTapLeftAvatar,
    this.onTapRightAvatar,
    this.onLongPressRightAvatar,
    this.onVisibleTrulyText,
    this.onFailedToResend,
    this.onClickItemView,
    this.onTapQuote,
    required this.onTapUserProfile,
    this.onTapVoice,
    this.onTapFile,
    this.playingVoiceMsgId,
    this.playingVoiceProgress = 0.0,
    this.onSeekVoice,
    this.onLongPressMessage,
  }) : super(key: key);
  final ItemViewBuilder? mediaItemBuilder;
  final ItemViewBuilder? itemViewBuilder;
  final CustomTypeBuilder? customTypeBuilder;
  final NotificationTypeBuilder? notificationTypeBuilder;

  final Subject<MsgStreamEv<bool>>? sendStatusSubject;

  final ItemVisibilityChange? visibilityChange;
  final String? timelineStr;
  final String? leftNickname;
  final String? leftFaceUrl;
  final String? rightNickname;
  final String? rightFaceUrl;
  final Message message;

  final double textScaleFactor;
  final bool ignorePointer;
  final bool showLeftNickname;
  final bool showRightNickname;

  final Color? highlightColor;
  final Map<String, String> allAtMap;
  final List<MatchPattern> patterns;
  final Function()? onTapLeftAvatar;
  final Function()? onTapRightAvatar;
  final Function()? onLongPressRightAvatar;
  final Function(String? text)? onVisibleTrulyText;
  final Function()? onClickItemView;
  final void Function(Message source, QuoteElem? quoteElem)? onTapQuote;
  final ValueChanged<
          ({String userID, String name, String? faceURL, String? groupID})>
      onTapUserProfile;

  final Function()? onFailedToResend;
  final Function(Message message)? onTapVoice;
  final Function(Message message)? onTapFile;
  final String? playingVoiceMsgId;
  final double playingVoiceProgress;
  final Function(Message message, double progress)? onSeekVoice;
  final Function(Message message, Rect globalRect)? onLongPressMessage;
  @override
  State<ChatItemView> createState() => _ChatItemViewState();
}

class _ChatItemViewState extends State<ChatItemView> {
  late final GlobalKey _bubbleKey;

  @override
  void initState() {
    super.initState();
    final keyValue = widget.message.clientMsgID ?? widget.message.serverMsgID ?? UniqueKey();
    _bubbleKey = GlobalObjectKey(keyValue);
  }

  Message get _message => widget.message;

  bool get _isISend => _message.sendID == OpenIM.iMManager.userID;

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      child: Container(
        color: widget.highlightColor,
        margin: EdgeInsets.only(bottom: 20.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Center(child: _child),
      ),
      onVisibilityLost: () {
        widget.visibilityChange?.call(widget.message, false);
      },
      onVisibilityGained: () {
        widget.visibilityChange?.call(widget.message, true);
      },
    );
  }

  Widget get _child =>
      widget.itemViewBuilder?.call(context, _message) ?? _buildChildView();

  Widget _buildChildView() {
    Widget? content;
    String? senderNickname;
    String? senderFaceURL;
    bool isBubbleBg = false;
    bool needChatItemContainer = true;

    final customTypeInfo = widget.customTypeBuilder?.call(context, _message);
    if (customTypeInfo != null) {
      content = customTypeInfo.customView;
      isBubbleBg = customTypeInfo.needBubbleBackground;
      needChatItemContainer = customTypeInfo.needChatItemContainer;
    } else if (_message.isQuoteType) {
      isBubbleBg = true;
      content = ChatQuoteView(
        isISend: _isISend,
        message: _message,
        patterns: widget.patterns,
        textScaleFactor: widget.textScaleFactor,
        onVisibleTrulyText: widget.onVisibleTrulyText,
        onTap: () => widget.onTapQuote?.call(
          _message,
          _message.quoteElem,
        ),
      );
    } else if (_message.isTextType) {
      isBubbleBg = true;
      content = ChatText(
        isISend: _isISend,
        text: _message.textElem!.content!,
        patterns: widget.patterns,
        textScaleFactor: widget.textScaleFactor,
        onVisibleTrulyText: widget.onVisibleTrulyText,
      );
    } else if (_message.isPictureType) {
      content = widget.mediaItemBuilder?.call(context, _message) ??
          ChatPictureView(
            isISend: _isISend,
            message: _message,
          );
    } else if (_message.isVoiceType) {
      isBubbleBg = false;
      final duration = _message.soundElem?.duration ?? 0;
      content = ChatVoiceView(
        duration: duration,
        isISend: _isISend,
        isPlaying: widget.playingVoiceMsgId == _message.clientMsgID,
        progress: widget.playingVoiceMsgId == _message.clientMsgID
            ? widget.playingVoiceProgress
            : 0.0,
        onTap: () => widget.onTapVoice?.call(_message),
        onSeek: widget.onSeekVoice == null
            ? null
            : (value) => widget.onSeekVoice!.call(_message, value),
      );
    } else if (_message.isVideoType) {
      isBubbleBg = false;
      final customMedia = widget.mediaItemBuilder?.call(context, _message);
      if (customMedia != null) {
        content = customMedia;
      } else {
        content = ChatVideoView(
          isISend: _isISend,
          message: _message,
          maxWidth: videoWidth,
        );
      }
    } else if (_message.isFileType) {
      isBubbleBg = false;
      content = ChatFileView(
        fileName: _message.fileElem?.fileName ?? StrRes.file,
        fileSize: _message.fileElem?.fileSize ?? 0,
        onTap: () => widget.onTapFile?.call(_message),
      );
    } else if (_message.isLocationType) {
      isBubbleBg = false;
      content = ChatLocationView(
        message: _message,
        isISend: _isISend,
      );
    } else if (_message.isEmojiType) {
      isBubbleBg = false;
      final data = IMUtils.parseCustomMessage(_message);
      final url = data?['url'];
      final width = (data?['width'] as num?)?.toDouble();
      final height = (data?['height'] as num?)?.toDouble();
      if (url is String && url.isNotEmpty) {
        content = ChatEmojiView(
          url: url,
          width: width != null && width > 0 ? width.w : null,
          height: height != null && height > 0 ? height.h : null,
        );
      } else {
        content = ChatText(
          isISend: _isISend,
          text: StrRes.unsupportedMessage,
          patterns: const [],
          textScaleFactor: widget.textScaleFactor,
        );
      }
    } else if (_message.isNotificationType) {
      if (_message.contentType ==
          MessageType.groupInfoSetAnnouncementNotification) {
        final map = json.decode(_message.notificationElem!.detail!);
        final ntf = GroupNotification.fromJson(map);
        final noticeContent = ntf.group?.notification;
        senderNickname = ntf.opUser?.nickname;
        senderFaceURL = ntf.opUser?.faceURL;
        content = ChatNoticeView(isISend: _isISend, content: noticeContent!);
      } else {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ChatHintTextView(
            message: _message,
            onTapUserProfile: widget.onTapUserProfile,
          ),
        );
      }
    }

    if (!needChatItemContainer) {
      return content ?? const SizedBox.shrink();
    }

    senderNickname ??= widget.leftNickname ?? _message.senderNickname;
    senderFaceURL ??= widget.leftFaceUrl ?? _message.senderFaceUrl;
    return content = ChatItemContainer(
      id: _message.clientMsgID!,
      isISend: _isISend,
      leftNickname: senderNickname,
      leftFaceUrl: senderFaceURL,
      rightNickname: widget.rightNickname ?? OpenIM.iMManager.userInfo.nickname,
      rightFaceUrl: widget.rightFaceUrl ?? OpenIM.iMManager.userInfo.faceURL,
      showLeftNickname: widget.showLeftNickname,
      showRightNickname: widget.showRightNickname,
      timelineStr: widget.timelineStr,
      timeStr: IMUtils.getChatTimeline(_message.sendTime!, 'HH:mm:ss'),
      hasRead: _message.isRead ?? false,
      isDelivered: _message.status == MessageStatus.succeeded,
      isSending: _message.isVideoType
          ? false
          : _message.status == MessageStatus.sending,
      isSendFailed: _message.status == MessageStatus.failed,
      isBubbleBg: content == null ? true : isBubbleBg,
      ignorePointer: widget.ignorePointer,
      sendStatusStream: widget.sendStatusSubject,
      onFailedToResend: widget.onFailedToResend,
      onLongPressRightAvatar: widget.onLongPressRightAvatar,
      onTapLeftAvatar: widget.onTapLeftAvatar,
      onTapRightAvatar: widget.onTapRightAvatar,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onClickItemView,
        onLongPressStart: (details) => _handleLongPress(details),
        onLongPress: () {},
        child: Container(
          key: _bubbleKey,
          child: content ??
              ChatText(isISend: _isISend, text: StrRes.unsupportedMessage),
        ),
      ),
    );
  }

  void _handleLongPress(LongPressStartDetails details) {
    final renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    Rect rect;
    if (renderBox != null) {
      final topLeft = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
    } else {
      rect = Rect.fromLTWH(
        details.globalPosition.dx,
        details.globalPosition.dy,
        0,
        0,
      );
    }
    widget.onLongPressMessage?.call(_message, rect);
  }
}

class ChatQuoteView extends StatelessWidget {
  const ChatQuoteView({
    Key? key,
    required this.message,
    required this.isISend,
    required this.patterns,
    required this.textScaleFactor,
    this.onVisibleTrulyText,
    this.onTap,
  }) : super(key: key);

  final Message message;
  final bool isISend;
  final List<MatchPattern> patterns;
  final double textScaleFactor;
  final Function(String? text)? onVisibleTrulyText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final quoteElem = message.quoteElem;
    final quotedMessage = quoteElem?.quoteMessage;
    final replyText = quoteElem?.text ?? '';
    final summary = quotedMessage != null
        ? IMUtils.messageDigest(quotedMessage)
        : StrRes.quoteContentBeRevoked;
    final nickname = quotedMessage?.senderNickname ??
        quotedMessage?.senderFaceUrl ??
        quotedMessage?.sendID ??
        '';
    final referenceText =
        summary.isNotEmpty ? summary : StrRes.quoteContentBeRevoked;

    final mediaPreview = _buildMediaPreview(quotedMessage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: quotedMessage != null ? onTap : null,
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Styles.c_F4F5F7,
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (mediaPreview != null) ...[
                  mediaPreview,
                  8.horizontalSpace,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (nickname.isNotEmpty)
                        Text(
                          nickname,
                          style: Styles.ts_8E9AB0_12sp,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (nickname.isNotEmpty) 4.verticalSpace,
                      Text(
                        referenceText,
                        style: Styles.ts_8E9AB0_14sp,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (replyText.isNotEmpty) ...[
          6.verticalSpace,
          ChatText(
            isISend: isISend,
            text: replyText,
            patterns: patterns,
            textScaleFactor: textScaleFactor,
            onVisibleTrulyText: onVisibleTrulyText,
          ),
        ],
      ],
    );
  }

  Widget? _buildMediaPreview(Message? quotedMessage) {
    if (quotedMessage == null) return null;
    if (quotedMessage.isPictureType) {
      return _buildImagePreview(
        filePath: quotedMessage.pictureElem?.sourcePath,
        url: quotedMessage.pictureElem?.snapshotPicture?.url ??
            quotedMessage.pictureElem?.sourcePicture?.url ??
            quotedMessage.pictureElem?.bigPicture?.url,
      );
    } else if (quotedMessage.isVideoType) {
      return Stack(
        alignment: Alignment.center,
        children: [
          _buildImagePreview(
                filePath: quotedMessage.videoElem?.snapshotPath,
                url: quotedMessage.videoElem?.snapshotUrl,
              ) ??
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Styles.c_E8EAEF,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(
                  Icons.videocam,
                  size: 20.sp,
                  color: Styles.c_8E9AB0,
                ),
              ),
          Icon(
            Icons.play_circle_outline,
            color: Colors.white.withValues(alpha: 0.9),
            size: 20.sp,
          ),
        ],
      );
    }
    return null;
  }

  Widget? _buildImagePreview({String? filePath, String? url}) {
    Widget? child;
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (file.existsSync()) {
        child = Image.file(
          file,
          width: 48.w,
          height: 48.w,
          fit: BoxFit.cover,
        );
      }
    }
    if (child == null && url != null && url.isNotEmpty) {
      child = ImageUtil.networkImage(
        url: url,
        width: 48.w,
        height: 48.w,
        fit: BoxFit.cover,
      );
    }
    if (child == null) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6.r),
      child: child,
    );
  }
}
