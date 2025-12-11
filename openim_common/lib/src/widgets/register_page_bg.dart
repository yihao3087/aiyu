import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class RegisterBgView extends StatelessWidget {
  const RegisterBgView({
    Key? key,
    required this.child,
    this.alignment = Alignment.center,
    this.initialSpacing = 54,
    this.topSpacing = 38,
  }) : super(key: key);
  final Widget child;
  final Alignment alignment;
  final double initialSpacing;
  final double topSpacing;

  @override
  Widget build(BuildContext context) => Material(
        child: TouchCloseSoftKeyboard(
          isGradientBg: true,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: initialSpacing.h),
                Padding(
                  padding: EdgeInsets.only(left: 22.w),
                  child: ImageRes.backBlack.toImage
                    ..width = 24.w
                    ..height = 24.h
                    ..onTap = () => Get.back(),
                ),
                38.verticalSpace,
                SizedBox(height: topSpacing.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Align(
                    alignment: alignment,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
