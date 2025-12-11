import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../extension/custom_ext.dart';
import '../../res/styles.dart';

class MessageAction {
  final String icon;
  final String label;
  final VoidCallback onTap;

  MessageAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class MessageActionBar extends StatefulWidget {
  const MessageActionBar({
    super.key,
    required this.actions,
    required this.anchorX,
    required this.showAbove,
    required this.anchorRect,
    this.onDismiss,
  });

  final List<MessageAction> actions;
  final double anchorX;
  final bool showAbove;
  final Rect anchorRect;
  final VoidCallback? onDismiss;

  static const double barHeight = 62.0;
  static const double itemWidth = 58.0;
  static const double itemSpacing = 10.0;
  static const double verticalGap = 12.0;
  static const double pointerHeight = 8.0;
  static const double pointerWidth = 18.0;

  @override
  State<MessageActionBar> createState() => _MessageActionBarState();
}

class _MessageActionBarState extends State<MessageActionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  OverlayEntry? _dismissOverlay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.94,
      upperBound: 1.0,
    )..forward();
  }

  @override
  void dispose() {
    _dismissOverlay?.remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) {
      return const SizedBox.shrink();
    }
    final barWidth = _calcBarWidth(widget.actions);
    if (barWidth <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (_, constraints) {
        final maxWidth = constraints.maxWidth;
        final minLeft = 12.0.w;
        final available = maxWidth - barWidth - 12.0.w;
        final maxLeft = available > minLeft ? available : minLeft;
        double left = widget.anchorX - barWidth / 2;
        final bool preferRightSide =
            widget.anchorRect.center.dx >= maxWidth / 2;
        if (preferRightSide) {
          left = widget.anchorRect.right - barWidth;
        } else {
          left = widget.anchorRect.left;
        }
        if (maxLeft <= minLeft) {
          left = minLeft;
        } else {
          left = left.clamp(minLeft, maxLeft);
        }
        final pointerWidth = MessageActionBar.pointerWidth.w;
        final pointerPadding = pointerWidth / 2 + 12.w;
        final pointerOffset =
            (widget.anchorX - left).clamp(pointerPadding, barWidth - pointerPadding);
        final topOffset = widget.showAbove ? 0.0 : 4.0.h;

        final totalHeight =
            (MessageActionBar.barHeight + MessageActionBar.pointerHeight + 8).h;
        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: topOffset,
                child: FadeTransition(
                  opacity: _controller,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: _controller,
                      curve: Curves.fastOutSlowIn,
                    )),
                    child: _ActionRow(
                      actions: widget.actions,
                      showAbove: widget.showAbove,
                      barWidth: barWidth,
                      pointerOffset: pointerOffset,
                      onDismiss: widget.onDismiss,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _calcBarWidth(List<MessageAction> actions) {
    if (actions.isEmpty) return 0;
    final itemWidth = MessageActionBar.itemWidth.w;
    final spacing = MessageActionBar.itemSpacing.w;
    return actions.length * itemWidth + (actions.length - 1) * spacing;
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.actions,
    required this.showAbove,
    required this.barWidth,
    required this.pointerOffset,
    this.onDismiss,
  });

  final List<MessageAction> actions;
  final bool showAbove;
  final double barWidth;
  final double pointerOffset;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    const bubbleColor = Color(0xF21A1A1A);
    final pointerAlign = (pointerOffset / barWidth).clamp(0.0, 1.0) * 2 - 1;
    final bubble = Container(
      width: barWidth,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _buildItems(),
      ),
    );
    final pointer = Align(
      alignment: Alignment(pointerAlign, 0),
      child: _Pointer(color: bubbleColor, pointDown: showAbove),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: showAbove ? [bubble, pointer] : [pointer, bubble],
    );
  }

  List<Widget> _buildItems() {
    final widgets = <Widget>[];
    for (final action in actions) {
      if (widgets.isNotEmpty) {
        widgets.add(SizedBox(width: MessageActionBar.itemSpacing.w));
      }
      widgets.add(_ActionButton(action: action, onDismiss: onDismiss));
    }
    return widgets;
  }
}

class _Pointer extends StatelessWidget {
  const _Pointer({required this.color, required this.pointDown});

  final Color color;
  final bool pointDown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MessageActionBar.pointerWidth.w,
      height: MessageActionBar.pointerHeight.h,
      child: CustomPaint(
        painter: _PointerPainter(color: color, pointDown: pointDown),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  _PointerPainter({required this.color, required this.pointDown});

  final Color color;
  final bool pointDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointDown) {
      path.moveTo(size.width / 2, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    }
    path.close();
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointDown != pointDown;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, this.onDismiss});

  final MessageAction action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () {
          action.onTap();
          onDismiss?.call();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: _buildIcon(),
              ),
              4.verticalSpace,
              Text(
                action.label,
                style: Styles.ts_FFFFFF_12sp.copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final imageView = action.icon.toImage
      ..width = 16.w
      ..height = 16.h
      ..color = Styles.c_FFFFFF;
    return imageView;
  }
}
