import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';
import 'package:video_player/video_player.dart';

class ChatVideoView extends StatefulWidget {
  const ChatVideoView({
    super.key,
    required this.message,
    required this.isISend,
  });

  final Message message;
  final bool isISend;

  @override
  State<ChatVideoView> createState() => _ChatVideoViewState();
}

class _ChatVideoViewState extends State<ChatVideoView> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _hasError = false;

  VideoElem get _videoElem => widget.message.videoElem!;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  Future<void> _setupController() async {
    try {
      final path = _videoElem.videoPath;
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        _controller = VideoPlayerController.file(File(path));
      } else {
        final resolvedUrl = IMUtils.resolveMediaUrl(_videoElem.videoUrl);
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          _controller =
              VideoPlayerController.networkUrl(Uri.parse(resolvedUrl));
        }
      }

      if (_controller == null) {
        setState(() => _hasError = true);
        return;
      }

      await _controller!.initialize();
      _controller!
        ..setLooping(true)
        ..setVolume(widget.isISend ? 1 : 1);
      setState(() => _initializing = false);
    } catch (e, s) {
      Logger.print('video init error: $e $s');
      setState(() {
        _hasError = true;
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  double get _aspectRatio {
    final snapshotWidth = _videoElem.snapshotWidth?.toDouble();
    final snapshotHeight = _videoElem.snapshotHeight?.toDouble();
    if (snapshotWidth != null &&
        snapshotHeight != null &&
        snapshotWidth > 0 &&
        snapshotHeight > 0) {
      return snapshotWidth / snapshotHeight;
    }
    if (_controller?.value.isInitialized == true) {
      return _controller!.value.aspectRatio;
    }
    return 16 / 9;
  }

  Widget _buildThumbnail() {
    final resolvedVideoUrl = IMUtils.resolveMediaUrl(_videoElem.videoUrl);
    final snapshotUrl = IMUtils.resolveThumbnailUrl(
      _videoElem.snapshotUrl,
      fallback: resolvedVideoUrl,
    );
    final snapshotPath = _videoElem.snapshotPath;
    Widget image;
    if (snapshotPath != null &&
        snapshotPath.isNotEmpty &&
        File(snapshotPath).existsSync()) {
      image = ImageUtil.fileImage(file: File(snapshotPath), fit: BoxFit.cover);
    } else if (snapshotUrl != null && snapshotUrl.isNotEmpty) {
      image = ImageUtil.networkImage(
          url: snapshotUrl,
          fit: BoxFit.cover,
          height: double.infinity,
          width: double.infinity);
    } else {
      image = Container(color: Colors.black38);
    }

    final duration = _videoElem.duration ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: image),
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
              IMUtils.seconds2HMS(duration),
              style: widget.isISend
                  ? Styles.chatSendTextStyle(12)
                  : Styles.ts_FFFFFF_12sp,
            ),
          ),
        ),
      ],
    );
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio;
    final maxWidth = pictureWidth;
    double width = maxWidth;
    double height = width / ratio;
    if (height > maxWidth * 1.5) {
      height = maxWidth * 1.5;
    }

    Widget body;
    if (_hasError) {
      body = Container(
        width: width,
        height: height,
        color: Colors.black26,
        alignment: Alignment.center,
        child: Icon(Icons.error, color: Colors.white, size: 32.w),
      );
    } else if (_initializing) {
      body = Container(
        width: width,
        height: height,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    } else {
      body = GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: borderRadius(widget.isISend),
              child: SizedBox(
                width: width,
                height: height,
                child: VideoPlayer(_controller!),
              ),
            ),
            if (!_controller!.value.isPlaying)
              ImageRes.progressPlay.toImage
                ..width = 36.w
                ..height = 36.w,
          ],
        ),
      );
    }

    if (_initializing || _hasError) {
      return ClipRRect(
        borderRadius: borderRadius(widget.isISend),
        child: SizedBox(width: width, height: height, child: _buildThumbnail()),
      );
    }
    return body;
  }
}
