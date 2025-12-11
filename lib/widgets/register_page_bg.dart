import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class RegisterBgView extends StatelessWidget {
  const RegisterBgView({
    super.key,
    required this.child,
    this.controller,
    this.alignment = Alignment.center,
    this.initialSpacing = 54,
    this.topSpacing = 38,
  });
  final Widget child;
  final ScrollController? controller;
  final Alignment alignment;
  final double initialSpacing;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/icon/splash_logo.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
          ),
          child: TouchCloseSoftKeyboard(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: initialSpacing.h),
                      if (canPop)
                        Padding(
                          padding: EdgeInsets.only(left: 22.w),
                          child: ImageRes.backBlack.toImage
                            ..width = 24.w
                            ..height = 24.h
                            ..onTap = () => Get.back(),
                        ),
                      if (canPop) 38.verticalSpace else 0.verticalSpace,
                      SizedBox(height: topSpacing.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Align(
                          alignment: alignment,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 560.w),
                            child: child,
                          ),
                        ),
                      ),
                      60.verticalSpace,
                      SizedBox(height: viewInsets),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
