import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'set_self_info_logic.dart';

class SetSelfInfoPage extends StatelessWidget {
  final logic = Get.find<SetSelfInfoLogic>();

  SetSelfInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(StrRes.plsCompleteInfo, style: Styles.ts_0C1C33_17sp),
        centerTitle: true,
        backgroundColor: Styles.c_FFFFFF,
      ),
      backgroundColor: Styles.c_F8F9FA,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatarSection(),
              24.verticalSpace,
              _nicknameField(),
              16.verticalSpace,
              32.verticalSpace,
              Obx(() => Button(
                    text: StrRes.done,
                    enabled: logic.faceURL.value.isNotEmpty &&
                        logic.nickname.value.isNotEmpty,
                    onTap: logic.submit,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarSection() => Obx(
        () => GestureDetector(
          onTap: logic.pickAvatar,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            decoration: BoxDecoration(
              color: Styles.c_FFFFFF,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                AvatarView(
                  width: 68.w,
                  height: 68.w,
                  url: logic.faceURL.value.isNotEmpty
                      ? logic.faceURL.value
                      : null,
                  text: logic.nickname.value,
                  onTap: logic.pickAvatar,
                ),
                20.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(StrRes.avatar, style: Styles.ts_8E9AB0_14sp),
                    8.verticalSpace,
                    Text(
                      logic.faceURL.value.isNotEmpty ? StrRes.avatarSet : StrRes.clickToSelectAvatar,
                      style: Styles.ts_0C1C33_17sp,
                    ),
                  ],
                  ),
                ),
                const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF2E9BFF)),
              ],
            ),
          ),
        ),
      );

  Widget _nicknameField() => Obx(
        () => Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: Styles.c_FFFFFF,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(StrRes.nickname, style: Styles.ts_8E9AB0_14sp),
              12.verticalSpace,
              TextField(
                controller: logic.nicknameCtrl,
                maxLength: 16,
                style: Styles.ts_0C1C33_17sp,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: StrRes.plsEnterYourNickname,
                  hintStyle: Styles.ts_8E9AB0_14sp,
                  errorText: logic.nicknameError.value,
                  errorStyle: Styles.ts_FF381F_14sp,
                ),
                onTap: logic.onNicknameTap,
              ),
            ],
          ),
        ),
      );
}
