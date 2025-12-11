import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatVoiceRecordResult {
  ChatVoiceRecordResult({required this.duration, required this.path});
  final int duration;
  final String path;
}

class ChatVoiceRecordBar extends StatefulWidget {
  const ChatVoiceRecordBar({
    super.key,
    required this.onSend,
    this.maxRecordSeconds = 60,
    this.onAmplitude,
  });

  final ValueChanged<ChatVoiceRecordResult> onSend;
  final int maxRecordSeconds;
  final ValueChanged<double>? onAmplitude;

  @override
  State<ChatVoiceRecordBar> createState() => _ChatVoiceRecordBarState();
}

class _ChatVoiceRecordBarState extends State<ChatVoiceRecordBar> {
  late final VoiceRecord _recorder;
  bool _isRecording = false;
  bool _willCancel = false;
  int _duration = 0;
  OverlayEntry? _overlayEntry;
  double _amplitude = 0;

  @override
  void initState() {
    _recorder = VoiceRecord(
      maxRecordSec: widget.maxRecordSeconds,
      onFinished: _handleFinish,
      onInterrupt: _handleInterrupt,
      onDuration: (sec) {
        setState(() {
          _duration = sec;
        });
      },
      onAmplitude: (level) {
        if (!mounted) return;
        setState(() {
          _amplitude = level;
        });
        widget.onAmplitude?.call(level);
        _overlayEntry?.markNeedsBuild();
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    _removeOverlay();
    _recorder.stop(isInterrupt: true);
    super.dispose();
  }

  void _handleFinish(int sec, String path) {
    _removeOverlay();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _willCancel = false;
      _amplitude = 0;
    });
    if (sec <= 0) {
      IMViews.showToast(
        StrRes.talkTooShort,
        allowUserInteraction: true,
      );
      return;
    }
    widget.onSend(ChatVoiceRecordResult(duration: sec, path: path));
  }

  void _handleInterrupt(int sec, String path) {
    _removeOverlay();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _willCancel = false;
      _amplitude = 0;
    });
    if (sec >= widget.maxRecordSeconds) {
      IMViews.showToast(StrRes.releaseToSend);
    }
  }

  void _onLongPressStart(LongPressStartDetails details) async {
    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = true;
      _willCancel = false;
      _duration = 0;
      _amplitude = 0;
    });
    _showOverlay(context);
    await _recorder.start();
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    final shouldCancel = details.localOffsetFromOrigin.dy < -60.h;
    if (shouldCancel != _willCancel) {
      setState(() {
        _willCancel = shouldCancel;
      });
      _updateOverlay();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) async {
    final cancelByDuration = _duration < 1;
    final cancel = _willCancel || cancelByDuration;
    if (cancelByDuration) {
      IMViews.showToast(
        StrRes.talkTooShort,
        allowUserInteraction: true,
      );
    }
    await _recorder.stop(isInterrupt: cancel);
    _removeOverlay();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _willCancel = false;
        _amplitude = 0;
      });
    }
  }

  void _showOverlay(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: 150.h,
        left: 32.w,
        right: 32.w,
        child: _RecordTips(
          willCancel: _willCancel,
          duration: _duration,
          maxRecordSeconds: widget.maxRecordSeconds,
          level: _amplitude,
        ),
      ),
    );
    Overlay.of(context, debugRequiredFor: widget)?.insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final text = !_isRecording
        ? StrRes.holdTalk
        : (_willCancel
              ? StrRes.liftFingerToCancelSend
              : StrRes.releaseToSendSwipeUpToCancel);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      alignment: Alignment.center,
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 200),
                ),
                (instance) {
                  instance
                    ..onLongPressStart = _onLongPressStart
                    ..onLongPressMoveUpdate = _onLongPressMove
                    ..onLongPressEnd = _onLongPressEnd;
                },
              ),
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isRecording ? Styles.c_FF381F_opacity10 : Styles.c_F0F2F6,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: _isRecording ? Styles.c_FF381F : Styles.c_E8EAEF,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 22.w,
                    height: 22.h,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            (_isRecording ? Styles.c_0089FF : Styles.c_8E9AB0)
                                .withValues(
                                  alpha: 0.15 + _amplitude * 0.35,
                                ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.mic,
                    size: 20,
                    color: _isRecording ? Styles.c_0089FF : Styles.c_0C1C33,
                  ),
                ],
              ),
              8.horizontalSpace,
              Flexible(
                child: Text(
                  text,
                  style: Styles.ts_0C1C33_17sp.copyWith(
                    fontSize: 16.sp,
                    color: _isRecording ? Styles.c_FF381F : Styles.c_0C1C33,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isRecording) ...[
                12.horizontalSpace,
                SizedBox(
                  height: 24.h,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(4, (index) {
                      final factor = 0.4 + index * 0.2;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          width: 4.w,
                          height: (10 + (_amplitude.clamp(0, 1) * 24 * factor))
                              .clamp(10, 34)
                              .h,
                          decoration: BoxDecoration(
                            color: Styles.c_0089FF,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTips extends StatelessWidget {
  const _RecordTips({
    required this.willCancel,
    required this.duration,
    required this.maxRecordSeconds,
    required this.level,
  });

  final bool willCancel;
  final int duration;
  final int maxRecordSeconds;
  final double level;

  @override
  Widget build(BuildContext context) {
    final remain = maxRecordSeconds - duration;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: willCancel
              ? Styles.c_FF381F
              : Colors.black.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              willCancel ? Icons.delete_outline : Icons.mic,
              color: Colors.white,
              size: 32.sp,
            ),
            if (!willCancel) ...[
              12.verticalSpace,
              SizedBox(
                width: 100.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    minHeight: 6.h,
                    value: level.clamp(0, 1),
                    backgroundColor: Colors.white24,
                    color: Styles.c_FFFFFF,
                  ),
                ),
              ),
            ],
            12.verticalSpace,
            Text(
              willCancel
                  ? StrRes.liftFingerToCancelSend
                  : StrRes.releaseToSendSwipeUpToCancel,
              style: Styles.ts_FFFFFF_14sp,
            ),
            if (!willCancel && remain <= 10)
              Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Text('$remain s', style: Styles.ts_FFFFFF_12sp),
              ),
          ],
        ),
      ),
    );
  }
}
