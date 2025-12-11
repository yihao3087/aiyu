import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatVoiceView extends StatelessWidget {
  const ChatVoiceView({
    super.key,
    required this.duration,
    required this.isISend,
    required this.isPlaying,
    this.progress = 0.0,
    this.onTap,
    this.onSeek,
  });

  final int duration;
  final bool isISend;
  final bool isPlaying;
  final double progress;
  final VoidCallback? onTap;
  final ValueChanged<double>? onSeek;

  Color get _primaryColor =>
      isISend ? Styles.c_FFFFFF : Styles.c_0C1C33;
  Color get _secondaryColor =>
      isISend ? Styles.c_FFFFFF : Styles.c_8E9AB0;

  List<Color> get _gradientColors => isISend
      ? [Styles.c_000000, Styles.c_000000]
      : [const Color(0xFFF8F9FC), const Color(0xFFE6EBF4)];

  @override
  Widget build(BuildContext context) {
    final limitedDuration = min(duration, 60);
    final rawWidth = 140.w + limitedDuration * 1.2.w;
    final width = rawWidth.clamp(160.w, 260.w).toDouble();
    final elapsed = (duration * progress).round();
    final remaining = max(duration - elapsed, 0);

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: (isISend ? Styles.c_000000 : Styles.c_0C1C33)
                .withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlayButton(
            isPlaying: isPlaying,
            foregroundColor: _primaryColor,
            backgroundColor: isISend
                ? Colors.white.withValues(alpha: 0.15)
                : _secondaryColor.withValues(alpha: 0.15),
            onTap: onTap,
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Waveform(
                  progress: progress,
                  activeColor: _primaryColor,
                  inactiveColor:
                      (isISend ? Colors.white70 : Styles.c_8E9AB0_opacity30),
                  duration: duration,
                  onSeek: onSeek,
                ),
                6.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(elapsed),
                      style: TextStyle(
                        color: _primaryColor.withValues(alpha: 0.85),
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      '-${_formatTime(remaining)}',
                      style: TextStyle(
                        color: _secondaryColor.withValues(alpha: 0.85),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.foregroundColor,
    required this.backgroundColor,
    this.onTap,
  });

  final bool isPlaying;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: foregroundColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: foregroundColor,
          size: 22.sp,
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.duration,
    this.onSeek,
  });

  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int duration;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final seed = max(duration, 1);
    final samples = List<double>.generate(
      28,
      (index) => 0.35 + (Random(seed + index).nextDouble() * 0.65),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      void handleSeek(double dx) {
        if (onSeek == null || width <= 0) return;
        onSeek!.call((dx / width).clamp(0.0, 1.0));
      }
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) => handleSeek(details.localPosition.dx),
        onHorizontalDragUpdate: (details) =>
            handleSeek(details.localPosition.dx),
        child: SizedBox(
          height: 24.h,
          child: CustomPaint(
            painter: _WaveformPainter(
              samples: samples,
              progress: progress.clamp(0.0, 1.0),
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
          ),
        ),
      );
    });
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (samples.length * 1.5);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final activeCount = (samples.length * progress).ceil();
    for (var i = 0; i < samples.length; i++) {
      final x = (barWidth * 1.5) * i + barWidth / 2;
      final barHeight = samples[i] * size.height;
      paint.color = i <= activeCount ? activeColor : inactiveColor;
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2),
        Offset(x, (size.height + barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.samples != samples;
  }
}
