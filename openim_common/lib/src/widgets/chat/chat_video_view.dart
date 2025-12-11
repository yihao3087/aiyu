import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatVideoView extends StatefulWidget {
  const ChatVideoView({
    super.key,
    required this.message,
    required this.isISend,
    this.maxWidth,
    this.onTap,
  });

  final Message message;
  final bool isISend;
  final double? maxWidth;
  final VoidCallback? onTap;

  @override
  State<ChatVideoView> createState() => _ChatVideoViewState();
}

class _ChatVideoViewState extends State<ChatVideoView> {
  late double _width;
  late double _height;
  File? _snapshotFile;
  String? _snapshotUrl;
  late int _duration;

  VideoElem get _videoElem => widget.message.videoElem!;

  @override
  void initState() {
    super.initState();
    _initLayout();
  }

  void _initLayout() {
    final maxWidth = widget.maxWidth ?? 120.w;
    final snapshotWidth = _videoElem.snapshotWidth?.toDouble();
    final snapshotHeight = _videoElem.snapshotHeight?.toDouble();
    final ratio = snapshotWidth != null && snapshotHeight != null && snapshotWidth > 0 && snapshotHeight > 0
        ? snapshotWidth / snapshotHeight
        : 16 / 9;
    _width = maxWidth;
    _height = _width / ratio;
    final maxHeight = maxWidth * 1.5;
    if (_height > maxHeight) {
      _height = maxHeight;
    }

    final path = _videoElem.snapshotPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      _snapshotFile = File(path);
    }
    final resolvedVideoUrl = IMUtils.resolveMediaUrl(_videoElem.videoUrl);
    _snapshotUrl = IMUtils.resolveThumbnailUrl(
      _videoElem.snapshotUrl,
      fallback: resolvedVideoUrl,
    );
    _duration = _videoElem.duration ?? 0;
  }

  @override
  void didUpdateWidget(covariant ChatVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.clientMsgID != widget.message.clientMsgID) {
      _snapshotFile = null;
      _snapshotUrl = null;
      _initLayout();
    }
  }

  void _openFullScreen() {
    IMUtils.previewMediaFile(
      context: context,
      message: widget.message,
      onAutoPlay: (_) => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = _bubbleBorderRadius(widget.isISend);
    Widget imageChild;
    if (_snapshotFile != null) {
      imageChild = ImageUtil.fileImage(
        file: _snapshotFile!,
        width: _width,
        height: _height,
        fit: BoxFit.cover,
      );
    } else if (_snapshotUrl != null && _snapshotUrl!.isNotEmpty) {
      imageChild = ImageUtil.networkImage(
        url: _snapshotUrl!,
        width: _width,
        height: _height,
        fit: BoxFit.cover,
      );
    } else {
      imageChild = Container(
        width: _width,
        height: _height,
        color: Colors.black26,
        alignment: Alignment.center,
        child: Icon(Icons.videocam, color: Colors.white70, size: 28.w),
      );
    }

    return GestureDetector(
      onTap: widget.onTap ?? _openFullScreen,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: imageChild),
              Container(
                width: _width,
                height: _height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
              ImageRes.progressPlay.toImage
                ..width = 36.w
                ..height = 36.w,
              Positioned(
                right: 8.w,
                bottom: 6.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                    child: Text(
                      IMUtils.seconds2HMS(_duration),
                      style: widget.isISend
                          ? Styles.chatSendTextStyle(12)
                          : Styles.ts_FFFFFF_12sp,
                    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius _bubbleBorderRadius(bool isSender) => BorderRadius.only(
        topLeft: Radius.circular(isSender ? 6.r : 0),
        topRight: Radius.circular(isSender ? 0 : 6.r),
        bottomLeft: Radius.circular(6.r),
        bottomRight: Radius.circular(6.r),
      );
}
