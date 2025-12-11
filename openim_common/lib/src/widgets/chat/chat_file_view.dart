import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:openim_common/openim_common.dart';

class ChatFileView extends StatelessWidget {
  const ChatFileView({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.onTap,
  });

  final String fileName;
  final int fileSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconByExt(fileName);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Container(
        width: 220.w,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Styles.c_FFFFFF,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Styles.c_E8EAEF),
        ),
        child: Row(
          children: [
            icon.toImage
              ..width = 42.w
              ..height = 42.h,
            12.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: Styles.ts_0C1C33_17sp,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  6.verticalSpace,
                  Text(
                    IMUtils.formatBytes(fileSize),
                    style: Styles.ts_8E9AB0_12sp,
                  ),
                ],
              ),
            ),
            12.horizontalSpace,
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _iconByExt(String name) {
    final segments = name.split('.');
    final ext = segments.length > 1 ? segments.last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return ImageRes.filePdf;
      case 'ppt':
      case 'pptx':
        return ImageRes.filePpt;
      case 'xls':
      case 'xlsx':
        return ImageRes.fileExcel;
      case 'doc':
      case 'docx':
        return ImageRes.fileWord;
      case 'zip':
      case 'rar':
      case '7z':
        return ImageRes.fileZip;
      default:
        return ImageRes.fileUnknown;
    }
  }
}
