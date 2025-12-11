import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

import 'user_profile_panel_logic.dart';

class UserProfilePanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => UserProfilePanelLogic(), tag: GetTags.userProfile);
  }
}
