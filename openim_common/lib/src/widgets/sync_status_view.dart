import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class SyncStatusView extends StatelessWidget {
  const SyncStatusView({
    Key? key,
    required this.isFailed,
    required this.statusStr,
  }) : super(key: key);
  final bool isFailed;
  final String statusStr;

  bool get _isFailureStatus =>
      isFailed ||
      statusStr == StrRes.connectionFailed ||
      statusStr == StrRes.syncFailed;

  bool get _isConnecting => statusStr == StrRes.connecting;

  bool get _isSynchronizing => statusStr == StrRes.synchronizing;

  Color get _statusColor {
    if (_isFailureStatus) {
      return Styles.c_FF381F;
    }
    if (_isConnecting) {
      return Styles.c_FFB300;
    }
    return Styles.c_0089FF;
  }

  @override
  Widget build(BuildContext context) {
    Logger.print('Sync Status View: $isFailed, $statusStr');
    final bgColor = _statusColor.withValues(alpha: .12);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isFailureStatus
              ? (ImageRes.syncFailed.toImage
                ..width = 12.w
                ..height = 12.h)
              : SizedBox(
                  width: 12.w,
                  height: 12.h,
                  child: CupertinoActivityIndicator(
                    color: _statusColor,
                    radius: 6.r,
                  ),
                ),
          4.horizontalSpace,
          statusStr.toText
            ..style = TextStyle(
              color: _statusColor,
              fontSize: 12.sp,
            ),
        ],
      ),
    );
  }
}
