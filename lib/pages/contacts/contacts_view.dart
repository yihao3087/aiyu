import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'contacts_logic.dart';

class ContactsPage extends StatelessWidget {
  final logic = Get.find<ContactsLogic>();

  ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar.contacts(
        onClickAddContacts: logic.addContacts,
      ),
      backgroundColor: Styles.c_F8F9FA,
      body: Column(
        children: [
          Obx(
            () => Column(
              children: [
                _buildItemView(
                  icon: _buildShortcutIcon(
                    Icons.person_add_alt_1_rounded,
                    colors: const [Color(0xFF111111), Color(0xFF2F2F2F)],
                  ),
                  label: StrRes.newFriend,
                  count: logic.friendApplicationCount,
                  onTap: logic.newFriend,
                ),
                _buildItemView(
                  icon: _buildShortcutIcon(
                    Icons.groups_3_rounded,
                    colors: const [Color(0xFF161616), Color(0xFF3B3B3B)],
                  ),
                  label: StrRes.myGroup,
                  onTap: logic.myGroup,
                ),
              ],
            ),
          ),
          10.verticalSpace,
          Expanded(
            child: Container(
              color: Styles.c_FFFFFF,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: StrRes.myFriend.toText..style = Styles.ts_8E9AB0_14sp,
                  ),
                  Divider(height: 1, thickness: 1, color: Styles.c_E8EAEF),
                  Expanded(child: _buildFriendList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendList() => Obx(() {
        final friends = logic.friendList;
        if (friends.isEmpty) {
          return Center(
            child: StrRes.contactFriendEmpty.toText..style = Styles.ts_8E9AB0_14sp,
          );
        }
        return WrapAzListView<ISUserInfo>(
          data: friends,
          itemCount: friends.length,
          itemBuilder: (_, data, __) => _buildFriendItem(data),
        );
      });

  Widget _buildFriendItem(ISUserInfo info) => Ink(
        height: 64.h,
        color: Styles.c_FFFFFF,
        child: InkWell(
          onTap: () => logic.viewFriendInfo(info),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                AvatarView(
                  url: info.faceURL,
                  text: info.showName,
                ),
                10.horizontalSpace,
                Expanded(
                  child: info.showName.toText..style = Styles.ts_0C1C33_17sp,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildItemView({
    String? assetsName,
    required String label,
    Widget? icon,
    int count = 0,
    bool showRightArrow = true,
    double? height,
    Function()? onTap,
  }) =>
      Ink(
        color: Styles.c_FFFFFF,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height ?? 60.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                if (icon != null)
                  icon
                else if (assetsName != null)
                  assetsName.toImage
                    ..width = 42.w
                    ..height = 42.h,
                12.horizontalSpace,
                label.toText..style = Styles.ts_0C1C33_17sp,
                const Spacer(),
                if (count > 0) UnreadCountView(count: count),
                4.horizontalSpace,
                if (showRightArrow)
                  ImageRes.rightArrow.toImage
                    ..width = 24.w
                    ..height = 24.h,
              ],
            ),
          ),
        ),
      );

  Widget _buildShortcutIcon(
    IconData data, {
    required List<Color> colors,
  }) {
    return Container(
      width: 42.w,
      height: 42.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        data,
        color: Styles.c_FFFFFF,
        size: 20.sp,
      ),
    );
  }
}
