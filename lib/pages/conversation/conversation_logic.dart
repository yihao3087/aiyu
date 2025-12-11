import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';
import 'package:pull_to_refresh_new/pull_to_refresh.dart';

import '../../core/controller/app_controller.dart';
import '../../core/controller/im_controller.dart';
import '../../core/im_callback.dart';
import '../../routes/app_navigator.dart';
import '../contacts/add_by_search/add_by_search_logic.dart';
import '../home/home_logic.dart';

class ConversationLogic extends GetxController {
  final popCtrl = CustomPopupMenuController();
  final list = <ConversationInfo>[].obs;
  final imLogic = Get.find<IMController>();
  final homeLogic = Get.find<HomeLogic>();
  final appLogic = Get.find<AppController>();
  final refreshController = RefreshController();
  final tempDraftText = <String, String>{};
  final pageSize = 400;

  final imStatus = IMSdkStatus.connectionSucceeded.obs;
  bool reInstall = false;
  bool _notifiedSyncReady = false;

  final onChangeConversations = <ConversationInfo>[];

  @override
  void onInit() {
    getFirstPage();
    imLogic.conversationAddedSubject.listen(onChanged);
    imLogic.conversationChangedSubject.listen(onChanged);
    imLogic.imSdkStatusSubject.listen((value) async {
      final status = value.status;
      final appReInstall = value.reInstall;
      final progress = value.progress;
      imStatus.value = status;

      if (status == IMSdkStatus.syncStart) {
        reInstall = appReInstall;
        if (reInstall) {
          EasyLoading.showProgress(0, status: StrRes.synchronizing);
        }
      }

      Logger.print(
          'IM SDK Status: $status, reinstall: $reInstall, progress: $progress');

      if (status == IMSdkStatus.syncProgress && reInstall) {
        final p = (progress!).toDouble() / 100.0;

        EasyLoading.showProgress(p,
            status: '${StrRes.synchronizing}(${(p * 100.0).truncate()}%)');
      } else if (status == IMSdkStatus.syncEnded ||
          status == IMSdkStatus.syncFailed) {
        EasyLoading.dismiss();
        if (status == IMSdkStatus.syncEnded && !_notifiedSyncReady) {
          _notifiedSyncReady = true;
          appLogic.onInitialSyncCompleted();
        }
        if (reInstall) {
          onRefresh();
          reInstall = false;
        }
      }
    });
    super.onInit();
  }

  @override
  void onClose() {
    list.clear();
    reInstall = false;
    super.onClose();
  }

  void onChanged(List<ConversationInfo> newList) {
    if (reInstall) {
      onChangeConversations.addAll(newList);
    }
    for (var newValue in newList) {
      Logger.print(
          '======== conversation changed: ${newValue.toJson()} ========');
      list.removeWhere((e) => e.conversationID == newValue.conversationID);
    }

    if (newList.length > pageSize) {
      final buffer = List<ConversationInfo>.from(newList);
      while (buffer.isNotEmpty) {
        final chunkSize = buffer.length > pageSize ? pageSize : buffer.length;
        final chunk = buffer.sublist(0, chunkSize);
        list.insertAll(0, chunk);
        _sortConversationList();
        buffer.removeRange(0, chunkSize);
      }
    } else {
      list.insertAll(0, newList);
      _sortConversationList();
      Logger.print(
          '======== conversation sort result: ${list.where((e) => e.unreadCount > 0).toList().map((e) => '${e.showName} [${e.conversationID}]: ${e.unreadCount}')} ========');
    }
  }

  void promptSoundOrNotification(ConversationInfo info) {
    if (imLogic.userInfo.value.globalRecvMsgOpt == 0 &&
        info.recvMsgOpt == 0 &&
        info.unreadCount > 0 &&
        info.latestMsg?.sendID != OpenIM.iMManager.userID) {
      appLogic.promptSoundOrNotification(info.latestMsg!.seq!);
    }
  }

  String getConversationID(ConversationInfo info) {
    return info.conversationID;
  }

  String? getPrefixTag(ConversationInfo info) {
    if (info.groupAtType == GroupAtType.groupNotification) {
      return '[${StrRes.groupAc}]';
    }

    return null;
  }

  String getContent(ConversationInfo info) {
    try {
      if (null != info.draftText && '' != info.draftText) {
        var map = json.decode(info.draftText!);
        String text = map['text'];
        if (text.isNotEmpty) {
          return text;
        }
      }

      if (null == info.latestMsg) return "";

      final text = IMUtils.parseNtf(info.latestMsg!, isConversation: true);
      if (text != null) return text;
      final msg = info.latestMsg!;
      final parsed = IMUtils.parseMsg(msg, isConversation: true);
      if (info.isSingleChat || msg.sendID == OpenIM.iMManager.userID) {
        return _normalizeSummary(parsed, msg);
      }
      final summary = _normalizeSummary(parsed, msg);
      return "${msg.senderNickname}: $summary ";
    } catch (e, s) {
      Logger.print('------e:$e s:$s');
    }
    return _fallbackSummary(info.latestMsg);
  }

  String? getAvatar(ConversationInfo info) {
    return info.faceURL;
  }

  bool isGroupChat(ConversationInfo info) {
    return info.isGroupChat;
  }

  String getShowName(ConversationInfo info) {
    if (info.showName == null || info.showName.isBlank!) {
      return info.userID!;
    }
    return info.showName!;
  }

  String getTime(ConversationInfo info) {
    return IMUtils.getChatTimeline(info.latestMsgSendTime!);
  }

  int getUnreadCount(ConversationInfo info) {
    return info.unreadCount;
  }

  bool existUnreadMsg(ConversationInfo info) {
    return getUnreadCount(info) > 0;
  }

  bool isUserGroup(int index) => list.elementAt(index).isGroupChat;

  String _normalizeSummary(String? parsed, Message msg) {
    final text = parsed?.trim() ?? '';
    if (text.isNotEmpty && !text.contains(StrRes.unsupportedMessage)) {
      return text;
    }
    return _fallbackSummary(msg);
  }

  String _fallbackSummary(Message? msg) {
    if (msg == null) return '[${StrRes.unsupportedMessage}]';
    switch (msg.contentType) {
      case MessageType.text:
        return msg.textElem?.content ?? '';
      case MessageType.atText:
        return msg.atTextElem?.text ?? msg.textElem?.content ?? '';
      case MessageType.picture:
        return '[${StrRes.picture}]';
      case MessageType.voice:
        final d = msg.soundElem?.duration ?? 0;
        return d > 0 ? '[${StrRes.voice}] ${d}s' : '[${StrRes.voice}]';
      case MessageType.video:
        return '[${StrRes.video}]';
      case MessageType.quote:
        final quote = msg.quoteElem;
        final reply = quote?.text ?? '';
        final target = IMUtils.messageDigest(quote?.quoteMessage);
        if (reply.isNotEmpty) {
          return '${StrRes.menuReply}: $reply';
        }
        if (target.isNotEmpty) {
          return '${StrRes.menuReply}: $target';
        }
        return StrRes.menuReply;
      case MessageType.file:
        final name = msg.fileElem?.fileName;
        return name?.isNotEmpty == true
            ? '[${StrRes.file}] $name'
            : '[${StrRes.file}]';
      case MessageType.location:
        final desc = msg.locationElem?.description ?? '';
        return desc.isNotEmpty
            ? '[${StrRes.location}] $desc'
            : '[${StrRes.location}]';
      case MessageType.card:
        final name = msg.cardElem?.nickname ?? '';
        return name.isNotEmpty
            ? '[${StrRes.contacts}] $name'
            : '[${StrRes.contacts}]';
      case MessageType.customFace:
        return '[${StrRes.emoji}]';
      case MessageType.custom:
        final data = IMUtils.parseCustomMessage(msg);
        if (data is Map) {
          final content = data['content'];
          if (content is String && content.isNotEmpty) {
            return content;
          }
          final viewType = data['viewType'];
          if (viewType == CustomMessageType.call) {
            final type = (data['type'] ?? 'audio').toString();
            return type == 'video' ? StrRes.callVideo : StrRes.callVoice;
          } else if (viewType == CustomMessageType.emoji) {
            return StrRes.emoji;
          } else if (viewType == CustomMessageType.tag) {
            final name = data['name'];
            return name is String && name.isNotEmpty ? name : StrRes.tagGroup;
          } else if (viewType == CustomMessageType.meeting) {
            return StrRes.videoMeeting;
          }
        }
        final payload = IMUtils.decodeCustomMessageMap(msg);
        if (payload != null) {
          final customType = IMUtils.customMessageType(msg);
          final dataMap = IMUtils.customMessageData(msg);
          final viewType = dataMap['viewType'] ?? customType;
          if (viewType == CustomMessageType.telegramRichMedia) {
            final text = (dataMap['text'] as String?)?.trim() ?? '';
            return text.isEmpty
                ? '[${StrRes.richMedia}]'
                : '[${StrRes.richMedia}] $text';
          }
        }
        return '[${StrRes.unsupportedMessage}]';
      default:
        return '[${StrRes.unsupportedMessage}]';
    }
  }

  String? get imSdkStatus {
    switch (imStatus.value) {
      case IMSdkStatus.syncStart:
      case IMSdkStatus.synchronizing:
      case IMSdkStatus.syncProgress:
        return StrRes.synchronizing;
      case IMSdkStatus.syncFailed:
        return StrRes.syncFailed;
      case IMSdkStatus.connecting:
        return StrRes.connecting;
      case IMSdkStatus.connectionFailed:
        return StrRes.connectionFailed;
      case IMSdkStatus.connectionSucceeded:
      case IMSdkStatus.syncEnded:
        return null;
    }
  }

  bool get isFailedSdkStatus =>
      imStatus.value == IMSdkStatus.connectionFailed ||
      imStatus.value == IMSdkStatus.syncFailed;

  void _sortConversationList() =>
      OpenIM.iMManager.conversationManager.simpleSort(list);

  Future<bool> markConversationAsRead(ConversationInfo info) async {
    if (info.unreadCount == 0) {
      IMViews.showSimpleTip(StrRes.markHasRead);
      return false;
    }
    try {
      await OpenIM.iMManager.conversationManager
          .markConversationMessageAsRead(conversationID: info.conversationID);
      final index =
          list.indexWhere((e) => e.conversationID == info.conversationID);
      if (index != -1) {
        list[index].unreadCount = 0;
      }
      list.refresh();
      IMViews.showSimpleTip(StrRes.markHasRead);
      return true;
    } catch (e, s) {
      Logger.print('mark conversation read failed: $e $s');
      IMViews.showToast(
        e is PlatformException ? '${e.code} ${e.message}' : e.toString(),
        allowUserInteraction: true,
      );
      return false;
    }
  }

  Future<bool> deleteConversation(ConversationInfo info) async {
    try {
      await OpenIM.iMManager.conversationManager
          .deleteConversationAndDeleteAllMsg(
              conversationID: info.conversationID);
      list.removeWhere(
          (element) => element.conversationID == info.conversationID);
      IMViews.showSimpleTip(StrRes.deleteSuccessfully);
      return true;
    } catch (e, s) {
      Logger.print('delete conversation failed: $e $s');
      IMViews.showToast(
        e is PlatformException ? '${e.code} ${e.message}' : e.toString(),
        allowUserInteraction: true,
      );
      return false;
    }
  }

  void onConversationLongPress(ConversationInfo info) {
    final isPinned = info.isPinned == true;
    final items = <SheetItem>[
      SheetItem(
        label: isPinned ? StrRes.cancelTop : StrRes.topChat,
        onTap: () async {
          Get.back();
          await toggleConversationPinned(info, pin: !isPinned);
        },
      ),
    ];
    Get.bottomSheet(BottomSheetView(items: items));
  }

  Future<void> toggleConversationPinned(ConversationInfo info,
      {required bool pin}) async {
    try {
      await OpenIM.iMManager.conversationManager
          .pinConversation(conversationID: info.conversationID, isPinned: pin);
      final index = list.indexWhere(
          (element) => element.conversationID == info.conversationID);
      if (index != -1) {
        list[index].isPinned = pin;
      }
      _sortConversationList();
      list.refresh();
      IMViews.showToast(
        pin ? StrRes.topChat : StrRes.cancelTop,
        allowUserInteraction: true,
      );
    } catch (e, s) {
      Logger.print('pin conversation failed: $e $s');
      IMViews.showToast(
        e is PlatformException ? '${e.code} ${e.message}' : e.toString(),
        allowUserInteraction: true,
      );
    }
  }

  Future<bool> onTapDeleteConversation(ConversationInfo info) async {
    final confirm = await Get.dialog<bool>(
      CustomDialog(
        title: StrRes.deleteConversationHint,
        rightText: StrRes.delete,
      ),
    );
    if (confirm == true) {
      return deleteConversation(info);
    }
    return false;
  }

  void onRefresh() async {
    late List<ConversationInfo> list;
    try {
      list = await _request();
      this.list.assignAll(list);

      if (list.isEmpty || list.length < pageSize) {
        refreshController.loadNoData();
      } else {
        refreshController.loadComplete();
      }
    } finally {
      refreshController.refreshCompleted();
    }
  }

  static Future<List<ConversationInfo>> getConversationFirstPage() async {
    IMController? im;
    if (Get.isRegistered<IMController>()) {
      im = Get.find<IMController>();
      await im.ensureInitialized().catchError((_) {});
    }
    final result = await IMUtils.runWithImReady(() => OpenIM
        .iMManager.conversationManager
        .getConversationListSplit(offset: 0, count: 400));

    return result;
  }

  void getFirstPage() async {
    final result = homeLogic.conversationsAtFirstPage;

    list.assignAll(result);
    _sortConversationList();
  }

  void clearConversations() {
    list.clear();
  }

  _request() async {
    final temp = <ConversationInfo>[];

    while (true) {
      var result = await IMUtils.runWithImReady(() => OpenIM
              .iMManager.conversationManager
              .getConversationListSplit(
            offset: temp.length,
            count: pageSize,
          ));
      if (onChangeConversations.isNotEmpty) {
        final bSet = Set.from(onChangeConversations);

        Logger.print(
            'replace conversation: [${onChangeConversations.length}], $bSet');

        for (int i = 0; i < result.length; i++) {
          final info = result[i];

          if (bSet.contains(info)) {
            result[i] =
                onChangeConversations[onChangeConversations.indexOf(info)];
          }
        }
      }
      temp.addAll(result);

      if (result.length < pageSize) {
        break;
      }
    }
    onChangeConversations.clear();

    return temp;
  }

  bool isValidConversation(ConversationInfo info) {
    return info.isValid;
  }

  static Future<ConversationInfo> _createConversation({
    required String sourceID,
    required int sessionType,
  }) =>
      LoadingView.singleton.wrap(
          asyncFunction: () => IMUtils.runWithImReady(() =>
                  OpenIM.iMManager.conversationManager.getOneConversation(
                sourceID: sourceID,
                sessionType: sessionType,
              )));

  Future<bool> _jumpOANtf(ConversationInfo info) async {
    if (info.conversationType == ConversationType.notification) {
      return true;
    }
    return false;
  }

  void toChat({
    bool offUntilHome = true,
    String? userID,
    String? groupID,
    String? nickname,
    String? faceURL,
    int? sessionType,
    ConversationInfo? conversationInfo,
    Message? searchMessage,
  }) async {
    conversationInfo ??= await _createConversation(
      sourceID: userID ?? groupID!,
      sessionType: userID == null ? sessionType! : ConversationType.single,
    );

    if (await _jumpOANtf(conversationInfo)) return;

    await AppNavigator.startChat(
      offUntilHome: offUntilHome,
      draftText: conversationInfo.draftText,
      conversationInfo: conversationInfo,
      searchMessage: searchMessage,
    );

    bool equal(e) => e.conversationID == conversationInfo?.conversationID;

    var groupAtType = list.firstWhereOrNull(equal)?.groupAtType;
    if (groupAtType != GroupAtType.atNormal) {
      final req = ConversationReq(groupAtType: GroupAtType.atNormal);
      final cid = conversationInfo?.conversationID;
      if (cid != null) {
        await IMUtils.runWithImReady(() => OpenIM.iMManager.conversationManager
            .setConversation(
          cid,
          req,
        ));
      }
    }
  }

  addFriend() =>
      AppNavigator.startAddContactsBySearch(searchType: SearchType.user);

  createGroup() => AppNavigator.startCreateGroup(
      defaultCheckedList: [OpenIM.iMManager.userInfo]);

  addGroup() =>
      AppNavigator.startAddContactsBySearch(searchType: SearchType.group);

  void globalSearch() => AppNavigator.startGlobalSearch();
}
