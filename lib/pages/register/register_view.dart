import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import '../../widgets/register_page_bg.dart';
import 'register_logic.dart';

class RegisterPage extends StatelessWidget {
  final logic = Get.find<RegisterLogic>();

  RegisterPage({super.key});

  @override
  Widget build(BuildContext context) => RegisterBgView(
        alignment: Alignment.center,
        initialSpacing: 0,
        topSpacing: 0,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 64.h, 20.w, 16.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 420.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StrRes.newUserRegister.toText
                        ..style = Styles.ts_FFFFFF_20sp_medium.copyWith(fontSize: 22.sp, fontWeight: FontWeight.w600)
                        ..textAlign = TextAlign.center,
                      12.verticalSpace,
                      _buildInputCard(
                        children: [
                          _avatarPicker(),
                          Obx(
                            () => logic.submitted.value && logic.avatarPath.value.isEmpty
                                ? Padding(
                                    padding: EdgeInsets.only(top: 6.h),
                                    child: StrRes.pleaseSetAvatar.toText..style = Styles.ts_FF381F_12sp,
                                  )
                                : const SizedBox.shrink(),
                          ),
                          16.verticalSpace,
                          Obx(
                            () => InputBox(
                              label: StrRes.setLoginAccount,
                              hintText: StrRes.setLoginAccount,
                              formatHintText: StrRes.accountFormatHint,
                              controller: logic.accountCtrl,
                              borderColor: Styles.c_0089FF_opacity50,
                              borderWidth: 1.2,
                              errorText: logic.accountError.value,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                              ],
                            ),
                          ),
                          12.verticalSpace,
                          Obx(
                            () => InputBox(
                              label: StrRes.setLoginPassword,
                              hintText: StrRes.setLoginPassword,
                              controller: logic.pwdCtrl,
                              formatHintText: StrRes.loginPwdFormat,
                              borderColor: Styles.c_0089FF_opacity50,
                              borderWidth: 1.2,
                              errorText: logic.pwdError.value,
                              inputFormatters: [IMUtils.getPasswordFormatter()],
                              type: InputBoxType.password,
                              obscureText: false,
                            ),
                          ),
                        ],
                      ),
                      20.verticalSpace,
                      Obx(
                        () => Button(
                          text: StrRes.registerNow,
                          enabled: logic.enabled.value,
                          onTap: logic.register,
                        ),
                      ),
                      10.verticalSpace,
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: '${StrRes.haveAccount} ',
                          style: Styles.ts_FFFFFF_opacity70_14sp.copyWith(fontSize: 12.sp),
                          children: [
                            TextSpan(
                              text: StrRes.loginNow,
                              style: Styles.ts_FFFFFF_14sp,
                              recognizer: TapGestureRecognizer()..onTap = logic.goLogin,
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

  Widget _buildInputCard({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: Offset(0, 18.h),
            blurRadius: 28.r,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _avatarPicker() => Obx(
        () {
          final path = logic.avatarPath.value;
          final file = path.isNotEmpty ? File(path) : null;
          final subtitle = file == null ? StrRes.clickToSelectAvatar : StrRes.avatarSet;
          return GestureDetector(
            onTap: logic.pickAvatar,
            behavior: HitTestBehavior.translucent,
            child: Row(
              children: [
                AvatarView(
                  width: 60.w,
                  height: 60.w,
                  file: file,
                  text: logic.accountCtrl.text,
                  enabledPreview: false,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                16.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StrRes.setAvatar.toText..style = Styles.ts_8E9AB0_12sp,
                      8.verticalSpace,
                      subtitle.toText
                        ..style = Styles.ts_0C1C33_17sp_medium
                        ..maxLines = 1,
                    ],
                  ),
                ),
                Icon(Icons.photo_camera_outlined, color: Styles.c_0089FF, size: 22.w),
              ],
            ),
          );
        },
      );

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
