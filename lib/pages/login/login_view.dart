import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../widgets/register_page_bg.dart';
import 'login_logic.dart';

class LoginPage extends StatelessWidget {
  final logic = Get.find<LoginLogic>();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RegisterBgView(
      alignment: Alignment.center,
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 64.h, 20.w, 16.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    StrRes.welcome.toText
                      ..style = Styles.ts_FFFFFF_20sp_medium.copyWith(fontSize: 22.sp, fontWeight: FontWeight.w600)
                      ..textAlign = TextAlign.center,
                    20.verticalSpace,
                    _buildInputView(),
                    24.verticalSpace,
                    Obx(
                      () => Button(
                        text: StrRes.login,
                        enabled: logic.enabled.value,
                        onTap: logic.login,
                      ),
                    ),
                    12.verticalSpace,
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: '${StrRes.noAccountYet} ',
                        style: Styles.ts_FFFFFF_opacity70_14sp.copyWith(fontSize: 12.sp),
                        children: [
                          TextSpan(
                            text: StrRes.registerNow,
                            style: Styles.ts_FFFFFF_14sp,
                            recognizer: TapGestureRecognizer()..onTap = logic.registerNow,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _autoLoginMask(),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28.r,
            offset: Offset(0, 18.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputBox(
            label: StrRes.setLoginAccount,
            hintText: StrRes.setLoginAccount,
            controller: logic.accountCtrl,
            focusNode: logic.accountFocus,
            borderColor: Styles.c_0089FF_opacity50,
            borderWidth: 1.2,
          ),
          16.verticalSpace,
          InputBox(
            label: StrRes.setLoginPassword,
            hintText: StrRes.setLoginPassword,
            controller: logic.pwdCtrl,
            focusNode: logic.pwdFocus,
            borderColor: Styles.c_0089FF_opacity50,
            borderWidth: 1.2,
            type: InputBoxType.password,
            obscureText: false,
            formatHintText: StrRes.loginPwdFormat,
            inputFormatters: [IMUtils.getPasswordFormatter()],
          ),
        ],
      ),
    );
  }

  Widget _autoLoginMask() => Obx(
        () => logic.autoLoginBusy.value
            ? Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      12.verticalSpace,
                      StrRes.loading.toText..style = Styles.ts_FFFFFF_16sp,
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
}
