import 'package:flutter/material.dart';

import '../models/signaling_info.dart';

class PackageBridge {
  PackageBridge._();

  static SelectContactsBridge? selectContactsBridge;
  static ViewUserProfileBridge? viewUserProfileBridge;
  static RTCBridge? rtcBridge;
  static CallNotificationBridge? callNotificationBridge;
}

abstract class OrganizationMultiSelBridge {
  Widget get checkedConfirmView;

  bool get isMultiModel;

  bool isChecked(dynamic info);

  bool isDefaultChecked(dynamic info);

  Function()? onTap(dynamic info);

  toggleChecked(dynamic info);

  removeItem(dynamic info);

  updateDefaultCheckedList(List<String> userIDList);
}

abstract class ViewUserProfileBridge {
  viewUserProfile(
    String userID,
    String? nickname,
    String? faceURL, [
    String? groupID,
  ]);
}

abstract class SelectContactsBridge {
  Future<T?>? selectContacts<T>(
    int type, {
    List<String>? defaultCheckedIDList,
    List<dynamic>? checkedList,
    List<String>? excludeIDList,
    bool openSelectedSheet = false,
    String? groupID,
    String? ex,
  });
}

abstract class RTCBridge {
  bool get hasConnection;
  void dismiss();
}

abstract class CallNotificationBridge {
  Future<void> showIncomingCallNotification(SignalingInfo signaling);
  Future<void> cancelIncomingCallNotification();
}

class GetTags {
  static final List<String> _chatTags = <String>[];
  static final List<String> _userProfileTags = <String>[];

  static void createChatTag() {
    _chatTags.add('_${DateTime.now().millisecondsSinceEpoch}');
  }

  static void createUserProfileTag() {
    _userProfileTags.add('_${DateTime.now().millisecondsSinceEpoch}');
  }

  static void destroyChatTag() {
    _chatTags.removeLast();
  }

  static void destroyUserProfileTag() {
    _userProfileTags.removeLast();
  }

  static String? get chat => _chatTags.isNotEmpty ? _chatTags.last : null;

  static String get userProfile => _userProfileTags.last;
}
